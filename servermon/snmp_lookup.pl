#!/usr/bin/perl -w
# Скрипт для полечения информации с удаленных хостов по SNMP и сохранения в RRD базе.
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
##############################################################################


use Config::General; 
use Net::SNMP;
use RRDs;

use constant DEF_TIMEOUT   => 10;

use constant GRAPH_BLOCK	=> 0;
use constant GRAPH_NAME		=> 1;
use constant GRAPH_ID		=> 2;
use constant GRAPH_VALUE	=> 3;

my %configuration_def_map = (
    "verbose_mode" 	=> 0,
    "log_dir"		=> "/usr/local/alertmon/toplogs",
    "graph_dir"		=> "./graph",
    "graph_days"	=> 3,
    "graph_width" 	=> 650,
    "graph_height" 	=> 300,
    "graph_bold_level"	=> 1,
    "cron_interval"	=> 600,
    "rrd_store_days"	=> 60,
    "remote_mon"	=> {
	"title"			=> "",
	"snmp_oid"		=> '1.3.6.1.4.1.2021.57.101',
	"snmp_host"		=> "",
	"snmp_port"		=> 161,
	"snmp_community"	=> "public",
	"sum_graph"		=> [],
			    }
);

my $cfg_lock_livetime = 20*60; # Время жизни лока, 20 мин.
my $cfg_lock_file;
my $config_path = "servermon.conf";
my $cfg_verbose_mode;
my $cfg_log_dir;
my $cfg_cron_interval;
my $cfg_rrd_store_days;
my $cfg_remote_dir = "remote";
my $cfg_rrd_dir = "$cfg_remote_dir/rrd";
my $now_time = time();
my %alert_list = ();
my @rrd_index=();

# Читаем файл конфигурации
if ( defined $ARGV[0]) {
    $config_path = $ARGV[0];
} elsif (! -f $config_path){
    $config_path = "/etc/$config_path";
}
if (! -f $config_path){
    die "Configuration file not found.\nUsage: 'snmp_lookup.pl <config_path>' or create /etc/$config_path\n";
}
my $config_main_obj = new Config::General(-ConfigFile => $config_path, 
					  -AllowMultiOptions => 'yes',
					  -LowerCaseNames => 'yes');
my %config_main = $config_main_obj->getall;

verify_config(\%configuration_def_map, \%config_main);

# Устанавливаем корневые переменные конфигурации.
    $cfg_verbose_mode = $config_main{"verbose_mode"} ||  $configuration_def_map{"verbose_mode"};
    $cfg_log_dir = $config_main{"log_dir"} || $configuration_def_map{"log_dir"};
    $cfg_cron_interval = $config_main{"cron_interval"} || $configuration_def_map{"cron_interval"};
    $cfg_rrd_store_days = $config_main{"rrd_store_days"} || $configuration_def_map{"rrd_store_days"};

    if (! -d $cfg_log_dir){
	die "Can't stat log directory '$cfg_log_dir'\n";
    }
    if (! -d "$cfg_log_dir/$cfg_remote_dir"){
	mkdir("$cfg_log_dir/$cfg_remote_dir",0775);
    }
    if (! -d "$cfg_log_dir/$cfg_rrd_dir"){
	mkdir("$cfg_log_dir/$cfg_rrd_dir",0775);
    }

# Обрабатываем возможную ситуацию одновременного исполнения двых процессов.
# Проверяем лок файлы.
    $cfg_lock_file = "$cfg_log_dir/snmp_lookup.lock";
    if ( -f "$cfg_lock_file"){
	my $act_flag = `ps -auxwww|grep "perl.*snmp_lookup.pl"| grep -v grep | wc -l`;
	if ($act_flag != 1){

	    if ((stat($cfg_lock_file))[9] + $cfg_lock_livetime < time()){
		print STDERR "Lock file exists! $act_flag Process already running !!! Lock file timeout. Killing old script. Continuing...\n";
		open(LOCK,"<$cfg_lock_file");
		my $lock_pid = <LOCK>;
		close (LOCK);
		chomp ($lock_pid);
		system("kill", "$lock_pid");
		unlink("$cfg_lock_file");
	    }else{
		print STDERR "Lock file exists! $act_flag Process already running !!! Exiting.\n";
		exit(0);
	    }
	} else {
	    unlink("$cfg_lock_file");
	    print STDERR "Lock file exists! Deadlock detected. Removing lock and continuing.\n";
	}
    }
