#!/usr/bin/perl -w
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Cron: */5 * * * * cd /usr/local/alertmon; ./topmon.pl
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>

use Config::General;

use constant DEF_EXEC_TIMEOUT	=> 10;

use constant PS_USER	=> 0;
use constant PS_VSIZE	=> 1;
use constant PS_RSSIZE	=> 2;
use constant PS_PCPU	=> 3;
use constant PS_CPUTIME => 4;
use constant PS_COMMAND => 5;

use constant NET_IP => 0;
use constant NET_PORT => 1;
use constant NET_NUM => 2;

use constant PROC_TYPE_MON => 0;
use constant PROC_TYPE_SIZE_MON => 1;
use constant PROC_TYPE_RSS_MON => 2;
use constant PROC_TYPE_NETSTAT => 3;
use constant PROC_TYPE_LISTEN => 4;

use constant PROC_GROUP_BY_ALL => 0;
use constant PROC_GROUP_BY_PROC => 1;
use constant PROC_GROUP_BY_USER => 2;
use constant PROC_GROUP_BY_PROC_USER => 3;

use constant NETSTAT_GROUP_BY_ALL => 0;
use constant NETSTAT_GROUP_BY_IP => 1;
use constant NETSTAT_GROUP_BY_PORT => 2;
use constant NETSTAT_GROUP_BY_IP_PORT => 3;

use constant DF_SIZE => 0;
use constant DF_INODE => 1;

use constant NET_CONN => 0;
use constant NET_LISTEN => 1;

use strict;

# Образ файла конфигурации, для проверки правильности составления конфига.

my %configuration_def_map = (
	"verbose_mode"	=> 0,
	"log_dir"	=> "/usr/local/alertmon/toplogs",
	"admin_email"	=> [ "root" ],
	"admin_pager_gate" => [],
	"emergency_email"	=> [],
	"host_name"	=> "localhost",
	"netstat_only_established" => 0,
	"mime_charset"	=> "iso-8859-1",
	"exec_timeout"	=> DEF_EXEC_TIMEOUT,
	"commands_path" => {
		"ps" 		=> "ps",
		"uptime" 	=> "uptime",
		"netstat" 	=> "netstat",
		"df" 		=> "df",
		"sendmail"	=> "/usr/sbin/sendmail"
			    },
	"proc_mon"	=> {
		"email_after_probe"	=> 0,
		"pager_after_probe"	=> 0,
		"emergency_after_probe"	=> 0,
		"group_by"		=> 0,
		"min_limit"		=> "",
		"max_limit"		=> "",
		"proc_mask"		=> "",
		"exclude_proc_mask"	=> "",
		"user_mask"		=> "",
		"exclude_user_mask"	=> "",
		"graph_name"		=> "",
		"action_cmd"		=> "",
		"report_cmd"		=> "",
		"comment"		=> ""
			    },
	"proc_size_mon"	=> {
		"email_after_probe"	=> 0,
		"pager_after_probe"	=> 0,
		"emergency_after_probe"	=> 0,
		"group_by"		=> 0,
		"min_limit"		=> "",
		"max_limit"		=> "",
		"proc_mask"		=> "",
		"exclude_proc_mask"	=> "",
		"user_mask"		=> "",
		"exclude_user_mask"	=> "",
		"graph_name"		=> "",
		"action_cmd"		=> "",
		"report_cmd"		=> "",
		"comment"		=> ""
			    },
	"proc_rss_mon"	=> {
		"email_after_probe"	=> 0,
		"pager_after_probe"	=> 0,
		"emergency_after_probe"	=> 0,
		"group_by"		=> 0,
		"min_limit"		=> "",
		"max_limit"		=> "",
		"proc_mask"		=> "",
		"exclude_proc_mask"	=> "",
		"user_mask"		=> "",
		"exclude_user_mask"	=> "",
		"graph_name"		=> "",
		"action_cmd"		=> "",
		"report_cmd"		=> "",
		"comment"		=> ""
			    },
	"netstat_mon"	=> {
		"email_after_probe"	=> 0,
		"pager_after_probe"	=> 0,
		"emergency_after_probe"	=> 0,
		"group_by"		=> 0,
		"min_limit"		=> "",
		"max_limit"		=> "",
		"ip_mask"		=> "",
		"exclude_ip_mask"	=> "",
		"port_mask"		=> "",
		"exclude_port_mask"	=> "",
		"graph_name"		=> "",
		"action_cmd"		=> "",
		"report_cmd"		=> "",
		"comment"		=> ""
			    },
	"listen_mon"	=> {
		"email_after_probe"	=> 0,
		"pager_after_probe"	=> 0,
		"emergency_after_probe"	=> 0,
		"group_by"		=> 0,
		"min_limit"		=> "",
		"max_limit"		=> "",
		"ip_mask"		=> "",
		"exclude_ip_mask"	=> "",
		"port_mask"		=> "",
		"exclude_port_mask"	=> "",
		"graph_name"		=> "",
		"action_cmd"		=> "",
		"report_cmd"		=> "",
		"comment"		=> ""
			    },
	"disk_mon"	=> {
		"email_after_probe"	=> 0,
		"pager_after_probe"	=> 0,
		"emergency_after_probe"	=> 0,
		"device"		=> "",
		"min_size_limit"	=> "",
		"min_inode_limit"	=> "",
		"graph_name"		=> "",
		"action_cmd"		=> "",
		"report_cmd"		=> "",
		"comment"		=> ""
			    },
	"la_mon"	=> {
		"email_after_probe"	=> 0,
		"pager_after_probe"	=> 0,
		"emergency_after_probe"	=> 0,
		"over_la1"		=> "",
		"over_la5"		=> "",
		"over_la15"		=> "",
		"graph_name"		=> "",
		"action_cmd"		=> "",
		"report_cmd"		=> "",
		"comment"		=> ""
			    },
	"external_mon"	=> {
		"email_after_probe"	=> 0,
		"pager_after_probe"	=> 0,
		"emergency_after_probe"	=> 0,
		"plugin_path"		=> "",
		"plugin_param"		=> "",
		"alert_mask"		=> "",
		"min_limit"		=> "",
		"max_limit"		=> "",
		"graph_name"		=> "",
		"action_cmd"		=> "",
		"report_cmd"		=> "",
		"comment"		=> ""
			    }
				    
);



my $config_path = "topmon.conf";

my $cfg_lock_livetime = 20*60; # Время жизни лока, 20 мин.
my $cfg_lock_file;

# Корневые директивы из файла конигурации.
my $cfg_netstat_only_established; # 1 - Учитываем только активные соединения, 0 - все, включая FIN_WAIT, SYN и т.д.
my $cfg_host_name;
my $cfg_mime_charset;
my $cfg_log_dir;
my $cfg_verbose_mode;
my $cfg_exec_timeout;
my @cfg_admin_email=();
my @cfg_emergency_email=();
my @cfg_admin_pager_gate=();

# <commands_path> директивы
my $cmd_ps;
my $cmd_uptime;
my $cmd_netstat;
my $cmd_df;
my $cmd_sendmail;

my $glob_graph_name="";
my $glob_graph_type="";
my $glob_graph_id="";
my $glob_graph_counter="";


my $now_time = time();
my $text_now_time = localtime($now_time);
my %diskusage_list = ();
my %proc_list = ();
my %proc_counter = ();
my %user_counter = ();
my %proc_user_counter = ();
my %connection_list = ();
my %ip_count_list = ();
my %port_count_list = ();
my %listen_list = ();
my $all_proc_count;
my $all_conn_count;
my $proc_text_dump = "Date: $text_now_time\n\n";
my $net_text_dump = "Date: $text_now_time\n\n";
my $df_text_dump = "Date: $text_now_time\n\n";
my $uptime_1;
my $uptime_5;
my $uptime_15;
my %alert_list = ();
my $tmp;

# SigPipe перехват
sub pipe_sig{
    return 0; 
};
local ($SIG{PIPE}) = \&pipe_sig;

# Обработка аварийного завершения.
sub die_sig{
    # Случай вызова die в eval блоке.
    die @_ if $^S;
    # Удаляем лок.
    if (defined $cfg_lock_file) {
	unlink("$cfg_lock_file");
    }
}
local ($SIG{__DIE__}) = \&die_sig;

# ---------------------------------------------

# Читаем файл конфигурации
if ( defined $ARGV[0]) {
    $config_path = $ARGV[0];
} elsif (! -f $config_path){
    $config_path = "/etc/$config_path";
}
if (! -f $config_path){
    die "Configuration file not found.\nUsage: 'topmon.pl <config_path>' or create /etc/topmon.conf\n";
}
my $config_main_obj = new Config::General(-ConfigFile => $config_path, 
					  -AllowMultiOptions => 'yes',
					  -LowerCaseNames => 'yes');
my %config_main = $config_main_obj->getall;

verify_config(\%configuration_def_map, \%config_main);

# Обрабатываем директивы состоящие из нескольких элементов.
$tmp = $config_main{"admin_email"} || $configuration_def_map{"admin_email"};
    if(ref($tmp) eq "ARRAY"){
	@cfg_admin_email = @{$tmp};
    } else {
	@cfg_admin_email = ($tmp);
    }

