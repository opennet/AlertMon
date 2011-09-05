#!/usr/bin/perl -w
# Создание графиков.
# На выходе графика:
#   - для каждого хоста сводный график (host.png).
#   - для каждого хоста график по виду монитороинга (host.mon.png).
#   - для каждого хоста график по группе графика (host.group.png).
#   - для каждой группы график со всеми хостами (group.png).
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>


# --host, --mon_block --group, --name 

# --days N - сколько дней выводить на графике.
# --skip_days N - сколько дней пропустить, т.е. 1 - начиная со вчера, 7 - с прошлой недели.





##############################################################################


use strict;
use Config::General;
use RRDs;

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

my @cfg_color_map = (
	'E00000','00E000','0000E0','E000E0','303030','E0E000','00E0E0',
	'B00000','00B000','0000B0','B000B0','B070B0','B0B000','00B0B0',
	'900000','009000','000090','900090','909090','909000','009090',
	'500000','005000','000050','500050','505050','505000','005050',
);

my $rrd_start_time = time();
my $config_path = "servermon.conf";

my %host_list=();  # $host_list{host} => 1
my %host_mon_list=();  # $host_list{host.mon}=> [[хост, группа, монитор, имя], ...]
my %host_group_list=();
my %group_list=(); # $group_list{group} => [[хост, группа, монитор, имя], ...]
my $cfg_rrd_base_dir;
my $cfg_log_dir;
my $cfg_graph_dir;
my $cfg_graph_days; # За сколько дней строить график.
my $cfg_graph_width;
my $cfg_graph_height;
my $cfg_graph_bold_level;
my $cfg_verbose_mode;

    # Читаем файл конфигурации
    if ( defined $ARGV[0]) {
	$config_path = $ARGV[0];
    } elsif (! -f $config_path){
	$config_path = "/etc/$config_path";
    }
    if (! -f $config_path){
	die "Configuration file not found.\nUsage: 'create_graph.pl <config_path>' or create /etc/$config_path\n";
    }

    my $config_main_obj = new Config::General(-ConfigFile => $config_path, 
					  -AllowMultiOptions => 'yes',
					  -LowerCaseNames => 'yes');
    my %config_main = $config_main_obj->getall;
    verify_config(\%configuration_def_map, \%config_main);


    # Устанавливаем корневые переменные конфигурации.
    $cfg_verbose_mode = $config_main{"verbose_mode"} ||  $configuration_def_map{"verbose_mode"};
    $cfg_log_dir = $config_main{"log_dir"} || $configuration_def_map{"log_dir"};
    $cfg_rrd_base_dir = "$cfg_log_dir/remote/rrd";
    $cfg_graph_dir = $config_main{"graph_dir"} || $configuration_def_map{"graph_dir"};
    $cfg_graph_days = $config_main{"graph_days"} || $configuration_def_map{"graph_days"};
    $cfg_graph_width = $config_main{"graph_width"} || $configuration_def_map{"graph_width"};
    $cfg_graph_height = $config_main{"graph_height"} || $configuration_def_map{"graph_height"};
    $cfg_graph_bold_level = $config_main{"graph_bold_level"} || $configuration_def_map{"graph_bold_level"};

    # Проверяем значения некоторых параметров конфигурации.
    if (! -d $cfg_log_dir){
	die "Can't stat log directory '$cfg_log_dir'\n";
    }
    if (! -d $cfg_rrd_base_dir){
	die "Can't stat rrd base directory '$cfg_rrd_base_dir'\n";
    }
    if (! -d $cfg_graph_dir){
	die "Can't stat rrd base directory '$cfg_graph_dir'\n";
    }
    if ($cfg_graph_bold_level != 1 && $cfg_graph_bold_level != 2 && $cfg_graph_bold_level != 3){
	$cfg_graph_bold_level = 1;
    }
    

    # Читаем список точек мониторинга.
    load_hosts($cfg_rrd_base_dir, \%host_list);

    # Читаем список параметров мониторинга.
    foreach my $cur_host (keys %host_list){
	load_host_param($cfg_rrd_base_dir, $cur_host, \%host_mon_list, \%group_list, \%host_group_list);
    }

    # График по хостам по типу мониторинга.
    foreach my $cur_host_mon (keys %host_mon_list){
	create_host_mon_graph($cfg_graph_dir, $cfg_rrd_base_dir, $cur_host_mon, \%host_mon_list);
    }

    # График по хостам по группам мониторинга.
    foreach my $cur_host_group (keys %host_group_list){
	create_host_group_graph($cfg_graph_dir, $cfg_rrd_base_dir, $cur_host_group, \%host_group_list);
    }

    # График по сводным группам мониторинга по всем хостам.
    foreach my $cur_group (keys %group_list){
	create_group_graph($cfg_graph_dir, $cfg_rrd_base_dir, $cur_group, \%group_list);
    }


    # Сводный график для каждого хоста.
    foreach my $cur_id (keys %{$config_main{"remote_mon"}}){

	my $cur_title = $config_main{"remote_mon"}->{"$cur_id"}->{"title"} || "$cur_id";
	my @cur_rrd_graph_data = ();
	if (! defined $config_main{"remote_mon"}->{"$cur_id"}->{"sum_graph"}){
	    print STDERR "WARNING: 'sum_graph' not set for $cur_id. Skiping.\n";
	    next;
	}
	print "SUM: $cur_id.png =>\n" unless ($cfg_verbose_mode == 0);
	foreach my $cur_sum_param (@{$config_main{"remote_mon"}->{"$cur_id"}->{"sum_graph"}}){
    	    my $cur_data_mul = 1;
	    my $cur_data_param;
	    if ($cur_sum_param =~ /^\s*$/){
		next;
	    } elsif ($cur_sum_param =~ /\*/){
	        ($cur_data_param, $cur_data_mul) = split(/\s*\*\s*/, $cur_sum_param);
	    } else {
		$cur_data_param = $cur_sum_param;
	    }
	    print "\t$cur_data_param ($cur_data_mul)\n" unless ($cfg_verbose_mode == 0);
    	    my @temp=("$cfg_rrd_base_dir/$cur_id/$cur_data_param.rrd", "$cur_data_param", $cur_data_mul);
	    push @cur_rrd_graph_data, \@temp;
	}
	if (! -d "$cfg_graph_dir/sum"){
	    mkdir("$cfg_graph_dir/sum", 0775);
	}
	create_rrd_graph("$cfg_graph_dir/sum/$cur_id", $cur_title, \@cur_rrd_graph_data);
    }
