#!/usr/bin/perl -I ./
# - Сводные гроафики по каждому хосту.
# - График по хосту
# - График по группам.
# - График по группам разных хостов.
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>

my $cfg_graph_path = "/usr/local/alertmon/toplogs/servermon/remote/rrd";
my $cfg_href_graph_path = "graph";

my $cfg_template_path = "./templates/show_graph.html";
my $cfg_show_graph_timeout = 24*60*60; # Если график не обновлялся более суток, не показываем его.
my $cfg_rm_graph_timeout = 3*24*60*60; # Если график не обновлялся более 3 суток, удаляем его.

################################################################
use strict;
use MCTemplate qw(print_template load_template);
use MCCGI qw(cgi_load_param);
use Config::General;

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

my %input=();
my %handlers = (
	"sum"		=>	\&h_view_sum,
	"host"		=>	\&h_view_host_mon,
	"host_mon"		=>	\&h_view_host_mon,
	"host_group"		=>	\&h_view_host_group,
	"group"		=>	\&h_view_group,
	"group_mixhost"	=>	\&h_view_group_mixhost,
    );

    print "Content-type: text/html\n\n";
    cgi_load_param(\%input);
    my %item_tpl = load_template("$cfg_template_path", 0);



    my $in_host = $input{"host"};
    my $in_group = $input{"group"};

    $item_tpl{"tpl_HOST"} = $in_host;
    $item_tpl{"tpl_GROUP"} = $in_group;

    # Читаем файл конфигурации
    if (! -f $config_path){
	die "Configuration file not found.\n";
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

    my $in_days = $item_tpl{"tpl_DAYS"} = $input{"days"} || $cfg_graph_days ;
    my $in_skip_days =  $item_tpl{"tpl_SKIP_DAYS"} = $input{"skip_days"} || 0;
    my $in_width =  $item_tpl{"tpl_WIDTH"} = $input{"width"} || $cfg_graph_width;
    my $in_height =  $item_tpl{"tpl_HEIGHT"} = $input{"height"} || $cfg_graph_height;
    $in_days =~ s/[^\d]//g;
    $in_skip_days =~ s/[^\d]//g;
    $in_width =~ s/[^\d]//g;
    $in_height =~ s/[^\d]//g;

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
    # load_hosts($cfg_rrd_base_dir, \%host_list);

    if ($in_host =~ /^[\d\w\-\_]+$/){
        # Читаем список параметров мониторинга.
    	load_host_param($cfg_rrd_base_dir, $in_host, \%host_mon_list, \%group_list, \%host_group_list);
    }


    my $act_flag = 0;
    foreach my $cur_act (keys (%handlers)){
        if (defined $input{"act_$cur_act"}){
		$item_tpl{"tpl_ACTION"} = "act_$cur_act";
		print print_template("header", \%item_tpl);
		$handlers{$cur_act}->();
		$act_flag = 1;
	}
    }
    if ($act_flag == 0){
	print print_template("header", \%item_tpl);
        h_view_sum();
    }

    print print_template("footer", \%item_tpl);    
    exit(0);
# ----------------- END

###############################################################################
sub h_view_sum{
    print print_template("sum_header", \%item_tpl);    

    $item_tpl{"tpl_ACT_LINK"} = "act_host";
    foreach my $cur_id (sort {$a cmp $b } keys %{$config_main{"remote_mon"}}){
        $item_tpl{"tpl_CUR_GROUP"} = $cur_id ;
	$item_tpl{"tpl_IMG_URL"} = "create_one.cgi?g_days=$in_days&g_skip_days=$in_skip_days&g_width=$in_width&g_height=$in_height";
	if (! defined $config_main{"remote_mon"}->{"$cur_id"}->{"sum_graph"}){
	    next;
	}
	#print "SUM: $cur_id.png =>\n" unless ($cfg_verbose_mode == 0);
	#my $cur_title = $config_main{"remote_mon"}->{"$cur_id"}->{"title"} || "$cur_id";
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
	    my ($cur_graph_block,$cur_graph_name,$cur_graph_id) = split(/\./, $cur_data_param);
	    #print "\t$cur_data_param ($cur_data_mul)\n" unless ($cfg_verbose_mode == 0);
    	    #my @temp=("$cfg_rrd_base_dir/$cur_id/$cur_data_param.rrd", "$cur_data_param", $cur_data_mul);
	    #push @cur_rrd_graph_data, \@temp;
	    $item_tpl{"tpl_IMG_URL"} .= "&id=$cur_id.$cur_graph_name.$cur_graph_id:$cur_data_mul";
	}
	#./create_one.cgi --id=opennet.la_mon.la5:100 --id=opennet.netstat_mon.all_conn --id=opennet.proc_mon.max_all  --id=opennet.proc_rss_mon.all_rss:0.001 --id=opennet.proc_mon.max_postgres --id=opennet.proc_mon.max.ftp --g_days=1  --g_skip_days=20

	$item_tpl{"tpl_CUR_HOST"} = $cur_id;
	print print_template("image_block", \%item_tpl);    
    }

    print print_template("sum_footer", \%item_tpl);    

}
###############################################################################
sub h_view_host_mon{
    print print_template("host_header", \%item_tpl);    

    #use Data::Dumper;   print '<pre>' . Dumper(\%host_mon_list) .'</pre>';
    $item_tpl{"tpl_ACT_LINK"} = "act_group";
    $item_tpl{"tpl_CUR_HOST"} = $in_host;
    foreach my $cur_block (keys %host_mon_list){
	$item_tpl{"tpl_IMG_URL"} = "create_one.cgi?g_days=$in_days&g_skip_days=$in_skip_days&g_width=$in_width&g_height=$in_height";
	foreach my $cur_id (@{$host_mon_list{$cur_block}}){
	    $item_tpl{"tpl_IMG_URL"} .= "&id=$$cur_id[0].$$cur_id[2].$$cur_id[3]:1";
	}
	if ($cur_block =~ /^$in_host\.(.*)$/){
	    my $cur_group = $1;
	    $item_tpl{"tpl_CUR_GROUP"} = $cur_group;
	    print print_template("image_block", \%item_tpl);    
	}
    }
    print print_template("host_footer", \%item_tpl);    
}
###############################################################################
sub h_view_host_group{
    print print_template("host_header", \%item_tpl);    

#    use Data::Dumper;   print '<pre>' . Dumper(\%host_group_list) .'</pre>';
    $item_tpl{"tpl_ACT_LINK"} = "act_group";
    $item_tpl{"tpl_CUR_HOST"} = $in_host;
    foreach my $cur_block (keys %host_group_list){
	$item_tpl{"tpl_IMG_URL"} = "create_one.cgi?g_days=$in_days&g_skip_days=$in_skip_days&g_width=$in_width&g_height=$in_height";
	foreach my $cur_id (@{$host_group_list{$cur_block}}){
	    $item_tpl{"tpl_IMG_URL"} .= "&id=$$cur_id[0].$$cur_id[2].$$cur_id[3]:1";
	}
	if ($cur_block =~ /^$in_host\.(.*)$/){
	    my $cur_group = $1;
	    $item_tpl{"tpl_CUR_GROUP"} = $cur_group;
	    print print_template("image_block", \%item_tpl);    
	}
    }
    print print_template("host_footer", \%item_tpl);    

}
###############################################################################
sub h_view_group{

    # Читаем список точек мониторинга.
    load_hosts($cfg_rrd_base_dir, \%host_list);

    foreach my $cur_host (keys %host_list){
        # Читаем список параметров мониторинга.
    	load_host_param($cfg_rrd_base_dir, $cur_host, \%host_mon_list, \%group_list, \%host_group_list);
    }

    #use Data::Dumper;   print '<pre>' . Dumper(\%group_list) .'</pre>';
    $item_tpl{"tpl_ACT_LINK"} = "act_sum";
    $item_tpl{"tpl_CUR_HOST"} = $in_host;
    foreach my $cur_block (keys %group_list){
	$item_tpl{"tpl_IMG_URL"} = "create_one.cgi?g_days=$in_days&g_skip_days=$in_skip_days&g_width=$in_width&g_height=$in_height";
	foreach my $cur_id (@{$group_list{$cur_block}}){
	    $item_tpl{"tpl_IMG_URL"} .= "&id=$$cur_id[0].$$cur_id[2].$$cur_id[3]:1";
	}
	$item_tpl{"tpl_CUR_GROUP"} = $cur_block;
	print print_template("image_block", \%item_tpl);    
    }
    print print_template("host_footer", \%item_tpl);    
}
###############################################################################
sub h_view_group_mixhost{
    print print_template("group_mixhost_header", \%item_tpl);    
    my @graph_items = ();
    load_graph_items("$cfg_graph_path/host", \@graph_items);

    $item_tpl{"tpl_ACT_LINK"} = "act_host";
    $item_tpl{"tpl_CUR_GROUP"} = $in_group;
    foreach my $cur_item (@graph_items){
	if ($cur_item =~ /^([^\.]+)\.$in_group$/){
	    my $cur_host = $1;
	    $item_tpl{"tpl_IMG_URL"} = "$cfg_href_graph_path/host/$cur_item.png";
	    $item_tpl{"tpl_CUR_HOST"} = $cur_host;
	    print print_template("image_block", \%item_tpl);    
	}
    }
    print print_template("group_mixhost_footer", \%item_tpl);    
}
##############################################################################
# Получение списка хостов.
sub load_graph_items{
    my ($base_dir, $data_arr) = @_;

    opendir(DIR, "$base_dir")|| return -1;
    while (my $cur_file = readdir(DIR)){ 
	if (-f "$base_dir/$cur_file" &&  $cur_file =~ /^([\d\w\_\-\.]+)\.rrd$/){
	    my $mod_time = (stat("$base_dir/$cur_file"))[9];
	    my $now_time = time();
	    if ($now_time - $mod_time < $cfg_show_graph_timeout){
		# График актуален.
		my $cur_item = $1;
		push @$data_arr, $cur_item;
	    }
	    if ($now_time - $mod_time > $cfg_rm_graph_timeout){
		# График можно удалить
		unlink("$base_dir/$cur_file");
	    }
	}
    }    
    close(DIR);
    return 0;
}

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
