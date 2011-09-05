#!/usr/bin/perl -I ./
# Отображение текущего статуса и истории алертов.
# Copyright (c) 1998-2004 by Maxim Chirkov. <mc@tyumen.ru>

my $config_path = "./servermon.conf"; 
my $cfg_template_path = "./templates/show_alerts.html";
my $cfg_max_status_columns = 3;
my $cfg_history_lines_per_page = 30;
################################################################
use strict;
use Config::General;
use File::ReadBackwards;
use MCTemplate qw(print_template load_template);
use MCCGI qw(cgi_load_param);

# my %configuration_def_map = ();
my $cfg_remote_dir = "remote";
my $now_time = time();

my %input=();
my %handlers = (
	"status"	=>	\&h_view_status,
	"sum"		=>	\&h_view_sum,
	"history"		=>	\&h_view_history,
	"alerts"		=>	\&h_view_alerts,
    );

    print "Content-type: text/html\n\n";

    # Читаем файл конфигурации
    if (! -f $config_path){
	exit_error("Configuration file $config_path not found.");
    }

    my $config_main_obj = new Config::General(-ConfigFile => $config_path, 
					  -AllowMultiOptions => 'yes',
					  -LowerCaseNames => 'yes');
    my %config_main = $config_main_obj->getall;

#    verify_config(\%configuration_def_map, \%config_main);
    # Устанавливаем базовые переменные конфигурации.
    my $cfg_log_dir = $config_main{"log_dir"};
    if (! -d $cfg_log_dir){
	exit_error("Log directory $cfg_log_dir not found.");
    }
    my %cfg_remote_mon = ();
    foreach my $cur_id (keys %{$config_main{"remote_mon"}}){
	$cfg_remote_mon{$cur_id} = $config_main{"remote_mon"}->{"$cur_id"}->{"snmp_host"} . " ( " . $config_main{"remote_mon"}->{"$cur_id"}->{"title"} . " )";
    }

    # Читаем CGI параметры
    cgi_load_param(\%input);
    my %item_tpl = load_template("$cfg_template_path", 0);
    print print_template("header", \%item_tpl);

    my $in_host = $input{"host"};
    my $in_group = $input{"group"};
    my $in_name = $input{"name"};

    $item_tpl{"tpl_PARAM_HOST"} = $in_host;
    $item_tpl{"tpl_PARAM_GROUP"} = $in_group;
    $item_tpl{"tpl_PARAM_name"} = $in_name;

    my $act_flag = 0;
    foreach my $cur_act (keys (%handlers)){
        if (defined $input{"act_$cur_act"}){
		$handlers{$cur_act}->();
		$act_flag = 1;
	}
    }
    if ($act_flag == 0){
        h_view_sum();
    }

    print print_template("footer", \%item_tpl);    
    exit(0);
# ----------------- END

###############################################################################
# Выход с ошибкой
sub exit_error{
    my ($error_text) = @_;

	print "<html><h1>$error_text</h1></html>";
	die "$error_text\n";
}

###############################################################################
sub h_view_sum{

    h_view_alerts();
    h_view_history();
#    h_view_status();
}
###############################################################################
# Свтодный текущий статус контролируемых хостов.
sub h_view_alerts{
    
    my %act_alerts=();
    # Читаем список состояний алертов с учетом фильтров.
    load_active_alerts(\%act_alerts, $in_host, $in_group);

    print print_template("host_act_sum_header", \%item_tpl);    

    foreach my $cur_host (sort keys %cfg_remote_mon){
	 if ($in_host ne "" && $in_host ne $cur_host) {
	     # Фильтр
	     next;
	 }
	 my $line_counter = 1;
	 $item_tpl{"tpl_CUR_HOST"} = $cur_host;
	 $item_tpl{"tpl_CUR_HOST_INFO"} = $cfg_remote_mon{$cur_host};
	 $item_tpl{"tpl_ALERT_HOST"} = $cur_host;
	 print print_template("host_act_header", \%item_tpl);

	 foreach my $cur_group (keys %{$act_alerts{$cur_host}}){
	    $item_tpl{"tpl_ALERT_GROUP"} = $cur_group;
	    foreach my $cur_name (keys %{$act_alerts{$cur_host}{$cur_group}}){
		$item_tpl{"tpl_ALERT_NAME"} = $cur_name;
		$item_tpl{"tpl_ALERT_INFO"} = $act_alerts{$cur_host}{$cur_group}{$cur_name}{"info"};
		$item_tpl{"tpl_ALERT_TIME"} = localtime($act_alerts{$cur_host}{$cur_group}{$cur_name}{"time"});
		$item_tpl{"tpl_ALERT_TIME"} =~ s/\s+/&nbsp;/g;
		$item_tpl{"tpl_ALERT_LENGTH"} = chk_number_time($now_time - $act_alerts{$cur_host}{$cur_group}{$cur_name}{"time"});
		if (int($line_counter/2) != $line_counter/2){
		    $item_tpl{"tpl_CUR_ORD"}=0;
		} else {
		    $item_tpl{"tpl_CUR_ORD"}=1;
		}
		$line_counter++;
		print print_template("host_act_item", \%item_tpl);
	    }
	 }
	 
	 
	 print print_template("host_act_footer", \%item_tpl);    
    }
    print print_template("host_act_sum_footer", \%item_tpl);    
}