# Создаем лок файл.
    open(LOCK,">$cfg_lock_file");
    print LOCK "$$\n";
    close (LOCK);


    # Перебираем удаленные хосты.
    foreach my $cur_id (keys %{$config_main{"remote_mon"}}){

	my $cur_snmp_oid = $config_main{"remote_mon"}->{"$cur_id"}->{"snmp_oid"} || $configuration_def_map{"remote_mon"}->{"snmp_oid"};
	my $cur_snmp_host = $config_main{"remote_mon"}->{"$cur_id"}->{"snmp_host"} || $configuration_def_map{"remote_mon"}->{"snmp_host"};
	my $cur_snmp_port = $config_main{"remote_mon"}->{"$cur_id"}->{"snmp_port"} || $configuration_def_map{"remote_mon"}->{"snmp_port"};
	my $cur_snmp_community = $config_main{"remote_mon"}->{"$cur_id"}->{"snmp_community"} || $configuration_def_map{"remote_mon"}->{"snmp_community"};
	my $cur_title = $config_main{"remote_mon"}->{"$cur_id"}->{"title"} || $configuration_def_map{"remote_mon"}->{"title"};
	my $cur_local_flag = 0;
	
	if ($cur_snmp_oid !~ /^[\d\.]+$/){
	    if (-f $cur_snmp_oid){
		$cur_local_flag = 1;
	    } else {
		print "Unknown SNMP OID or status file: $cur_snmp_oid\n";
		next;
	    }
	}
	my @cur_graph_status = ();
	my @cur_alert_status = ();
	# Вызываем обработчик для выборки данных по SNMP
	if ($cur_local_flag == 0){
	    fetch_remote_stat($cur_id, $cur_snmp_oid, $cur_snmp_host, $cur_snmp_port, $cur_snmp_community, \@cur_graph_status, \@cur_alert_status);
	} else {
	    fetch_local_stat($cur_id, $cur_snmp_oid, \@cur_graph_status);
	}
	# Обновляем RRD базу для построения графиков.
	update_rrd_base($cur_id, $cur_title, \@cur_graph_status, \@rrd_index); 

	# Сохраняем информацию о текущем статусе на диск.
	open (STATUS_DUMP,">$cfg_log_dir/$cfg_remote_dir/$cur_id.status.new");
	flock(STATUS_DUMP,2);
	foreach my $cur_datablock (@cur_graph_status){
	    print STATUS_DUMP "$$cur_datablock[&GRAPH_BLOCK]\t$$cur_datablock[&GRAPH_NAME]\t$$cur_datablock[&GRAPH_ID]\t$$cur_datablock[&GRAPH_VALUE]\n";
	}
	close(STATUS_DUMP);
	rename("$cfg_log_dir/$cfg_remote_dir/$cur_id.status.new", "$cfg_log_dir/$cfg_remote_dir/$cur_id.status");
	
	if ($cur_local_flag == 0){
	    # Учитываем алерты удаленной системы
	    update_alert_base($cur_id, \@cur_alert_status); 
	    close_alerts($cur_id);
	}
    }
    
    # Сбрасываем индекс RRD файлов на диск.

    open(RRDINDEX, ">$cfg_log_dir/$cfg_rrd_dir/.rrd_index.new");
    flock(RRDINDEX,2);
    foreach my $cur_rrd_inf (@rrd_index){
	print RRDINDEX "$cur_rrd_inf\n";
    }
    close(RRDINDEX);
    rename("$cfg_log_dir/$cfg_rrd_dir/.rrd_index.new", "$cfg_log_dir/$cfg_rrd_dir/.rrd_index");
    
    # Удаляем лок файл.
    unlink("$cfg_lock_file");