$tmp = $config_main{"admin_pager_gate"} || $configuration_def_map{"admin_pager_gate"};
    if(ref($tmp) eq "ARRAY"){
	@cfg_admin_pager_gate = @{$tmp};
    } else {
	@cfg_admin_pager_gate = ($tmp);
    }

$tmp = $config_main{"emergency_email"} || $configuration_def_map{"emergency_email"};
    if(ref($tmp) eq "ARRAY"){
	@cfg_emergency_email = @{$tmp};
    } else {
	@cfg_emergency_email = ($tmp);
    }

# Устанавливаем корневые переменные конфигурации.
    $cfg_netstat_only_established = $config_main{"netstat_only_established"} || $configuration_def_map{"netstat_only_established"};
    $cfg_verbose_mode = $config_main{"verbose_mode"} ||  $configuration_def_map{"verbose_mode"};
    $cfg_exec_timeout = $config_main{"exec_timeout"} || $configuration_def_map{"exec_timeout"};
    $cfg_host_name = $config_main{"host_name"} || $configuration_def_map{"host_name"};
    $cfg_mime_charset = $config_main{"mime_charset"} || $configuration_def_map{"mime_charset"};
    $cfg_log_dir = $config_main{"log_dir"} || $configuration_def_map{"log_dir"};
    if (! -d $cfg_log_dir){
	die "Can't stat log directory '$cfg_log_dir'\n";
    }

# <commands_path> директивы
    $cmd_ps = $config_main{"commands_path"}->{"ps"} || $configuration_def_map{"commands_path"}->{"ps"};
    $cmd_uptime = $config_main{"commands_path"}->{"uptime"} || $configuration_def_map{"commands_path"}->{"uptime"};
    $cmd_netstat = $config_main{"commands_path"}->{"netstat"} || $configuration_def_map{"commands_path"}->{"netstat"};
    $cmd_df = $config_main{"commands_path"}->{"df"} || $configuration_def_map{"commands_path"}->{"df"};
    $cmd_sendmail = $config_main{"commands_path"}->{"sendmail"} || $configuration_def_map{"commands_path"}->{"sendmail"};

