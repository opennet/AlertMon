#!/usr/bin/perl -w
# Генерация и вывод одного графика.
# Copyright (c) 1998-2003 by Maxim Chirkov. <mc@tyumen.ru>

# host=host
# mon_block=mon_block
# group=group
# name=name
# id=host.mon_block.name[:mul]

# g_days=N - сколько дней выводить на графике.
# g_skip_days=N - сколько дней пропустить, т.е. 1 - начиная со вчера, 7 - с прошлой недели.
# g_width=N
# g_height=N
# g_bold=N
# g_store_on_disk=file_path
#    print "Content-type: text/plain\n\n";

##############################################################################
use strict;
use Config::General;
use RRDs;
use MCCGI qw(cgi_load_param);
use Getopt::Long;
use CGI::Carp 'fatalsToBrowser'; 

my $config_path = "./servermon.conf";

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

my $cfg_rrd_base_dir;
my $cfg_log_dir;
my $cfg_graph_dir="/usr/local/nagios/htdocs/graph/tmp";
my $cfg_graph_days; # За сколько дней строить график.
my $cfg_graph_width;
my $cfg_graph_height;
my $cfg_graph_bold_level;
my $cfg_verbose_mode;

# -------------------------------------
    # Читаем файл конфигурации
    if (! -f $config_path){
	die "Configuration file $config_path not found.\n";
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
	die "Can't stat rrd graph directory '$cfg_graph_dir'\n";
    }

    # -------------------------------------------------------
    # Анализируем параметры вызова cgi-скрипта.
    my %input=();
    cgi_load_param(\%input);

    my @in_ids = split(/\t/, $input{"id"});
    my @in_hosts = split(/\t/, $input{"host"});
    my @in_groups = split(/\t/, $input{"group"});
    my @in_mon_blocks = split(/\t/, $input{"mon_block"});
    my @in_names = split(/\t/, $input{"name"});

    my $in_g_days = $input{"g_days"} || $cfg_graph_days;
    my $in_g_skip_days = $input{"g_skip_days"} || 0;
    my $in_g_width = $input{"g_width"} || $cfg_graph_width;
    my $in_g_height = $input{"g_height"} || $cfg_graph_height;
    my $in_g_bold = $input{"g_bold"} || $cfg_graph_bold_level;

    # Если параметры передаются через командную строку.
    GetOptions( "id=s", \@in_ids, 
	        "host=s", \@in_hosts, 
		"group=s", \@in_groups,
		"mon_block=s", \@in_mon_blocks,
		"name=s", \@in_names,
		"g_days=s", \$in_g_days,
		"g_skip_days=s", \$in_g_skip_days,
		"g_width=s", \$in_g_width,
		"g_height=s", \$in_g_height,
		"g_bold=s", \$in_g_bold);
    
    # Проверяем значения переданных параметров.
    my %in_ids_mul = ();
    foreach my $cur_id (@in_ids){ 
	if ($cur_id =~ /^([^:]+)\:([\d\.]+)$/){
	    $cur_id = $1;
	    $in_ids_mul{$cur_id} = $2;
	}
	$cur_id =~ s/[^\w\d\-_\.]//g; 
    }
    foreach (@in_names){ s/[^\w\d\-\._]//g; }
    foreach (@in_mon_blocks){ s/[^\w\d\-\._]//g; }
    foreach (@in_hosts){ s/[^\w\d\-\._]//g; }
    foreach (@in_groups){ s/[^\w\d\-\._]//g; }


    if ($in_g_bold < 1 && $in_g_bold > 3){
	$in_g_bold = $cfg_graph_bold_level;
    }

    if ($in_g_width !~ /^\d+$/){
	$in_g_width = $cfg_graph_width;
    }

    if ($in_g_height !~ /^\d+$/){
	$in_g_height = $cfg_graph_height;
    }

    if ($in_g_skip_days !~ /^\d+$/){
	$in_g_skip_days = 0;
    }

    if ($in_g_days !~ /^\d+$/){
	$in_g_days = $cfg_graph_days;
    }

    # -------------------------------------------------------
    # Делаем выборку данных из индекса rrd баз.
    my @rrd_graph_data=();
    my $in_hosts_size = scalar(@in_hosts);
    my $in_groups_size = scalar(@in_groups);
    my $in_mon_blocks_size = scalar(@in_mon_blocks);
    my $in_names_size = scalar(@in_names);
    my $in_ids_size = scalar(@in_ids);
    
    open(RRD_INDEX, "<$cfg_rrd_base_dir/.rrd_index") || die "Can't open rrd index in $cfg_rrd_base_dir\n";
    flock(RRD_INDEX, 2);
    while(<RRD_INDEX>){
	chomp;
	my ($idx_host, $idx_group, $idx_mon_block, $idx_name) = split(/\t/);


	if (($in_ids_size == 0) || (! grep {$_ eq "$idx_host.$idx_mon_block.$idx_name"} @in_ids)){
	    if (($in_hosts_size != 0) && (! grep {$_ eq $idx_host} @in_hosts)){
		next;
	    }
    	    if (($in_groups_size != 0) && (! grep {$_ eq $idx_group} @in_groups)){
		next;
	    }
	    if (($in_mon_blocks_size != 0) && (! grep {$_ eq $idx_mon_block} @in_mon_blocks)){
		next;
	    }
	    if (($in_names_size != 0) && (! grep {$_ eq $idx_name} @in_names)){
		next;
	    }
	    if ($in_hosts_size + $in_groups_size + $in_mon_blocks_size + $in_names_size == 0){
		# Нет маски.
		next;
	    }
	}
	
	#print "DEBUG: host=$idx_host,group=$idx_group,mon_block=$idx_mon_block,name=$idx_name\n\t$idx_host, $idx_group, $idx_mon_block, $idx_name\n";
	
        # $idx_host, $idx_group, $idx_mon_block, $idx_name
	my @temp=("$cfg_rrd_base_dir/$idx_host/$idx_group.$idx_mon_block.$idx_name.rrd", "$idx_host.$idx_mon_block.$idx_name", $in_ids_mul{"$idx_host.$idx_mon_block.$idx_name"} || 1);
	push @rrd_graph_data, \@temp;
    }
    close(RRD_INDEX);

    # Строим график.
    my $tmp_graph_name="$cfg_graph_dir/tmp.$rrd_start_time." . int(rand(999999)) . "." . $$;
    my $start_time = localtime($rrd_start_time - $in_g_days*24*60*60 - $in_g_skip_days*24*60*60);
    my $end_time = localtime($rrd_start_time - $in_g_skip_days*24*60*60);
    
    create_rrd_graph($tmp_graph_name, "$start_time - $end_time", \@rrd_graph_data);
    print "Expires: Tue, 14 May 1973 09:05:28 GMT\n";
    print "Pragma: no-cache\n";
    print "Content-type: image/png\n\n";
    my $buff;
    open (PNG, "<$tmp_graph_name.png");
    binmode(PNG);
    while (read (PNG, $buff, 1024)) {
	print $buff;
    }
    close (PNG);    
    unlink("$tmp_graph_name.png");
exit;

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
	push @line_items, "LINE$in_g_bold:$cur_var_name#$cfg_color_map[$line_cnt]:$cur_name";
	$line_cnt++;
	$color_cnt++;
	if ($#cfg_color_map < $line_cnt){
	    $color_cnt = 0;
	}
    }
    if (scalar (@line_items) == 0){
	die "Null graph !!!";
    }
    # Строим график
    RRDs::graph( "$graph_path.png.new",
      "--title", "$graph_name", 
      "--start", $rrd_start_time - $in_g_days*24*60*60 - $in_g_skip_days*24*60*60,
      "--end", $rrd_start_time - $in_g_skip_days*24*60*60,
      "--imgformat", "PNG",
      "--width=$in_g_width",
      "--height=$in_g_height",
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