exit(0);

##############################################################################
# Получение списка хостов.
sub load_hosts{
    my ($base_dir, $host_list) = @_;
    
    opendir(DIR, "$base_dir")|| return -1;
    while (my $cur_dir = readdir(DIR)){ 
	if ($cur_dir !~ /^\./ && -d "$base_dir/$cur_dir"){
	    $$host_list{$cur_dir} = 1;
	}
    }    
    close(DIR);
    return 0;
}

##############################################################################
# Чтение параметров одного хоста.
sub load_host_param{
    my ($base_dir, $cur_host, $host_mon_list, $group_list, $host_group_list) = @_;

    opendir(DIR, "$base_dir/$cur_host")|| return -1;
    while (my $cur_rrd = readdir(DIR)){ 
	if (-f "$base_dir/$cur_host/$cur_rrd" &&  $cur_rrd =~ /^([\d\w\_\-]+)\.([\d\w\_\-]+)\.([\d\w\_\-]+)\.rrd$/){
	    my $cur_group = $1;
	    my $cur_monitor = $2;
	    my $cur_name = $3;
	    my @temp = ($cur_host, $cur_group, $cur_monitor, $cur_name);
	    push @{$$host_mon_list{"$cur_host.$cur_monitor"}}, \@temp;
	    push @{$$host_group_list{"$cur_host.$cur_group"}}, \@temp;
	    push @{$$group_list{$cur_group}}, \@temp;
	}
    }    
    close(DIR);
    return 0;
}