# Обрабатываем возможную ситуацию одновременного исполнения двых процессов.
# Проверяем лок файлы.
    $cfg_lock_file = "$cfg_log_dir/topmon.lock";
    if ( -f "$cfg_lock_file"){
	my $act_flag = `ps -auxwww|grep "perl.*topmon.pl"| grep -v grep | wc -l`;
	if ($act_flag != 1){
	    if ((stat($cfg_lock_file))[9] + $cfg_lock_livetime < time()){
		print STDERR "Lock file exists! $act_flag Process already running !!! Lock file timeout. Killing old script. Continuing...\n";
		open(LOCK,"<$cfg_lock_file");
		my $lock_pid = <LOCK>;
		close (LOCK);
		chomp ($lock_pid);
		if ($lock_pid > 10){
		    system("kill", "$lock_pid");
		}
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
	       

# Заполняем таблицы текущих процессов, сетевых соединений и др. информации.

    load_proccess_list(\%proc_list, \%proc_counter, \%user_counter, \%proc_user_counter, \$proc_text_dump);
    load_netstat_list(\%connection_list, \%ip_count_list, \%port_count_list, \%listen_list, \$net_text_dump);
    load_uptime_list(\$uptime_1, \$uptime_5, \$uptime_15);
    load_df_list(\%diskusage_list, \$df_text_dump);

# Проходим поэтапно по всем директивам конфигурации.

# <proc_mon id>
    parse_proc_mon("proc_mon");
# <proc_size_mon id>
    parse_proc_mon("proc_size_mon");
# <proc_rss_mon id>
    parse_proc_mon("proc_rss_mon");
# <netstat_mon id>
    parse_netstat_mon("netstat_mon");
# <listen_mon id>
    parse_netstat_mon("listen_mon");
# <disk_mon id>
    parse_disk_mon();
# <la_mon>
    parse_la_mon();
# <external_mon id>
    parse_external_mon();

close_alerts();
store_graph();

# Удаляем лок файл.
unlink("$cfg_lock_file");

exit(0);





##############################################################################
# ПАРСЕРЫ ДЛЯ КАЖДОГО ВИДА МОНИТОРИНГА.
##############################################################################
# <proc_mon id>  Контроль процессов. Разбор конфига.
# <proc_size_mon id>
# <proc_rss_mon id>
# $cur_proc_type: 0 - proc_mon, 1 - proc_size_mon, 2 - proc_rss_mon.
sub parse_proc_mon{
	my ($cur_proc_type) = @_;
	my ($cur_id);
	my ($cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe, $cur_group_by);
	my ($cur_min_limit, $cur_max_limit, $cur_proc_mask, $cur_exclude_proc_mask);
	my ($cur_user_mask, $cur_exclude_user_mask, $cur_graph_name);
	my ($cur_action_cmd, $cur_report_cmd, $cur_comment);
	my ($alert_flag, $num_proc_type);

    if ($cur_proc_type eq 'proc_mon'){
	$num_proc_type = PROC_TYPE_MON;
    }elsif ($cur_proc_type eq 'proc_size_mon'){
	$num_proc_type = PROC_TYPE_SIZE_MON;
    }elsif ($cur_proc_type eq 'proc_rss_mon'){
	$num_proc_type = PROC_TYPE_RSS_MON;
    }

    foreach $cur_id (keys %{$config_main{"$cur_proc_type"}}){
	 $cur_group_by = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"group_by"} || $configuration_def_map{"$cur_proc_type"}->{"group_by"};
	 $cur_min_limit = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"min_limit"} || $configuration_def_map{"$cur_proc_type"}->{"min_limit"};
	 $cur_max_limit = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"max_limit"} || $configuration_def_map{"$cur_proc_type"}->{"max_limit"};
	 $cur_proc_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"proc_mask"} || $configuration_def_map{"$cur_proc_type"}->{"proc_mask"};
	 $cur_exclude_proc_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"exclude_proc_mask"} || $configuration_def_map{"$cur_proc_type"}->{"exclude_proc_mask"};
	 $cur_user_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"user_mask"} || $configuration_def_map{"$cur_proc_type"}->{"user_mask"};
	 $cur_exclude_user_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"exclude_user_mask"} || $configuration_def_map{"$cur_proc_type"}->{"exclude_user_mask"};

	 $cur_email_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"email_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"email_after_probe"};
	 $cur_pager_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"pager_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"pager_after_probe"};
	 $cur_emergency_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"emergency_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"emergency_after_probe"};
	 $cur_action_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"action_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"action_cmd"};
	 $cur_report_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"report_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"report_cmd"};
	 $cur_comment = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"comment"} || $configuration_def_map{"$cur_proc_type"}->{"comment"};
	 $cur_graph_name = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"graph_name"} || $configuration_def_map{"$cur_proc_type"}->{"graph_name"};

	 my ($alert_msg, $alert_pid, $alert_pname, $alert_user, $graph_counter);
	 if ($cur_group_by eq 'proc'){
	     $cur_group_by = PROC_GROUP_BY_PROC;
	 } elsif ($cur_group_by eq 'user'){
	     $cur_group_by = PROC_GROUP_BY_USER;
	 } elsif ($cur_group_by eq 'proc_user' || $cur_group_by eq 'user_proc'){
	     $cur_group_by = PROC_GROUP_BY_PROC_USER;
	 }
	 	 
	 $alert_flag = check_proc_mon($num_proc_type, $cur_group_by, $cur_min_limit, $cur_max_limit, $cur_proc_mask, 
	                $cur_exclude_proc_mask, $cur_user_mask, $cur_exclude_user_mask,
			\$alert_msg, \$alert_pid, \$alert_pname, \$alert_user, \$graph_counter);
			
	 if ($alert_flag  > 0){
	     # Зарегистрирован факт алерта.

	     # Фомируем сообщение.
	     $cur_comment = insert_macro($cur_comment, $alert_pid, $alert_pname, $alert_user,"","","");
	     $cur_report_cmd = insert_macro($cur_report_cmd, $alert_pid, $alert_pname, $alert_user,"","","");
	     create_alert($cur_proc_type, $cur_id, "$graph_counter: $cur_comment", 
	                  \$alert_msg, $cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe,
			  $cur_report_cmd);
	     
	     # Предпринимаем действие.
	     exec_action(insert_macro($cur_action_cmd, $alert_pid, $alert_pname, $alert_user,"","",""));

	     if ($cfg_verbose_mode > 0){
	         print "Alert. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	         if ($cfg_verbose_mode > 2){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }

	 } else {
	     if ($cfg_verbose_mode > 0){
	         print "Ok. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	    	 if ($cfg_verbose_mode > 3){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }
	 }
         if ($cfg_verbose_mode > 1){
	     print "\tgroup_by: $cur_group_by, min_limit: $cur_min_limit, max_limit: $cur_max_limit, proc_mask: $cur_proc_mask\n";
	     print "\texclude_proc_mask: $cur_exclude_proc_mask, user_mask: $cur_user_mask, exclude_user_mask: $cur_exclude_user_mask\n";
	     print "\temail_after_probe: $cur_email_after_probe, pager_after_probe: $cur_pager_after_probe, emergency_fater_probe: $cur_emergency_after_probe, report_cmd: $cur_report_cmd\n";
	     print "\taction_cmd: $cur_action_cmd, comment: $cur_comment\n";
	 }
	 # Обновляем график.
	 update_graph($cur_proc_type, $cur_id, $cur_graph_name, $graph_counter);
    }

}
# ----------------------------------------
# Непосредственный перебор процессов для выявления алерта.
# $cur_proc_type: 0 - proc_mon, 1 - proc_size_mon, 2 - proc_rss_mon.
# $cur_group_by:   0 - нет группировки, 1 - proc, 2 - user, 3 - proc+user
sub check_proc_mon{
    my ($cur_proc_type, $cur_group_by, $cur_min_limit, $cur_max_limit, $cur_proc_mask, 
        $cur_exclude_proc_mask, $cur_user_mask, $cur_exclude_user_mask,
	$alert_msg, $alert_pid, $alert_pname, $alert_user, $graph_counter) = @_;

    my $cur_pid;
    my ($p_user, $p_size, $p_rssize, $p_pcpu, $p_cputime, $p_command);
    my ($c_proc_counter, $c_user_counter, $c_proc_user_counter);
    my $sum_counter = 0;
    $$alert_msg = "";
    
    foreach my $p_pid (keys %proc_list){
        $p_user = $proc_list{$p_pid}[PS_USER];
        $p_size = $proc_list{$p_pid}[PS_VSIZE];
        $p_rssize = $proc_list{$p_pid}[PS_RSSIZE];
        $p_pcpu = $proc_list{$p_pid}[PS_PCPU];
        $p_cputime = $proc_list{$p_pid}[PS_CPUTIME];
        $p_command = $proc_list{$p_pid}[PS_COMMAND];
	$c_proc_counter = $proc_counter{$p_command};
	$c_user_counter = $user_counter{$p_user};
	$c_proc_user_counter = $proc_user_counter{"$p_command\t$p_user"};

        if (($cur_proc_mask eq '' || $p_command =~ /$cur_proc_mask/) &&
	    ($cur_exclude_proc_mask eq '' || $p_command !~ /$cur_exclude_proc_mask/) &&
	    ($cur_user_mask eq '' || $p_user =~ /$cur_user_mask/) &&
	    ($cur_exclude_user_mask eq '' || $p_user !~ /$cur_exclude_user_mask/)){
    	    
	    # Попадание в диапазон.
	    # proc_mon
	    if ($cur_proc_type == PROC_TYPE_MON){
	    # Группировка
	        if ($cur_group_by == PROC_GROUP_BY_PROC){
		    # Группировка по одинаковым процессам в ОЗУ
		    if ($c_proc_counter > $sum_counter){
			$sum_counter = $c_proc_counter;
			$$alert_pid = $p_pid;
			$$alert_pname = $p_command;
			$$alert_user = $p_user;
    			$$alert_msg = "Proc: $p_command, Counter: $c_proc_counter, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    			$$alert_msg .= "pid\tuser\tsize\trss\tpcpu\tcputime\t\tcommand\n";
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    }elsif($c_proc_counter == $sum_counter){
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    }elsif ($c_proc_counter > $cur_max_limit){
			$$alert_msg .= "!$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    }
		} elsif ($cur_group_by == PROC_GROUP_BY_USER){
		    # Группировка по именам пользователей.
		    if ($c_user_counter > $sum_counter){
			$sum_counter = $c_user_counter;
			$$alert_pid = $p_pid;
			$$alert_pname = $p_command;
			$$alert_user = $p_user;
    			$$alert_msg = "User: $p_user, Counter: $c_user_counter, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    			$$alert_msg .= "pid\tuser\tsize\trss\tpcpu\tcputime\t\tcommand\n";
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    } elsif($c_user_counter == $sum_counter){
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    } elsif ($c_user_counter > $cur_max_limit){
			$$alert_msg .= "!$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    }
		} elsif ($cur_group_by == PROC_GROUP_BY_PROC_USER){
		    # Группировка по одинаковым процессам и именам пользователей.
		    if ($c_proc_user_counter > $sum_counter){
			$sum_counter = $c_proc_user_counter;
			$$alert_pid = $p_pid;
			$$alert_pname = $p_command;
			$$alert_user = $p_user;
    			$$alert_msg = "Proc: $p_command, User: $p_user, Counter: $c_proc_user_counter, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    			$$alert_msg .= "pid\tuser\tsize\trss\tpcpu\tcputime\t\tcommand\n";
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    } elsif($c_proc_user_counter == $sum_counter){
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    } elsif ($c_proc_user_counter > $cur_max_limit){
			$$alert_msg .= "!$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    }
		} else {
		    # Простой счет, без группировки.
    		    $sum_counter++;
		    $$alert_pid = $p_pid;
	    	    $$alert_pname = $p_command;
		    $$alert_user = $p_user;
		    if ($$alert_msg eq ''){
    			$$alert_msg = "Counter: $sum_counter, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
			$$alert_msg .= "pid\tuser\tsize\trss\tpcpu\tcputime\t\tcommand\n";
		    }
		    $$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		}
	    # proc_size_mon
	    # proc_rss_mon
	    } elsif ($cur_proc_type == PROC_TYPE_SIZE_MON){
		    if ($p_size > $sum_counter){
			$sum_counter = $p_size;
			$$alert_pid = $p_pid;
			$$alert_pname = $p_command;
			$$alert_user = $p_user;
    			$$alert_msg = "Proc: $p_command, User: $p_user, Size: $p_size, RSS: $p_rssize, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    			$$alert_msg .= "pid\tuser\tsize\trss\tpcpu\tcputime\t\tcommand\n";
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    } elsif($c_proc_user_counter == $sum_counter){
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    } elsif ($p_size > $cur_max_limit){
			$$alert_msg .= "!$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    }
	    } elsif ($cur_proc_type == PROC_TYPE_RSS_MON){
		    if ($p_rssize > $sum_counter){
			$sum_counter = $p_rssize;
			$$alert_pid = $p_pid;
			$$alert_pname = $p_command;
			$$alert_user = $p_user;
    			$$alert_msg = "Proc: $p_command, User: $p_user, Size: $p_size, RSS: $p_rssize, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    			$$alert_msg .= "pid\tuser\tsize\trss\tpcpu\tcputime\t\tcommand\n";
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    } elsif($c_proc_user_counter == $sum_counter){
			$$alert_msg .= "$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    } elsif ($p_rssize > $cur_max_limit){
			$$alert_msg .= "!$p_pid\t$p_user\t$p_size\t$p_rssize\t$p_pcpu\t$p_cputime\t$p_command\n";
		    }
	    }
	}
    }

    $$graph_counter = $sum_counter;
    if (($cur_min_limit ne '' && $sum_counter < $cur_min_limit) ||
        ($cur_max_limit ne '' && $sum_counter > $cur_max_limit)){
	# Нарушение заданных лимитов.
	return 1;
    }
    return 0;
}

###################################################################
# <netstat_mon id>  Контроль сетевых соединений. Разбор конфига.
sub parse_netstat_mon{
	my ($cur_proc_type) = @_;
	my ($cur_id);
	my ($cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe, $cur_group_by);
	my ($cur_min_limit, $cur_max_limit, $cur_ip_mask, $cur_exclude_ip_mask);
	my ($cur_port_mask, $cur_exclude_port_mask, $cur_graph_name);
	my ($cur_action_cmd, $cur_report_cmd, $cur_comment);
	my ($alert_flag, $num_proc_type);

    if ($cur_proc_type eq 'netstat_mon'){
	$num_proc_type = PROC_TYPE_NETSTAT;
    }elsif ($cur_proc_type eq 'listen_mon'){
	$num_proc_type = PROC_TYPE_LISTEN;
    }

    foreach $cur_id (keys %{$config_main{"$cur_proc_type"}}){


	 $cur_group_by = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"group_by"} || $configuration_def_map{"$cur_proc_type"}->{"group_by"};
	 $cur_min_limit = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"min_limit"} || $configuration_def_map{"$cur_proc_type"}->{"min_limit"};
	 $cur_max_limit = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"max_limit"} || $configuration_def_map{"$cur_proc_type"}->{"max_limit"};
	 $cur_ip_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"ip_mask"} || $configuration_def_map{"$cur_proc_type"}->{"ip_mask"};
	 $cur_exclude_ip_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"exclude_ip_mask"} || $configuration_def_map{"$cur_proc_type"}->{"exclude_ip_mask"};
	 $cur_port_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"port_mask"} || $configuration_def_map{"$cur_proc_type"}->{"port_mask"};
	 $cur_exclude_port_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"exclude_port_mask"} || $configuration_def_map{"$cur_proc_type"}->{"exclude_port_mask"};

	 $cur_email_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"email_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"email_after_probe"};
	 $cur_pager_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"pager_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"pager_after_probe"};
	 $cur_emergency_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"emergency_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"emergency_after_probe"};
	 $cur_action_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"action_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"action_cmd"};
	 $cur_report_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"report_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"report_cmd"};
	 $cur_comment = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"comment"} || $configuration_def_map{"$cur_proc_type"}->{"comment"};
	 $cur_graph_name = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"graph_name"} || $configuration_def_map{"$cur_proc_type"}->{"graph_name"};

	 my ($alert_msg, $alert_ip, $alert_port, $graph_counter);
	 if ($cur_group_by eq 'ip'){
	     $cur_group_by = NETSTAT_GROUP_BY_IP;
	 } elsif ($cur_group_by eq 'port'){
	     $cur_group_by = NETSTAT_GROUP_BY_PORT;
	 } elsif ($cur_group_by eq 'ip_port'){
	     $cur_group_by = NETSTAT_GROUP_BY_IP_PORT;
	 }
         $alert_flag = check_netstat_mon($num_proc_type, $cur_group_by, $cur_min_limit, $cur_max_limit, $cur_ip_mask, 
	                $cur_exclude_ip_mask, $cur_port_mask, $cur_exclude_port_mask,
			\$alert_msg, \$alert_ip, \$alert_port, \$graph_counter);
	 if ($alert_flag  > 0){
	     # Зарегистрирован факт алерта.

	     # Фомируем сообщение.
	     $cur_comment = insert_macro($cur_comment, "", "", "", $alert_ip, $alert_port, "");
	     $cur_report_cmd = insert_macro($cur_report_cmd, "", "", "", $alert_ip, $alert_port, "");
	     create_alert($cur_proc_type, $cur_id, "$graph_counter: $cur_comment", 
	                  \$alert_msg, $cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe,
			  $cur_report_cmd);
	     
	     # Предпринимаем действие.
	     exec_action(insert_macro($cur_action_cmd, "", "", "", $alert_ip, $alert_port, ""));

	     if ($cfg_verbose_mode > 0){
	         print "Alert. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	         if ($cfg_verbose_mode > 2){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }

	 } else {
	     if ($cfg_verbose_mode > 0){
	         print "Ok. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	    	 if ($cfg_verbose_mode > 3){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }
	 }
         if ($cfg_verbose_mode > 1){
	     print "\tgroup_by: $cur_group_by, min_limit: $cur_min_limit, max_limit: $cur_max_limit, ip_mask: $cur_ip_mask\n";
	     print "\texclude_ip_mask: $cur_exclude_ip_mask, port_mask: $cur_port_mask, exclude_port_mask: $cur_exclude_port_mask\n";
	     print "\temail_after_probe: $cur_email_after_probe, pager_after_probe: $cur_pager_after_probe, emergency_after_probe: $cur_emergency_after_probe, report_cmd: $cur_report_cmd\n";
	     print "\taction_cmd: $cur_action_cmd, comment: $cur_comment\n";
	 }
	 # Обновляем график.
	 update_graph($cur_proc_type, $cur_id, $cur_graph_name, $graph_counter);
    }

}
# ----------------------------------------
# Непосредственный перебор активных соединений для выявления алерта.
# $cur_group_by:   0 - нет группировки, 1 - ip, 2 - port, 3 - ip+port
sub check_netstat_mon{
    my ($cur_proc_type, $cur_group_by, $cur_min_limit, $cur_max_limit, $cur_ip_mask, 
        $cur_exclude_ip_mask, $cur_port_mask, $cur_exclude_port_mask,
	$alert_msg, $alert_ip, $alert_port, $graph_counter) = @_;

    my $cur_connect;
    my ($p_port, $p_ip, $p_num, $c_ip_counter, $c_port_counter);
    my $sum_counter = 0;
    $$alert_msg = "";
    my $active_netstat_list;
    
    if ($cur_proc_type == PROC_TYPE_NETSTAT){
	$active_netstat_list = \%connection_list;
    } else {
	$active_netstat_list = \%listen_list;
    }

    foreach $cur_connect (keys %$active_netstat_list){
	if ($cur_proc_type == PROC_TYPE_NETSTAT){
	    # Для активных соединений
	    $p_port = $connection_list{$cur_connect}[NET_PORT];
	    $p_ip = $connection_list{$cur_connect}[NET_IP];
	    $p_num = $connection_list{$cur_connect}[NET_NUM];
    	    $c_ip_counter = $ip_count_list{$p_ip}[NET_CONN];
	    $c_port_counter = $port_count_list{$p_port}[NET_CONN];
	} else {
	    # Для Listen соединений.
	    $p_port = $listen_list{$cur_connect}[NET_PORT];
	    $p_ip = $listen_list{$cur_connect}[NET_IP];
	    $p_num = 1;
    	    $c_ip_counter = $ip_count_list{$p_ip}[NET_LISTEN];
	    $c_port_counter = $port_count_list{$p_port}[NET_LISTEN];
	}

        if (($cur_ip_mask eq '' || $p_ip =~ /$cur_ip_mask/) &&
	    ($cur_exclude_ip_mask eq '' || $p_ip !~ /$cur_exclude_ip_mask/) &&
	    ($cur_port_mask eq '' || $p_port =~ /$cur_port_mask/) &&
	    ($cur_exclude_port_mask eq '' || $p_port !~ /$cur_exclude_port_mask/)){
	    # Попадание в диапазон.

	    # Группировка
	    if ($cur_group_by == NETSTAT_GROUP_BY_IP){
	        # Группировка по одинаковым IP
	        if ($c_ip_counter > $sum_counter){
	    	    $sum_counter = $c_ip_counter;
		    $$alert_ip = $p_ip;
		    $$alert_port = $p_port;
    		    $$alert_msg = "IP: $p_ip, Port: $p_port, All Counter: $p_num, IP Counter: $c_ip_counter, Port Counter: $c_port_counter, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    		    $$alert_msg .= "port\tnum\tip_cnt\tp_cnt\tip\n";
		    $$alert_msg .= "$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}elsif($c_ip_counter == $sum_counter){
		    $$alert_msg .= "$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}elsif ($c_ip_counter > $cur_max_limit){
		    $$alert_msg .= "!$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}
	    } elsif ($cur_group_by == NETSTAT_GROUP_BY_PORT){
	        # Группировка по именам пользователей.
	        if ($c_port_counter > $sum_counter){
	    	    $sum_counter = $c_port_counter;
		    $$alert_ip = $p_ip;
		    $$alert_port = $p_port;
    		    $$alert_msg = "IP: $p_ip, Port: $p_port, All Counter: $p_num, IP Counter: $c_ip_counter, Port Counter: $c_port_counter, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    		    $$alert_msg .= "port\tnum\tip_cnt\tp_cnt\tip\n";
		    $$alert_msg .= "$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}elsif($c_port_counter == $sum_counter){
		    $$alert_msg .= "$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}elsif ($c_port_counter > $cur_max_limit){
		    $$alert_msg .= "!$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}

	    } elsif ($cur_group_by == NETSTAT_GROUP_BY_IP_PORT){
	        # Группировка по одинаковым процессам и именам пользователей.
	        if ($p_num > $sum_counter){
		    $sum_counter = $p_num;
		    $$alert_ip = $p_ip;
		    $$alert_port = $p_port;
    		    $$alert_msg = "IP: $p_ip, Port: $p_port, All Counter: $p_num, IP Counter: $c_ip_counter, Port Counter: $c_port_counter, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    		    $$alert_msg .= "port\tnum\tip_cnt\tp_cnt\tip\n";
		    $$alert_msg .= "$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}elsif($p_num == $sum_counter){
		    $$alert_msg .= "$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}elsif ($p_num > $cur_max_limit){
		    $$alert_msg .= "!$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
		}
	    } else {
		# Простой счет, без группировки.
    		$sum_counter += $p_num;
		$$alert_ip = $p_ip;
		$$alert_port = $p_port;
    		
		if ($$alert_msg eq ''){
		    $$alert_msg = "IP: $p_ip, Port: $p_port, All Counter: $p_num, IP Counter: $c_ip_counter, Port Counter: $c_port_counter, Limits: min: $cur_min_limit, max: $cur_max_limit\n";
    		    $$alert_msg .= "port\tnum\tip_cnt\tp_cnt\tip\n";
		}
	        $$alert_msg .= "$p_port\t$p_num\t$c_ip_counter\t$c_port_counter\t$p_ip\n";
	    }
	}
    }

    $$graph_counter = $sum_counter;
    if (($cur_min_limit ne '' && $sum_counter < $cur_min_limit) ||
        ($cur_max_limit ne '' && $sum_counter > $cur_max_limit)){
	# Нарушение заданных лимитов.
	return 1;
    }
    return 0;
}

###################################################################
# <disk_mon id> Контроль наличия свободного дискового пространства. Разбор конфига.
sub parse_disk_mon{
	my ($cur_id);
	my ($cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe);
	my ($cur_min_size_limit, $cur_min_inode_limit, $cur_device);
	my ($cur_graph_name, $cur_action_cmd, $cur_report_cmd, $cur_comment);
	my ($alert_flag, $num_proc_type);
	my $cur_proc_type = "disk_mon";

    foreach $cur_id (keys %{$config_main{"$cur_proc_type"}}){

	 $cur_min_size_limit = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"min_size_limit"} || $configuration_def_map{"$cur_proc_type"}->{"min_size_limit"};
	 $cur_min_inode_limit = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"min_inode_limit"} || $configuration_def_map{"$cur_proc_type"}->{"min_inode_limit"};
	 $cur_device = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"device"} || $configuration_def_map{"$cur_proc_type"}->{"device"};

	 $cur_email_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"email_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"email_after_probe"};
	 $cur_pager_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"pager_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"pager_after_probe"};
	 $cur_emergency_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"emergency_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"emergency_after_probe"};
	 $cur_action_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"action_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"action_cmd"};
	 $cur_report_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"report_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"report_cmd"};
	 $cur_comment = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"comment"} || $configuration_def_map{"$cur_proc_type"}->{"comment"};
	 $cur_graph_name = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"graph_name"} || $configuration_def_map{"$cur_proc_type"}->{"graph_name"};

	 my ($alert_msg, $alert_device, $graph_counter);

         $alert_flag = check_disk_mon($cur_min_size_limit, $cur_min_inode_limit,
	                $cur_device, \$alert_msg, \$alert_device, \$graph_counter);
	 if ($alert_flag  > 0){
	     # Зарегистрирован факт алерта.

	     # Фомируем сообщение.
	     $cur_comment = insert_macro($cur_comment, "", "", "", "", "", $alert_device);
	     $cur_report_cmd = insert_macro($cur_report_cmd, "", "", "", "", "", $alert_device);
	     create_alert($cur_proc_type, $cur_id, "$graph_counter: $cur_comment", 
	                  \$alert_msg, $cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe, 
			  $cur_report_cmd);
	     
	     # Предпринимаем действие.
	     exec_action(insert_macro($cur_action_cmd, "", "", "", "", "", $alert_device));

	     if ($cfg_verbose_mode > 0){
	         print "Alert. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	         if ($cfg_verbose_mode > 2){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }

	 } else {
	     if ($cfg_verbose_mode > 0){
	         print "Ok. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	    	 if ($cfg_verbose_mode > 3){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }
	 }
         if ($cfg_verbose_mode > 1){
	     print "\tmin_size_limit: $cur_min_size_limit, min_inode_limit: $cur_min_inode_limit, device: $cur_device\n";
	     print "\temail_after_probe: $cur_email_after_probe, pager_after_probe: $cur_pager_after_probe, emergency_after_probe: $cur_emergency_after_probe, report_cmd: $cur_report_cmd\n";
	     print "\taction_cmd: $cur_action_cmd, comment: $cur_comment\n";
	 }
	 # Обновляем график.
	 update_graph($cur_proc_type, $cur_id, $cur_graph_name, $graph_counter);
    }

}
# ----------------------------------------
# Выявление алерта при переполнении диска.
sub check_disk_mon{
    my ($cur_min_size_limit, $cur_min_inode_limit, $cur_device,
	$alert_msg, $alert_device, $graph_counter) = @_;

    my ($p_size, $p_inode);
    $$alert_msg = "";

    $$alert_device = $cur_device;
    if (defined $diskusage_list{$cur_device}[DF_SIZE]){
	$p_size = $diskusage_list{$cur_device}[DF_SIZE];
	$p_inode = $diskusage_list{$cur_device}[DF_INODE];
    }else{
	print STDERR "Unknown device: $cur_device\n";
	$$graph_counter = 0;
	return 0;
    }
    if ($cur_min_size_limit ne ''){
	$$graph_counter = $p_size;
    } else {
	$$graph_counter = $p_inode;
    }
    $$alert_msg = "Device: $cur_device, Size: $p_size, Inodes: $p_inode, Limits: min size - $cur_min_size_limit, min inode - $cur_min_inode_limit\n";
    if ($cur_min_size_limit ne '' && $cur_min_size_limit > $p_size){
	# Нарушение заданных лимитов.
	return 1;
    }
    if ($cur_min_inode_limit ne '' && $cur_min_inode_limit > $p_inode){
	# Нарушение заданных лимитов.
	return 1;
    }
    return 0;
}