exit(0);

##############################################################################
##############################################################################
##############################################################################

##############################################################################
# Проверка директив в файле конфигурации. 
sub verify_config{
    my ($configuration_def_map, $config_main) = @_;
    my ($cur_name, $cur_id, $cur_item);
    
    foreach $cur_name (keys %$config_main){
	if (! defined $$configuration_def_map{$cur_name}){
	    # Удаляем лок файл.
	    unlink("$cfg_lock_file");
	    die "Error: Incorrect configuration directive '$cur_name'\n";
	}
	if (ref($$configuration_def_map{$cur_name}) eq "HASH"){
	    foreach $cur_id (keys %{$config_main{$cur_name}}){
		if (ref ($$config_main{$cur_name}{$cur_id}) eq "HASH"){
		    foreach $cur_item (keys %{$config_main{$cur_name}{$cur_id}}){
			if (! defined $$configuration_def_map{$cur_name}{$cur_item}){
			        # Удаляем лок файл.
			        unlink("$cfg_lock_file");
				die "Error: Incorrect configuration directive '$cur_item' in block <$cur_name $cur_id>\n";
			}
		    }
		} else {
		    if (! defined $$configuration_def_map{$cur_name}{$cur_id}){
			# Удаляем лок файл.
		        unlink("$cfg_lock_file");
			die "Error: Incorrect configuration directive '$cur_id' in block <$cur_name>\n";
		    }
		}
	    }	    
	}
    }
}

##############################################################################
# Вызываем обработчик для выборки данных по SNMP
sub fetch_remote_stat{
    my ($cur_id, $cur_snmp_oid, $cur_snmp_host, $cur_snmp_port, 
	$cur_snmp_community, $cur_graph_status, $cur_alert_status) = @_;

	my ($session, $error) = Net::SNMP->session(
             -hostname  => $cur_snmp_host,
             -community => $cur_snmp_community,
	     -port      => $cur_snmp_port
	);
        if (!defined($session)) {
             print STDERR "ERROR session: $error\n";
             next;
        }
	$session->timeout(10); # 10 сек. таймаут
	$session->retries(5); # 5 повторов
	$session->translate(0); # Для отображения русских букв.
	  
	if (!defined($result = $session->get_table($cur_snmp_oid))){
    	    print STDERR "Net::SNMP:get_request(ckactByts): " . $session->error() . "\n";
	    next;
	}
	my $base_oid;
	while (($base_oid) = each(%$result)){
	    my $cur_val = $result->{$base_oid};
	    chomp($cur_val);
	    $base_oid =~ /^.*\.(\d+)$/;
	    my $cur_operation = $1;
	    if ($cur_operation == 1){
		#  разделенные ^ имена блоков
		my $i = 0;
		foreach $cur_item (split(/\^/, $cur_val)){
		    $$cur_graph_status[$i][GRAPH_BLOCK] = $cur_item;
		    $i++;
		}
	    } elsif ($cur_operation == 2){ 
		# разделенные ^ имена графика
		my $i = 0;
		foreach $cur_item (split(/\^/, $cur_val)){
		    $$cur_graph_status[$i][GRAPH_NAME] = $cur_item;
		    $i++;
		}
	    } elsif ($cur_operation == 3){ 
		# разделенные ^ имена id
		my $i = 0;
		foreach $cur_item (split(/\^/, $cur_val)){
		    $$cur_graph_status[$i][GRAPH_ID] = $cur_item;
		    $i++;
		}
	    } elsif ($cur_operation == 4){ 
		#  разделенные ^ топовые значения
		my $i = 0;
		foreach $cur_item (split(/\^/, $cur_val)){
		    $$cur_graph_status[$i][GRAPH_VALUE] = $cur_item;
		    $i++;
		}
	    } else {
		# строки идентифицирующие активные алерты
		$cur_val =~ s/\^/\t/g;
		push @$cur_alert_status, $cur_val;
	    }
	}
	$session->close;
}