###############################################################################
# Выборка текущего состояния.
sub h_view_status{

    my %current_status=();
    my %items_counter=();
    # Читаем список состояний с учетом фильтров.
    load_current_status(\%current_status, $in_host, $in_group, \%items_counter);

    print print_template("host_status_sum_header", \%item_tpl);

    foreach my $cur_host (sort keys %cfg_remote_mon){
	 if ($in_host ne "" && $in_host ne $cur_host) {
	     # Фильтр
	     next;
	 }
	 my $line_counter = 1;
	 $item_tpl{"tpl_CUR_HOST"} = $cur_host;
	 $item_tpl{"tpl_CUR_HOST_INFO"} = $cfg_remote_mon{$cur_host};
	 $item_tpl{"tpl_STATUS_HOST"} = $cur_host;
	 print print_template("host_status_header", \%item_tpl);

	 foreach my $cur_group (keys %{$current_status{$cur_host}}){
	    $item_tpl{"tpl_STATUS_GROUP"} = $cur_group;
	    foreach my $cur_name (keys %{$current_status{$cur_host}{$cur_group}}){

		$item_tpl{"tpl_STATUS_NAME"} = $cur_name;
		$item_tpl{"tpl_STATUS_GRAPH_GROUP"} = $current_status{$cur_host}{$cur_group}{$cur_name}{"graph_group"};
		$item_tpl{"tpl_STATUS_VALUE"} = $current_status{$cur_host}{$cur_group}{$cur_name}{"value"};

		print print_template("host_status_item", \%item_tpl);
		if ($items_counter{$cur_host} / $cfg_max_status_columns <= $line_counter){
		    print print_template("host_status_item_br", \%item_tpl);
		    $line_counter = 0;
		}	    
		$line_counter++;
	    }
	}
	print print_template("host_status_footer", \%item_tpl);    

    }
    print print_template("host_status_sum_footer", \%item_tpl);    

}

###############################################################################
# История алертов. 
sub h_view_history{

    my $in_lines = $input{"lines"} || $cfg_history_lines_per_page;
    my $in_skip = $input{"skip"} || 0;

    $item_tpl{"tpl_PARAM_SKIP"} = $in_skip;
    $item_tpl{"tpl_PARAM_LINES"} = $in_lines;
    $item_tpl{"tpl_HISTORY_PREV_SKIP"} = $in_skip - $in_lines;
    if ($item_tpl{"tpl_HISTORY_PREV_SKIP"} < 0){
	$item_tpl{"tpl_HISTORY_PREV_SKIP"} = 0;
    }
    $item_tpl{"tpl_HISTORY_NEXT_SKIP"} = $in_skip + $in_lines;

    print print_template("history_header", \%item_tpl);    

    print print_template("history_pager", \%item_tpl);    
    
    my $log_line;
    my $log_line_cnt=0;
    my $log_file = File::ReadBackwards->new( "$cfg_log_dir/$cfg_remote_dir/alertlist.log" ) or  exit_error("Can't open alert log file $cfg_log_dir/$cfg_remote_dir/alertlist.log");
    while( defined( $log_line = $log_file->readline ) ) {
	chomp($log_line);
        my ($s_oper_type, $s_update_time, $s_open_update_time, $s_alert_name, $s_text_alert_time, $s_alert_info, 
            $s_alert_time, $s_alert_host_name, $s_alert_host_id) = split(/\t/, $log_line);
	if ($s_oper_type ne "CLOSE"){
	    # Обрабатываем только закрытые алерты.
	    next;
	}

	if ($log_line_cnt >= $in_lines + $in_skip){
	    # Все алерты страницы показаны.
	    last;
	}
	if ($log_line_cnt < $in_skip){
	    # Не дошли еще до строк которые нужно показывать.
	    $log_line_cnt++;
	    next;
	}

        if ($in_host ne "" && $in_host ne $s_alert_host_id) {
	     # Фильтр
	     next;
	}
	
	my ($cur_group, $cur_name) = split(/\./, $s_alert_name);
        if ($in_name ne "" && $in_name ne $cur_name) {
	     # Фильтр
	     next;
	}

        if ($in_group ne "" && $in_group ne $cur_group) {
	     # Фильтр
	     next;
	}

	$log_line_cnt++;
	$item_tpl{"tpl_HISTORY_LINE_NUM"} = $log_line_cnt;
	$item_tpl{"tpl_HISTORY_START_TIME"} = localtime($s_alert_time);
	$item_tpl{"tpl_HISTORY_START_TIME"} =~ s/\s+/&nbsp;/g;
	$item_tpl{"tpl_HISTORY_STOP_TIME"} = localtime($s_update_time);
	$item_tpl{"tpl_HISTORY_STOP_TIME"} =~ s/\s+/&nbsp;/g;
	$item_tpl{"tpl_HISTORY_LENGTH"} = chk_number_time($s_update_time - $s_alert_time);
	$item_tpl{"tpl_HISTORY_NAME"} = $cur_name;
	$item_tpl{"tpl_HISTORY_GROUP"} = $cur_group;
	$item_tpl{"tpl_HISTORY_HOST"} = $s_alert_host_id || $s_alert_host_name;
	$item_tpl{"tpl_HISTORY_HOST_NAME"} = $s_alert_host_name;
	$item_tpl{"tpl_HISTORY_INFO"} = $s_alert_info;

	if (int($log_line_cnt/2) != $log_line_cnt/2){
	    $item_tpl{"tpl_CUR_ORD"}=0;
	} else {
	    $item_tpl{"tpl_CUR_ORD"}=1;
	}
	print print_template("history_item", \%item_tpl);
    }
    $log_file->close();
    
    print print_template("history_pager", \%item_tpl);
    print print_template("history_footer", \%item_tpl);    
}