###################################################################
# <la_mon id> Контроль LA. Разбор конфига.
sub parse_la_mon{
	my ($cur_id); 
	my ($cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe);
	my ($cur_over_la1, $cur_over_la5, $cur_over_la15);
	my ($cur_graph_name, $cur_action_cmd, $cur_report_cmd, $cur_comment);
	my ($alert_flag, $num_proc_type);
	my $cur_proc_type = "la_mon";

    foreach $cur_id (keys %{$config_main{"$cur_proc_type"}}){

	 $cur_over_la1 = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"over_la1"} || $configuration_def_map{"$cur_proc_type"}->{"over_la1"};
	 $cur_over_la5 = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"over_la5"} || $configuration_def_map{"$cur_proc_type"}->{"over_la5"};
	 $cur_over_la15 = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"over_la15"} || $configuration_def_map{"$cur_proc_type"}->{"over_la15"};

	 $cur_email_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"email_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"email_after_probe"};
	 $cur_pager_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"pager_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"pager_after_probe"};
	 $cur_emergency_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"emergency_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"emergency_after_probe"};
	 $cur_action_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"action_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"action_cmd"};
	 $cur_report_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"report_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"report_cmd"};
	 $cur_comment = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"comment"} || $configuration_def_map{"$cur_proc_type"}->{"comment"};
	 $cur_graph_name = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"graph_name"} || $configuration_def_map{"$cur_proc_type"}->{"graph_name"};

	 my ($alert_msg, $graph_counter);

         $alert_flag = check_la_mon($cur_over_la1, $cur_over_la5, $cur_over_la15,
		    		    \$alert_msg, \$graph_counter);
	 if ($alert_flag  > 0){
	     # Зарегистрирован факт алерта.

	     # Фомируем сообщение.
	     $cur_comment = insert_macro($cur_comment, "", "", "", "", "", "");
	     $cur_report_cmd = insert_macro($cur_report_cmd, "", "", "", "", "", "");
	     create_alert($cur_proc_type, $cur_id, "$graph_counter: $cur_comment", 
	                  \$alert_msg, $cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe,
			  $cur_report_cmd);
	     
	     # Предпринимаем действие.
	     exec_action(insert_macro($cur_action_cmd, "", "", "", "", "", ""));

	     if ($cfg_verbose_mode > 0){
	         print "Alert. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	         if ($cfg_verbose_mode > 2){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }

	 } else {
	     if ($cfg_verbose_mode > 0){
	         print "Ok. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	    	 if ($cfg_verbose_mode > 3){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }
	 }
         if ($cfg_verbose_mode > 1){
	     print "\tla1:$cur_over_la1, la5:$cur_over_la5, la15:$cur_over_la15\n";
	     print "\temail_after_probe: $cur_email_after_probe, pager_after_probe: $cur_pager_after_probe, emergency_after_probe: $cur_emergency_after_probe, report_cmd: $cur_report_cmd\n";
	     print "\taction_cmd: $cur_action_cmd, comment: $cur_comment\n";
	 }
	 # Обновляем график.
	 update_graph($cur_proc_type, $cur_id, $cur_graph_name, $graph_counter);
    }

}
# ----------------------------------------
# Выявление алерта при больших LOAD AVERAGE.
sub check_la_mon{
    my ($cur_over_la1, $cur_over_la5, $cur_over_la15,
	$alert_msg, $graph_counter) = @_;

    $$alert_msg = "";

    if ($cur_over_la1 ne ''){
	$$graph_counter = $uptime_1;
    } elsif ($cur_over_la5 ne ''){
	$$graph_counter = $uptime_5;
    } else {
	$$graph_counter = $uptime_15;
    }

    $$alert_msg = "LA1: $uptime_1, LA5: $uptime_5, LA15: $uptime_15, Limits: LA1 < $cur_over_la1, LA5 < $cur_over_la5, LA15 < $cur_over_la15\n";
    if ($cur_over_la1 ne '' && $cur_over_la1 < $uptime_1){
	# Нарушение заданных лимитов.
	return 1;
    }
    if ($cur_over_la5 ne '' && $cur_over_la5 < $uptime_5){
	# Нарушение заданных лимитов.
	return 1;
    }
    if ($cur_over_la15 ne '' && $cur_over_la15 < $uptime_15){
	# Нарушение заданных лимитов.
	return 1;
    }
    return 0;
}