##############################################################################
# Графики по хостам по виду мониторинга
sub create_host_mon_graph{
    my ($graph_dir, $base_dir, $cur_host_mon, $host_mon_list) = @_;

    my @cur_rrd_graph_data = (); # => [[rrd_file, name],....]
    print "HOST: $cur_host_mon.png =>\n" unless ($cfg_verbose_mode == 0);
    foreach my $cur_rrd (@{$host_mon_list{$cur_host_mon}}){
	my $cur_host = $$cur_rrd[0];
	my $cur_group = $$cur_rrd[1];
	my $cur_monitor = $$cur_rrd[2];
	my $cur_name = $$cur_rrd[3];
	print "\t$cur_monitor.$cur_name\n" unless ($cfg_verbose_mode == 0);
	my @temp=("$base_dir/$cur_host/$cur_group.$cur_monitor.$cur_name.rrd", "$cur_monitor.$cur_name", 1);
	push @cur_rrd_graph_data, \@temp;
    }
    if (! -d "$graph_dir/host"){
	mkdir("$graph_dir/host", 0775);
    }
    create_rrd_graph("$graph_dir/host/$cur_host_mon",$cur_host_mon, \@cur_rrd_graph_data);
}

##############################################################################
# Графики по хостам по группам мониторинга
sub create_host_group_graph{
    my ($graph_dir, $base_dir, $cur_host_group, $host_group_list) = @_;

    my @cur_rrd_graph_data = (); # => [[rrd_file, name],....]
    print "HOST: $cur_host_group.png =>\n" unless ($cfg_verbose_mode == 0);
    foreach my $cur_rrd (@{$host_group_list{$cur_host_group}}){
	my $cur_host = $$cur_rrd[0];
	my $cur_group = $$cur_rrd[1];
	my $cur_monitor = $$cur_rrd[2];
	my $cur_name = $$cur_rrd[3];
	print "\t$cur_monitor.$cur_name\n" unless ($cfg_verbose_mode == 0);
	my @temp=("$base_dir/$cur_host/$cur_group.$cur_monitor.$cur_name.rrd", "$cur_monitor.$cur_name", 1);
	push @cur_rrd_graph_data, \@temp;
    }
    if (! -d "$graph_dir/host_group"){
	mkdir("$graph_dir/host_group", 0775);
    }
    create_rrd_graph("$graph_dir/host_group/$cur_host_group",$cur_host_group, \@cur_rrd_graph_data);
}

##############################################################################
# Графики по точкам мониторинга (групповым именам графиков) на хостах 
sub create_name_graph{
    my ($graph_dir, $base_dir, $cur_host_mon, $host_mon_list) = @_;

    my @cur_rrd_graph_data = (); # => [[rrd_file, name],....]
    print "HOST: $cur_host_mon.png =>\n" unless ($cfg_verbose_mode == 0);
    foreach my $cur_rrd (@{$host_mon_list{$cur_host_mon}}){
	my $cur_host = $$cur_rrd[0];
	my $cur_group = $$cur_rrd[1];
	my $cur_monitor = $$cur_rrd[2];
	my $cur_name = $$cur_rrd[3];
	print "\t$cur_monitor.$cur_name\n" unless ($cfg_verbose_mode == 0);
	my @temp=("$base_dir/$cur_host/$cur_group.$cur_monitor.$cur_name.rrd", "$cur_monitor.$cur_name", 1);
	push @cur_rrd_graph_data, \@temp;
    }
    if (! -d "$graph_dir/name"){
	mkdir("$graph_dir/name", 0775);
    }
    create_rrd_graph("$graph_dir/host/$cur_host_mon",$cur_host_mon, \@cur_rrd_graph_data);
}