##############################################################################
# Вызываем обработчик для выборки данных из локальной базы.
sub fetch_local_stat{
    my ($cur_id, $cur_status_file, $cur_graph_status) = @_;


    open (TOP, "<$cur_status_file") || return -1;
    flock(TOP, 2);
    my $graph_name = <TOP> || "";
    my $graph_type = <TOP> || "";
    my $graph_id = <TOP> || ""; 
    my $graph_counter = <TOP> ||"";
    close(TOP);
    chomp($graph_name);
    chomp($graph_type);
    chomp($graph_id);
    chomp($graph_counter);
    
    #  разделенные ^ имена блоков
    my $i = 0;
    foreach my $cur_item (split(/\t/, $graph_name)){
        $$cur_graph_status[$i][GRAPH_BLOCK] = $cur_item;
        $i++;
    }
    # разделенные ^ имена графика
    $i = 0;
    foreach my $cur_item (split(/\t/, $graph_type)){
        $$cur_graph_status[$i][GRAPH_NAME] = $cur_item;
        $i++;
    }
    # разделенные ^ имена id
    $i = 0;
    foreach my $cur_item (split(/\t/, $graph_id)){
        $$cur_graph_status[$i][GRAPH_ID] = $cur_item;
        $i++;
    }
    #  разделенные ^ топовые значения
    $i = 0;
    foreach $cur_item (split(/\t/, $graph_counter)){
        $$cur_graph_status[$i][GRAPH_VALUE] = $cur_item;
        $i++;
    }
}

##############################################################################
# Обработка факта исчезновения алерта.
sub close_alerts{
    my ($cur_id) = @_;
    my ($cur_alert, $cur_alert_name);

    opendir (LOGDIR, "$cfg_log_dir/$cfg_remote_dir");
    while ($cur_alert = readdir(LOGDIR)){
	if ($cur_alert =~ /^($cur_id\.[^\/]+)\.act$/){
	    $cur_alert_name = $1;
	    if (defined $alert_list{"$cur_alert_name"}){
		# Алерт еще активен.
		next;
	    } else {
		my $alert_text;
		open (ALERT, "<$cfg_log_dir/$cfg_remote_dir/$cur_alert") || print STDERR "Can't open .act file ($cur_alert).\n";
		chomp($alert_text = <ALERT>);
		close(ALERT);
		unlink("$cfg_log_dir/$cfg_remote_dir/$cur_alert");

		open (SMALL_LOG, ">>$cfg_log_dir/$cfg_remote_dir/alertlist.log");
		flock(SMALL_LOG, 2);
		print SMALL_LOG "CLOSE\t$now_time\t$alert_text\t$cur_id\n";
		close(SMALL_LOG);
	    }
	}
    }
    closedir(LOGDIR);
}


##############################################################################
# Учитываем алерты удаленной системы
# $block_name.$id_name\t$text_now_time\t$alert_subject\t$now_time\t$cfg_host_name