###################################################################
# <external_mon id> Выхов внешних программ-плагинов. Разбор конфига.
sub parse_external_mon{
	my ($cur_id);
	my ($cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe);
	my ($cur_min_limit, $cur_max_limit);
	my ($cur_alert_mask, $cur_plugin_path, $cur_plugin_param);
	my ($cur_graph_name, $cur_action_cmd, $cur_report_cmd, $cur_comment);
	my ($alert_flag, $num_proc_type);
	my $cur_proc_type = "external_mon";

    foreach $cur_id (keys %{$config_main{"$cur_proc_type"}}){

	 $cur_min_limit = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"min_limit"} || $configuration_def_map{"$cur_proc_type"}->{"min_limit"};
	 $cur_max_limit = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"max_limit"} || $configuration_def_map{"$cur_proc_type"}->{"max_limit"};
	 $cur_alert_mask = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"alert_mask"} || $configuration_def_map{"$cur_proc_type"}->{"alert_mask"};
	 $cur_plugin_path = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"plugin_path"} || $configuration_def_map{"$cur_proc_type"}->{"plugin_path"};
	 $cur_plugin_param = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"plugin_param"} || $configuration_def_map{"$cur_proc_type"}->{"plugin_param"};

	 $cur_email_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"email_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"email_after_probe"};
	 $cur_pager_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"pager_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"pager_after_probe"};
	 $cur_emergency_after_probe = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"emergency_after_probe"} || $configuration_def_map{"$cur_proc_type"}->{"emergency_after_probe"};
	 $cur_action_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"action_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"action_cmd"};
	 $cur_report_cmd = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"report_cmd"} || $configuration_def_map{"$cur_proc_type"}->{"report_cmd"};
	 $cur_comment = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"comment"} || $configuration_def_map{"$cur_proc_type"}->{"comment"};
	 $cur_graph_name = $config_main{"$cur_proc_type"}->{"$cur_id"}->{"graph_name"} || $configuration_def_map{"$cur_proc_type"}->{"graph_name"};

	 my ($alert_msg, $graph_counter);

         $alert_flag = check_external_mon($cur_min_limit, $cur_max_limit,
	                $cur_alert_mask, $cur_plugin_path, $cur_plugin_param,
			\$alert_msg, \$graph_counter);
	 if ($alert_flag  > 0){
	     # Зарегистрирован факт алерта.

	     # Фомируем сообщение.
	     $cur_comment = insert_macro($cur_comment, "", "", "", "", "", "");
	     $cur_report_cmd = insert_macro($cur_report_cmd, "", "", "", "", "", "");
	     create_alert($cur_proc_type, $cur_id, "$graph_counter: $cur_comment", 
	                  \$alert_msg, $cur_email_after_probe, $cur_pager_after_probe, $cur_emergency_after_probe, 
			  $cur_report_cmd);
	     
	     # Предпринимаем действие.
	     exec_action(insert_macro($cur_action_cmd, "", "", "", "", "", ""));

	     if ($cfg_verbose_mode > 0){
	         print "Alert. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	         if ($cfg_verbose_mode > 2){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }

	 } else {
	     if ($cfg_verbose_mode > 0){
	         print "Ok. Block: $cur_proc_type, Id: $cur_id, Counter: $graph_counter.\n";
	    	 if ($cfg_verbose_mode > 3){
		     print "-------------------------------\n$alert_msg\n\n";
		 }
	     }
	 }
         if ($cfg_verbose_mode > 1){
	     print "\tplugin_param: $cur_plugin_param, plugin_path:$cur_plugin_path\n";
	     print "\tmin_limit: $cur_min_limit, max_limit: $cur_max_limit, alert_mask: $cur_alert_mask\n";
	     print "\temail_after_probe: $cur_email_after_probe, pager_after_probe: $cur_pager_after_probe, emergency_after_probe: $cur_emergency_after_probe, report_cmd: $cur_report_cmd\n";
	     print "\taction_cmd: $cur_action_cmd, comment: $cur_comment\n";
	 }
	 # Обновляем график.
	 update_graph($cur_proc_type, $cur_id, $cur_graph_name, $graph_counter);
    }

}
# ----------------------------------------
# Выявление алерта при вызове внешнего обработчика.
sub check_external_mon{
    my ($cur_min_limit, $cur_max_limit,$cur_alert_mask, $cur_plugin_path, 
	$cur_plugin_param, $alert_msg, $graph_counter) = @_;

    my $p_return_str = "";
    $$alert_msg = "";
    if ( ! -x "$cur_plugin_path"){
	print STDERR "Error: Plug-in $cur_plugin_path not found.\n";
	return 0;
    }

    eval {
        local $SIG{ALRM} = sub { print STDERR "timeout during executing plugin: $cur_plugin_path $cur_plugin_param\n"; die "timeout"; };
        alarm($cfg_exec_timeout);
	$p_return_str = `$cur_plugin_path $cur_plugin_param`;
        alarm(0);
    };
    $p_return_str =~ s/[\t\n\r]//g;
    if ($p_return_str =~ /^\s*(\d+).*$/){
	$$graph_counter = $1;
    } else {
	$$graph_counter = 0;
    }

    $$alert_msg = "Plugin: $cur_plugin_path $cur_plugin_param\n";

    if ($p_return_str eq ''){
	$$alert_msg .= "Returned not valid vslue or timeout\n";
	return 1;
    }
    $$alert_msg .= "Return code: $p_return_str, Limits: mask - $cur_alert_mask, min - $cur_min_limit, max - $cur_max_limit\n";

    if ($cur_alert_mask ne '' && $p_return_str =~ /$cur_alert_mask/){
	# Нарушение заданных лимитов.
	return 1;
    }
    if (($cur_min_limit ne '' && $$graph_counter < $cur_min_limit) ||
        ($cur_max_limit ne '' && $$graph_counter > $cur_max_limit)){
	# Нарушение заданных лимитов.
	return 1;
    }
    return 0;
}