##############################################################################
# Графики по группам.
sub create_group_graph{
    my ($graph_dir, $base_dir, $cur_group, $group_list) = @_;

    my @cur_rrd_graph_data = (); # => [[rrd_file, name],....]
    print "GROUP: $cur_group.png =>\n" unless ($cfg_verbose_mode == 0);    
    foreach my $cur_rrd (@{$group_list{$cur_group}}){
	my $cur_host = $$cur_rrd[0];
	my $cur_group = $$cur_rrd[1];
	my $cur_monitor = $$cur_rrd[2];
	my $cur_name = $$cur_rrd[3];
	print "\t$cur_host.$cur_name\n" unless ($cfg_verbose_mode == 0);
	my @temp=("$base_dir/$cur_host/$cur_group.$cur_monitor.$cur_name.rrd", "$cur_host.$cur_monitor.$cur_name", 1);
	push @cur_rrd_graph_data, \@temp;
    }
    if (! -d "$graph_dir/group"){
	mkdir("$graph_dir/group", 0775);
    }
    create_rrd_graph("$graph_dir/group/$cur_group", $cur_group, \@cur_rrd_graph_data);
}

##############################################################################
# Непосредственное создание одного RRD графика на основании переденных данных.
sub create_rrd_graph{
    my ($graph_path, $graph_name, $rrd_graph_data) = @_;

    my @def_items=();
    my @line_items=();
    my $line_cnt=0;
    my $color_cnt=0;
    # Формируем параметры для RRD постоителя графиков.
    foreach my $cur_rrd_param (@$rrd_graph_data){
	my $cur_file = $$cur_rrd_param[0];
	my $cur_name = $$cur_rrd_param[1];
	my $cur_mul = $$cur_rrd_param[2];
	if ($cur_mul == 0 ){ 
	    $cur_mul = 1;
	}
	my $cur_var_name= "var$line_cnt";
	if ($cur_mul != 1){
	    push @def_items, "DEF:_$cur_var_name=$cur_file:var:AVERAGE";
	    push @def_items, "CDEF:$cur_var_name=_$cur_var_name,$cur_mul,*",
	} else {
	    push @def_items, "DEF:$cur_var_name=$cur_file:var:AVERAGE";
	}
	push @line_items, "LINE$cfg_graph_bold_level:$cur_var_name#$cfg_color_map[$line_cnt]:$cur_name";
	$line_cnt++;
	$color_cnt++;
	if ($#cfg_color_map < $line_cnt){
	    $color_cnt = 0;
	}
    }
    
    # Строим график
    RRDs::graph( "$graph_path.png.new",
      "--title", "$graph_name", 
      "--start", $rrd_start_time - $cfg_graph_days*24*60*60,
      "--end", $rrd_start_time,
      "--imgformat", "PNG",
      "--width=$cfg_graph_width",
      "--height=$cfg_graph_height",
      "--alt-autoscale-max",
      @def_items,
      @line_items
    );
    rename("$graph_path.png.new", "$graph_path.png");
    if (my $ERROR = RRDs::error) {
        print STDERR "RRD TRAP: graph $graph_path, $0: unable to graph rrd': $ERROR\n";
        return -1;
    }
    return 0;
}

##############################################################################
# Проверка директив в файле конфигурации.
sub verify_config{
    my ($configuration_def_map, $config_main) = @_;
    my ($cur_name, $cur_id, $cur_item);
    
    foreach $cur_name (keys %$config_main){
	if (! defined $$configuration_def_map{$cur_name}){
	    # Удаляем лок файл.
	    die "Error: Incorrect configuration directive '$cur_name'\n";
	}
	if (ref($$configuration_def_map{$cur_name}) eq "HASH"){
	    foreach $cur_id (keys %{$config_main{$cur_name}}){
		if (ref ($$config_main{$cur_name}{$cur_id}) eq "HASH"){
		    foreach $cur_item (keys %{$config_main{$cur_name}{$cur_id}}){
			if (! defined $$configuration_def_map{$cur_name}{$cur_item}){
			        # Удаляем лок файл.
				die "Error: Incorrect configuration directive '$cur_item' in block <$cur_name $cur_id>\n";
			}
		    }
		} else {
		    if (! defined $$configuration_def_map{$cur_name}{$cur_id}){
			# Удаляем лок файл.
			die "Error: Incorrect configuration directive '$cur_id' in block <$cur_name>\n";
		    }
		}
	    }	    
	}
    }
}