###############################################################################
# Читаем список состояний алертов с учетом фильтров ($in_host, $in_group).
sub load_active_alerts{
    my ($act_alerts, $in_host, $in_group) = @_;

    opendir (LOGDIR, "$cfg_log_dir/$cfg_remote_dir") or exit_error("Can't open status directory $cfg_log_dir/$cfg_remote_dir");
    while (my $cur_alert = readdir(LOGDIR)){
	if ($cur_alert =~ /^([^.]+)\.([^.]+)\.([^.]+)\.act$/){
	    my $cur_host = $1;
	    my $cur_group = $2;
	    my $cur_name = $3;
	    if ($in_host ne "" && $in_host ne $cur_host) {
		 # Фильтр
	         next;
	    }
	    if ($in_group ne "" && $in_group ne $cur_group) {
		 # Фильтр
	         next;
	    }
	    # Читаем строку состояния алерта.
	    open(ACT, "<$cfg_log_dir/$cfg_remote_dir/$cur_alert") || next;
	    flock(ACT, 1);
	    my $cur_line = <ACT>;
	    close(ACT);
	    chomp($cur_line);
	    my ($s_update_time, $s_alert_name, $s_text_alert_time, $s_alert_info, 
	        $s_alert_time, $s_alert_host_name) = split(/\t/, $cur_line);

	    $act_alerts->{$cur_host}{$cur_group}{$cur_name}{"time"} = $s_alert_time;
	    $act_alerts->{$cur_host}{$cur_group}{$cur_name}{"info"} = $s_alert_info;
	}
    }
    closedir(LOGDIR);
    return 0;
}
###############################################################################
# Читаем текущее состояние для хостов.
sub load_current_status{
    my ($current_status, $in_host, $in_group, $items_counter) = @_;
    
    opendir (LOGDIR, "$cfg_log_dir/$cfg_remote_dir") or exit_error("Can't open status directory $cfg_log_dir/$cfg_remote_dir");
    while (my $cur_status = readdir(LOGDIR)){
	if ($cur_status =~ /^([^.]+)\.status$/){
	    my $cur_host = $1;
	    if ($in_host ne "" && $in_host ne $cur_host) {
		 # Фильтр
	         next;
	    }
	    # Читаем строку состояния алерта.
	    open(STATUS, "<$cfg_log_dir/$cfg_remote_dir/$cur_status") or next;
	    flock(STATUS, 1);
	    while (<STATUS>){
		chomp;
		my ($s_graph_group, $s_mon_group, $s_name, $s_value) = split(/\t/);
	        $current_status->{$cur_host}{$s_mon_group}{$s_name}{"graph_group"} = $s_graph_group;
	        $current_status->{$cur_host}{$s_mon_group}{$s_name}{"value"} = $s_value;
		$items_counter->{$cur_host}++;
	    }
	    close(STATUS);
	}
    }
    closedir(LOGDIR);
    return 0;

}
###############################################################################
# Вывод времени из секунд в читаемый формат
sub chk_number_time{
    my ($var) = @_;

	my $var_day="";
	my $var_hour="";
	my $var_min="";
	if ($var > 1080000){ # 1 Дн
	    $var_day = int ($var / 86400) . "&nbsp;дн.&nbsp;";
	    $var -= int ($var / 86400) * 86400;
	}
	if ($var > 3600){ # 1 Час
	    $var_hour = int ($var / 3600) . "&nbsp;час.&nbsp;";
	    $var -= int ($var / 3600) * 3600;
	} 
	if ($var > 60){ # 1 Мин
	    $var_min = int ($var / 60) . "&nbsp;мин.&nbsp;";
	    $var -= int ($var / 60) * 60;
	}
	return "$var_day$var_hour$var_min$var&nbsp;сек.";
}