##############################################################################
##############################################################################


##############################################################################
# Фомирование хэша с списком процессов в системе.

sub load_proccess_list{
	my ($proc_list, $proc_counter, $user_counter, $proc_user_counter, $text_dump) = @_;
	my ($cur_pid, $cur_command, $cur_user);
	my $all_count = 0;

    open (CMD, "$cmd_ps -axwwwwo pid,user,vsz,rss,pcpu,cputime,command|")|| die "ERROR: Cat't run $cmd_ps\n";
    while (<CMD>){
	$$text_dump .= $_;
	chomp;
	s/[\r\n]//g;
	if (/^\s*(\d+)\s+([^\s]+)\s+(\d+)\s+(\d+)\s+(\d+[\.\,]\d+)\s+([\d\-]+[\:\.\,]\d+[\:\.\,]\d+)\s+(.*)$/){
	    $cur_pid = $1;
    	    $cur_user = $$proc_list{$cur_pid}[PS_USER]    = $2;
            $$proc_list{$cur_pid}[PS_VSIZE]   = $3;
            $$proc_list{$cur_pid}[PS_RSSIZE]  = $4;
	    $$proc_list{$cur_pid}[PS_PCPU]    = $5;
            $$proc_list{$cur_pid}[PS_CPUTIME] = $6;
	    $cur_command = $$proc_list{$cur_pid}[PS_COMMAND] = $7;
	    $$proc_counter{$cur_command}++;
	    $$user_counter{$cur_user}++;
	    $$proc_user_counter{"$cur_command\t$cur_user"}++;
	    $all_count++;
	} else {
	    if ($all_count != 0){
		print "WARNING: invalid line:$_\n";
	    }
	}
    }
    close(CMD);
    return $all_count;
}

##############################################################################
# Фомирование хэша с списком соединений в системе.
sub load_netstat_list{
	my ($connection_list, $ip_count_list, $port_count_list, $listen_list, $text_dump) = @_;
	my ($n_local_ip, $n_local_port, $n_foreign_ip, $n_foreign_port);
	my $all_count = 0;

    open (CMD, "$cmd_netstat -an|")|| die "ERROR: Cat't run $cmd_netstat\n";
    while (<CMD>){
	$$text_dump .= $_;
	chomp;
	my ($n_proto, $n_recv, $n_send, $n_local, $n_foreign, $n_state) = split(/\s+/, lc($_));
	if (($n_proto =~ /^udp/ && $n_state eq "") || ($n_proto =~ /^tcp/ && $n_state eq "listen")){
	    if ( $n_local =~ /^((\d+\.\d+\.\d+\.\d+)|(\*)).((\d+)|(\*))$/){
		my $l_ip = $1;
		my $l_port = $4;
		if ($l_ip =~ /^0\.0\.0\.0$/){
		    $l_ip = "*";
		}
		$$listen_list{"$l_ip:$l_port"}[NET_PORT]=$l_port;
		$$listen_list{"$l_ip:$l_port"}[NET_IP]=$l_ip;
		$$ip_count_list{$l_ip}[NET_LISTEN]++;
		$$port_count_list{$l_port}[NET_LISTEN]++;
	    } else {
		print "WARNING: invalid line:$_\n";
	    }
	}
	if (($n_proto !~ /^tcp/ && $n_proto !~ /^udp/)||($n_local !~ /^(\d+\.\d+\.\d+\.\d+).(\d+)$/)){
	    next;
	}
	$n_local_ip = $1;
	$n_local_port = $2;
	$n_foreign =~ /^(\d+\.\d+\.\d+\.\d+).(\d+)$/;
	$n_foreign_ip = $1;
	$n_foreign_port = $2;
	if ($n_state eq "established" || $cfg_netstat_only_established == 0){
	    $$connection_list{"$n_foreign_ip:$n_local_port"}[NET_PORT] = $n_local_port;
	    $$connection_list{"$n_foreign_ip:$n_local_port"}[NET_IP] = $n_foreign_ip;
	    $$connection_list{"$n_foreign_ip:$n_local_port"}[NET_NUM]++;
    	    $$ip_count_list{$n_foreign_ip}[NET_CONN]++;
	    $$port_count_list{$n_local_port}[NET_CONN]++;
	    $all_count++;
	}
    }
    close (CMD);
    return $all_count;
}