sub update_alert_base{
    my ($cur_id, $cur_alert_status) = @_; 
    
    foreach $cur_alert_text (@$cur_alert_status){
	my ($alert_name, $text_alert_time, $alert_subject, $alert_time, 
				$alert_host_name) = split(/\t/, $cur_alert_text);

	# Проверяем наличие файлов активных алертов.
	if (! -f "$cfg_log_dir/$cfg_remote_dir/$cur_id.$alert_name.act"){
	    # Алерт не был ранее создан.
	    # Создаем флаг активности алерта.
	    open (ALERT, ">$cfg_log_dir/$cfg_remote_dir/$cur_id.$alert_name.act") || print STDERR "Can't create .act file.\n";
	    print ALERT "$now_time\t$cur_alert_text\n";
	    close(ALERT);
	    # Запись в лог файл алертов.
	    open (SMALL_LOG, ">>$cfg_log_dir/$cfg_remote_dir/alertlist.log");
	    flock(SMALL_LOG, 2);
	    print SMALL_LOG "OPEN\t$now_time\t$cur_alert_text\t$cur_id\n";
	    close(SMALL_LOG);
	}
	# Сохраняем информацию об алерте в базе
        my ($log_sec, $log_min, $log_hour, $log_mday, $log_mon, $log_year,
    	    $log_wday, $log_yday, $log_isdst) = localtime($now_time);
	$log_mon++;
	$log_year += 1900;
	my $cur_log_path = "$cfg_log_dir/$cfg_remote_dir/$log_year/$log_mon/$log_mday";

	# Создаем директории для дерева, если не созданы ранее.    
	if (! -d "$cfg_log_dir/$cfg_remote_dir/$log_year"){
	    mkdir("$cfg_log_dir/$cfg_remote_dir/$log_year",0775);
	}
        if (! -d "$cfg_log_dir/$cfg_remote_dir/$log_year/$log_mon"){
    	    mkdir("$cfg_log_dir/$cfg_remote_dir/$log_year/$log_mon",0775);
	}
	if (! -d "$cfg_log_dir/$cfg_remote_dir/$log_year/$log_mon/$log_mday"){
	    mkdir("$cfg_log_dir/$cfg_remote_dir/$log_year/$log_mon/$log_mday",0775);
	}
	# Дамп алерта
	open(LOG, ">>$cur_log_path/$cur_id.$alert_name.txt")|| print STDERR "Can't create dump file\n";
        flock(LOG, 2);
	print LOG "$cur_alert_text\n";
	close(LOG);
	$alert_list{"$cur_id.$alert_name"} = 1;
    }
}

##############################################################################
# Обновляем RRD базу для построения графиков.
sub update_rrd_base{
    my ($cur_id, $cur_title, $cur_graph_status, $rrd_index) = @_; 
    my ($ERROR);
    
    foreach $cur_graph_arr (@$cur_graph_status){

	my $cur_graph_block = $$cur_graph_arr[GRAPH_BLOCK];
	my $cur_graph_name  = $$cur_graph_arr[GRAPH_NAME];
	my $cur_graph_id    = $$cur_graph_arr[GRAPH_ID];
	my $cur_graph_value = $$cur_graph_arr[GRAPH_VALUE];

	# Создаем текущие списки полей.

        push @$rrd_index, "$cur_id\t$cur_graph_block\t$cur_graph_name\t$cur_graph_id";


	# Создаем или апдейтим RRD таблицы.
	if (! -d "$cfg_log_dir/$cfg_rrd_dir/$cur_id"){
	    mkdir("$cfg_log_dir/$cfg_rrd_dir/$cur_id",0775);
	}
	my $cur_rrd_file = "$cfg_log_dir/$cfg_rrd_dir/$cur_id/$cur_graph_block.$cur_graph_name.$cur_graph_id.rrd";

	if (! -f "$cur_rrd_file" ){
	    # Создаем RRD базу.
	    my $rrd_pulsation = $cfg_cron_interval*3;
	    my $rrd_name = "var";
	    my $rrs_size = int ($cfg_rrd_store_days*24*60*60/$cfg_cron_interval);

	    RRDs::create ($cur_rrd_file, "--start", $now_time, "--step", $cfg_cron_interval,
	      "DS:$rrd_name:GAUGE:$rrd_pulsation:U:U",
	      "RRA:AVERAGE:0.5:1:$rrs_size",
	      "RRA:MIN:0.5:1:$rrs_size",
	      "RRA:MAX:0.5:1:$rrs_size"
	    );
	    if ($ERROR = RRDs::error) {
		print STDERR "RRD ERROR: create $cur_rrd_file, $0: unable to create rrd: $ERROR\n";
		next;
	    }
	} else {
	    # Апдейтим RRD базу.    
	    RRDs::update ($cur_rrd_file, "$now_time:$cur_graph_value");
	    if ($ERROR = RRDs::error) {
		print STDERR "RRD ERROR: update $cur_rrd_file, $0: unable to update rrd: $ERROR\n";
		next;
	    }
	}	
    }
}