##############################################################################
# Выборка данных по uptime
sub load_uptime_list{
	my ($uptime_1, $uptime_5, $uptime_15) = @_;
	
    my $now_full_uptime=`$cmd_uptime`;
    $now_full_uptime =~ s/[\n\r]//g;
    if ($now_full_uptime =~ /\:\s*([\d\.]+)\,\s*([\d\.]+)\,\s*([\d\.]+)$/){
        $$uptime_1 = $1;
	$$uptime_5 = $2;
        $$uptime_15= $3;
    } else {
	$now_full_uptime =~ s/\,/./g;
	if ($now_full_uptime =~ /\:\s*([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)$/){
    	    $$uptime_1 = $1;
	    $$uptime_5 = $2;
    	    $$uptime_15= $3;
	} else {
	    print STDERR "uptime syntax not supported: '$now_full_uptime'\n";
    	    $$uptime_1 = 0;
	    $$uptime_5 = 0;
    	    $$uptime_15= 0;
	}
    }
}

##############################################################################
# Выборка данных по свободному дисковому пространству
sub load_df_list{
	my ($diskusage_list, $text_dump) = @_;


    open (CMD, "$cmd_df -k|")|| die "ERROR: Cat't run $cmd_df -k\n";
    while (<CMD>){
	$$text_dump .= $_;
	chomp;
	my ($d_dev, $d_blocks, $d_used, $d_free, $d_proc, $d_mount) = split(/\s+/);
	if ($d_dev =~ /^\/dev\/([\w\d\/\.]+)$/){
	    my $cur_dev = $1;
    	    $$diskusage_list{$cur_dev}[DF_SIZE] = $d_free;
	}
    }
    close (CMD);

    open (CMD, "$cmd_df -i|")|| die "ERROR: Cat't run $cmd_df -i\n";
    while (<CMD>){
	$$text_dump .= $_;
	chomp;
	my ($d_dev, $d_blocks, $d_used, $d_free, $d_proc, $d_iused, $d_ifree, $d_iproc, $d_mount) = split(/\s+/);
	if ($d_dev =~ /^\/dev\/([\w\d\/\.]+)$/){
	    my $cur_dev = $1;
	    if (defined $d_mount){
		# FreeBSD
    		$$diskusage_list{$cur_dev}[DF_INODE] = $d_ifree;
	    } else {
		# Linux
    		$$diskusage_list{$cur_dev}[DF_INODE] = $d_free;
	    }
	}
    }
    close (CMD);
}

##############################################################################
# Создание лога алерта и рассылка на email.
sub create_alert{
    my ($block_name, $id_name, $alert_subject, $alert_text, $alertmail_flag, 
	$alertpage_flag, $alertemergency_flag, $report_cmd) = @_;


    my ($log_sec, $log_min, $log_hour, $log_mday, $log_mon, $log_year,
        $log_wday, $log_yday, $log_isdst) = localtime($now_time);
    $log_mon++;
    $log_year += 1900;
    my $cur_log_path = "$cfg_log_dir/$log_year/$log_mon/$log_mday";


    # Создаем директории для дерева, если не созданы ранее.    
    if (! -d "$cfg_log_dir/$log_year"){
	mkdir("$cfg_log_dir/$log_year",0775);
    }
    if (! -d "$cfg_log_dir/$log_year/$log_mon"){
	mkdir("$cfg_log_dir/$log_year/$log_mon",0775);
    }
    if (! -d "$cfg_log_dir/$log_year/$log_mon/$log_mday"){
	mkdir("$cfg_log_dir/$log_year/$log_mon/$log_mday",0775);
    }

    # Дамп процессов.
    open(LOG, ">$cur_log_path/$block_name.$id_name.$log_hour.$log_min.$log_sec.proc")|| print STDERR "Can't create dump file in $cfg_log_dir/$log_year/$log_mon/$log_mday\n";
    flock(LOG, 2);
    print LOG "LA: $uptime_1\t$uptime_5\t$uptime_15\n";
    print LOG $proc_text_dump;
    close(LOG);

    # Дамп сетевых соединений.
    open(LOG, ">$cur_log_path/$block_name.$id_name.$log_hour.$log_min.$log_sec.net")|| print STDERR "Can't create dump file in $cfg_log_dir/$log_year/$log_mon/$log_mday\n";
    flock(LOG, 2);
    print LOG $net_text_dump;
    close(LOG);

    # Результат действия дополнительных команд в отчет.
    if ($report_cmd ne ""){
	$$alert_text .= "\n\n------------------------------------------------------\n$report_cmd:\n";
	open (STATUS, "$report_cmd|") || print STDERR "Can't run sub status proccess $report_cmd\n";
	while (<STATUS>){
	    $$alert_text .= $_;
	}
	close (STATUS);
    }

    # Текстовый блок для текущего алерта
    open(LOG, ">$cur_log_path/$block_name.$id_name.$log_hour.$log_min.$log_sec.txt")|| print STDERR "Can't create info file in $cfg_log_dir/$log_year/$log_mon/$log_mday\n";
    flock(LOG, 2);
    print LOG $alert_subject;
    print LOG "\n\n";
    print LOG $$alert_text;
    if ($report_cmd ne ""){
	print LOG "\n\n------------------------------------------------------\n$report_cmd:\n";
	open (STATUS, "$report_cmd|") || print STDERR "Can't run sub status proccess $report_cmd\n";
	while (<STATUS>){
	    print LOG $_;
	}
	close (STATUS);
    }
    close(LOG);

# Проверка флагового файла.
    my ($tmp_alertmail_flag, $tmp_alertpage_flag, $tmp_alert_iterations);
    my ($tmp_alert_comment, $tmp_alert_text, $tmp_rand_sid);
    
    $alert_list{"$block_name.$id_name"} = 1;
    if (-f "$cfg_log_dir/$block_name.$id_name.act"){
	# Алерт уже был ранее зафиксирован.
	open (ALERT, "<$cfg_log_dir/$block_name.$id_name.act") || print STDERR "Can't open .act file ($block_name.$id_name).\n";
	chomp($tmp_alertmail_flag = <ALERT>);
	chomp($tmp_alertpage_flag = <ALERT>);
	chomp($tmp_alert_iterations = <ALERT>);
	chomp($tmp_alert_text = <ALERT>);
	chomp($tmp_alert_comment = <ALERT>);
	chomp($tmp_rand_sid = <ALERT>);
	close(ALERT);
	$tmp_alert_iterations++;
    } else {
	# первая итерация для текущего алерта
	$tmp_alertmail_flag = $alertmail_flag;
	$tmp_alertpage_flag = $alertpage_flag;
	$tmp_alert_iterations = 1;
	$tmp_rand_sid = int(rand(999999));
	$tmp_alert_text = "$cur_log_path/$block_name.$id_name.$log_hour.$log_min.$log_sec";
	$tmp_alert_comment = "$block_name.$id_name\t$text_now_time\t$alert_subject\t$now_time\t$cfg_host_name";
	# Лог алертов.
	open (SMALL_LOG, ">>$cfg_log_dir/alertlist.log");
        flock(SMALL_LOG, 2);
	print SMALL_LOG "OPEN\t$tmp_alert_comment\n";
        close(SMALL_LOG);
    }
    # Обновляем флаговый файл.
    open (ALERT, ">$cfg_log_dir/$block_name.$id_name.act") || print STDERR "Can't create .act file.\n";
    print ALERT "$tmp_alertmail_flag\n";
    print ALERT "$tmp_alertpage_flag\n";
    print ALERT "$tmp_alert_iterations\n";
    print ALERT "$tmp_alert_text\n";
    print ALERT "$tmp_alert_comment\n";
    print ALERT "$tmp_rand_sid\n";
    close(ALERT);

    # Высылаем предупреждение администратору по email
    if (($alertmail_flag == -1 || $tmp_alertmail_flag == $tmp_alert_iterations)){
	mail_alert(\@cfg_admin_email, "ALERT $cfg_host_name (OPEN $block_name.$id_name): $alert_subject", $alert_text, "$block_name.$id_name.$tmp_rand_sid", "", 0);
    }

    # Высылаем предупреждение администратору по SMS или на пейджер
    if (($alertpage_flag == -1 || $tmp_alertpage_flag == $tmp_alert_iterations)){
	pager_alert(\@cfg_admin_pager_gate, "ALERT $cfg_host_name ($block_name.$id_name): $alert_subject");
    }

    # Высылаем экстренное сообщение
    if (($alertemergency_flag == -1 || $alertemergency_flag == $tmp_alert_iterations)){
	mail_alert(\@cfg_emergency_email, "EMERGENCY $cfg_host_name ($block_name.$id_name): $alert_subject", $alert_text, "", "", 1);
    }

}


##############################################################################
# Рассылка сообщений, при исчезновении алерта.
sub close_alerts{
    
    my ($cur_alert, $cur_alert_name);

    opendir (LOGDIR, "$cfg_log_dir");
    while ($cur_alert = readdir(LOGDIR)){
	if ($cur_alert =~ /^([^\/]+)\.act$/){
	    $cur_alert_name = $1;
	    if (defined $alert_list{"$cur_alert_name"}){
		# Алерт еще активен.
		next;
	    } else {
		my $alertmail_flag = 0;
		my $alertpage_flag = 0;
		my $alertmail_iterations = 0;
		my $alert_rand_sid = 0;
		my $alert_text = "";
		my $alert_comment = "";
		open (ALERT, "<$cfg_log_dir/$cur_alert") || print STDERR "Can't open .act file ($cur_alert).\n";
		chomp($alertmail_flag = <ALERT>);
		chomp($alertpage_flag = <ALERT>);
		chomp($alertmail_iterations = <ALERT>);
		chomp($alert_text = <ALERT>);
		chomp($alert_comment = <ALERT>);
		chomp($alert_rand_sid  = <ALERT>);
		close(ALERT);
		unlink("$cfg_log_dir/$cur_alert");
		# Алерт закрылся. (для -1 и 0 не высылаем, для остальных если уже был первичный алерт)
	        if ($alertmail_flag > 0 && $alertmail_flag <= $alertmail_iterations){
		    mail_alert(\@cfg_admin_email, "ALERT $cfg_host_name (CLOSE $cur_alert_name)", \$alert_comment, "", "$cur_alert_name.$alert_rand_sid", 0);
		}
		# О закрытии на пейджер не сообщаем.
		open (SMALL_LOG, ">>$cfg_log_dir/alertlist.log");
		flock(SMALL_LOG, 2);
		print SMALL_LOG "CLOSE\t$cur_alert_name\t$text_now_time\t$now_time\t$cfg_host_name\n";
		close(SMALL_LOG);
	    }
	}
    }
    closedir(LOGDIR);
}

##############################################################################
# Отправка сообщения по почте.
sub mail_alert{
	my ($emails, $subject, $body_text, $msg_id, $ref_id, $emergency_flag) = @_;

    if (scalar (@$emails) == 0){
	return; # Не указан емайл для отправки алертов.
    }
    open (SENDMAIL, "|$cmd_sendmail -t") || print STDERR "Can't run sendmail\n";
    print SENDMAIL "MIME-Version: 1.0\n";
    print SENDMAIL "Content-Type: text/plain; charset=\"$cfg_mime_charset\"\n";
    print SENDMAIL "Content-Transfer-Encoding: 8bit\n";
    if (defined $msg_id && $msg_id ne ""){
	print SENDMAIL "Message-ID: <$msg_id\@$cfg_host_name>\n";
    }
    if (defined $ref_id && $ref_id ne ""){
	print SENDMAIL "References: <$ref_id\@$cfg_host_name>\n";
	print SENDMAIL "In-Reply-To: <$ref_id\@$cfg_host_name>\n";
    }
    foreach (@$emails){
	if ($cfg_verbose_mode > 0){
	    print "\t\tMAIL TO: $_\n";
	}
	print SENDMAIL "To: $_\n";
    }
    if ( $emergency_flag == 1){
	print SENDMAIL "From: Emergency MON <nobody\@$cfg_host_name>\n";
    }else{
	print SENDMAIL "From: MONITORING <root\@$cfg_host_name>\n";
    }
    print SENDMAIL "Subject: $subject\n\n";
    print SENDMAIL $$body_text;
    print SENDMAIL "\n";
    close (SENDMAIL);

}

##############################################################################
# Отправка сообщения на пейджер по SMS.
sub pager_alert{
	my ($pagers, $body_text) = @_;

    if (scalar (@$pagers) == 0){
	return; # Не указан емайл для отправки алертов.
    }
    foreach (@$pagers){
	my ($mail_to, $mail_subj) = split(/\s+/);
	if ($cfg_verbose_mode > 0){
	    print "\t\tPAGE TO: $mail_to/$mail_subj\n";
	}
        open (SENDMAIL, "|$cmd_sendmail -t") || print STDERR "Can't run sendmail\n";
	print SENDMAIL "MIME-Version: 1.0\n";
        print SENDMAIL "Content-Type: text/plain; charset=\"$cfg_mime_charset\"\n";
	print SENDMAIL "Content-Transfer-Encoding: 8bit\n";
        print SENDMAIL "From: MONITORING <root\@$cfg_host_name>\n";
	print SENDMAIL "To: $mail_to\n";
	print SENDMAIL "Subject: $mail_subj\n\n";
        print SENDMAIL $body_text;
	print SENDMAIL " - $text_now_time\n";
        close (SENDMAIL);
    }
}

##############################################################################
# Подстановка макровставок по маске.
sub insert_macro{
    my ($macro_text, $alert_pid, $alert_pname, $alert_user, $alert_ip, $alert_port, $alert_device) = @_;

    if ($macro_text eq ""){
	return "";
    }
    $macro_text =~ s/\%pid\%/$alert_pid/g;
    $macro_text =~ s/\%pname\%/$alert_pname/g;
    $macro_text =~ s/\%user\%/$alert_user/g;
    $macro_text =~ s/\%ip\%/$alert_ip/g;
    $macro_text =~ s/\%port\%/$alert_port/g;
    $macro_text =~ s/\%device\%/$alert_device/g;
    $macro_text =~ s/\%la1\%/$uptime_1/g;
    $macro_text =~ s/\%la5\%/$uptime_5/g;
    $macro_text =~ s/\%la15\%/$uptime_15/g;
    return $macro_text;
}

##############################################################################
# Запуск программы реакции на алерт.
sub exec_action{
    my ($cur_action_cmd) = @_;

    if ($cur_action_cmd eq ""){
	return 0;
    }

    eval {
        local $SIG{ALRM} = sub { print STDERR "timeout during exec: $cur_action_cmd\n"; die "timeout"; };
        alarm($cfg_exec_timeout);
	system("$cur_action_cmd");
        alarm(0);
   };
}

##############################################################################
# Компановка списка для построения графиков.
# $cfg_log_dir/snmp.status - файл для построение графика,
# первая строка - разделенные табуляцией имена графика.
# вторая строка - разделенные табуляцией имена id.
# третья строка - разделенные табуляцией топовые значения для id.

sub update_graph{
    my ($cur_proc_type, $cur_id, $cur_graph_name, $graph_counter) = @_;

    if ($cur_graph_name eq ""){
	return;
    }

    if ($glob_graph_name ne ""){
	$glob_graph_name .= "\t";
	$glob_graph_type .= "\t";
	$glob_graph_id   .= "\t";
	$glob_graph_counter .= "\t";
    }
    $glob_graph_name .= $cur_graph_name;
    $glob_graph_type .= $cur_proc_type;
    $glob_graph_id   .= $cur_id;
    $glob_graph_counter .= $graph_counter || 0;
}

# Сохраняем информацию для построения графиков на диск.
sub store_graph{

    open (TOP, ">$cfg_log_dir/snmp.status") || print STDERR "Can't create top file: $cfg_log_dir/snmp.status\n";
    flock(TOP, 2);
    print TOP "$glob_graph_name\n";
    print TOP "$glob_graph_type\n";
    print TOP "$glob_graph_id\n";
    print TOP "$glob_graph_counter\n";
    close(TOP);
}

##############################################################################
# Проверка директив в файле конфигурации. 
sub verify_config{
    my ($configuration_def_map, $config_main) = @_;
    my ($cur_name, $cur_id, $cur_item);
    
    foreach $cur_name (keys %$config_main){
	if (! defined $$configuration_def_map{$cur_name}){
	    die "Error: Incorrect configuration directive '$cur_name'\n";
	}
	if (ref($$configuration_def_map{$cur_name}) eq "HASH"){
	    foreach $cur_id (keys %{$config_main{$cur_name}}){
		if (ref ($$config_main{$cur_name}{$cur_id}) eq "HASH"){
		    foreach $cur_item (keys %{$config_main{$cur_name}{$cur_id}}){
			if (! defined $$configuration_def_map{$cur_name}{$cur_item}){
			    die "Error: Incorrect configuration directive '$cur_item' in block <$cur_name $cur_id>\n";
			}
		    }
		} else {
		    if (! defined $$configuration_def_map{$cur_name}{$cur_id}){
			die "Error: Incorrect configuration directive '$cur_id' in block <$cur_name>\n";
		    }
		}
	    }	    
	}
    }
}
