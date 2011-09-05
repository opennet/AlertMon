#!/usr/bin/perl
# Monitoring Auto Responce Systems.
# Recomended for local host monitoring purpose.
# (C) by Maxim Chirkov <mc@tyumen.ru>, v2.0
#------
$alert_email="alert\@test.ru";
$log_file="/var/log/alerts.log";
$small_file="/var/log/alerts_sml.log";
$localhost="zhadum.test.ru";	       # Host id.

#------
$internal_icmp_ping=1; #  0 - user ping utitlity instead of perl function.

# Set full path for programs:
$cmd_netstat="netstat -an";
$cmd_ping="ping";
$cmd_mail="/usr/sbin/sendmail -t";
$cmd_ps="ps auxwww";
$cmd_df="df -k";
$cmd_top="top -b -n 1"; # Not used in this version, for old version compatibility only.

#--------------------------------------------------
# Process control ([proccess mask, action for trap, description])
# Контроль работы процессов ([маска для процесса, команда для реакции на падение, название записи])
# Последние два поля (action и description) сейчас и далее являются не обязательными.

@conf_proc=(
    ["web ","/usr/local/apache/bin/apachectl start",""],
    ["web1","/usr/local/apache.webmail/bin/apachectl start",""],
    ["web2","/home/vhome/apache/bin/chroot_ctl.sh start",""],
    ["chrond","/home/vhome/apache/bin/chroot_cron.sh",""],
    ["vsd-inetd","/usr/sbin/vsd-inetd",""],
    ["crond","/usr/sbin/crond",""],
    ["sshd","/usr/sbin/sshd",""],
    ["snmpd","/etc/rc.d/init.d/snmpd start",""],
    ["postmaster","/etc/rc.d/postgres.sh",""],
#    ["squid","/usr/local/squid/bin/proxy.restart",""],
    ["mysql","/etc/rc.d/mysql.server start",""],
    ["searchd","/search/sbin/reload_search.sh",""],
    ["#1005","",""],
    ["#2005","",""],
    ["#3005","",""],
    ["#4005","",""],
    ["#5005","",""],
    ["postfix","",""],
    ["searchd","/search/sbin/reload_search.sh",""],
    ["freechat","/home/chat/reload_freechat.sh &",""],
    ["entropychat","/home/vsluhchat/bin/reload_chat.sh &",""],
    [".*","1 test",""],
    [".*","2 test",""],
    [".*","3 test",""],
    ["web.*httpd","4 test",""],
#    ["pbxreaderd","/home/kt/pbx_reader/pbxreaderd",""],
);

#--------------------------------------------------
# Process overflow control (proccess mask, max limit for running proccess, action for trap, description])
# Контроль перегрузки (маска процесса, максимально допустимое число запущенных процессов, команда для реакции, название записи])

@conf_maxproc=(
    ["web.*httpd","150","","httpd OLD HOSTING flood"],
    ["web1.*httpd","50","","httpd WEBMAIL flood"],
    ["web2.*httpd","150","","httpd NEW HOSTING flood"],
    ["postgres","10","","sql flood"],
    ["sql","20","","sql flood"],
    ["perl","50","","Perl flood"],

    ["#1005.*smtp","30","","SMTP tgma flood"],
    ["#2005.*smtp","30","","SMTP indus flood"],
    ["#3005.*smtp","30","","SMTP tgasa flood"],
    ["#4005.*smtp","30","","SMTP tgngu flood"],
    ["#5005.*smtp","40","","SMTP tgu flood"],
    ["postfix.*smtp","40","","SMTP zhadum flood"],
    ["sh","50","","SH flood"],

);

#--------------------------------------------------
# Free disk space control ([dev mask, min_free_size, action for trap, description])
# Контроль наличия свободного дискового пространства ([устройство, минимум свободных Мб, команда для реакции, название записи])

@conf_diskspace=(
    ["sda5","100000","",""],
    ["sda9","100000","",""],
    ["sda6","100000","",""],
    ["sda7","100000","",""],
    ["sdb1","100000","",""],
    ["sdd1","100000","",""],
    ["sdc1","100000","",""],
);

#--------------------------------------------------
# DNS resolver ([resolved host, dns server, failed action, description])
# Контроль работы DNS ([имя для резолвинга, IP DNS сервера, команда для реакции, название записи])

@conf_dns=(
    ["www.vsluh.ru","212.46.224.3","",""],
    ["www.altavista.com","212.46.227.1","",""],
);

#--------------------------------------------------
# Host alive (ip,protocol(tcp,udp,icmp),timeout,bytes(<1024),tryes,action,description)
# If you don't run scrept from root privilegies set $internal_icmp_ping=0
# Контроль достижимости хостов (IP хоста, протокол(tcp,udp,icmp), таймаут, размер тестового пакета(<1024), число попыток, команда для реакции, название записи)

@conf_ping=(
    ["212.46.224.2","icmp",10,56,5,"","проблемы с офисным каналом"],
    ["217.196.104.233","icmp",10,56,5,"","Rustel проблемы с каналом, если подобные сообщения будут повторяться сообщите на пейджер"],
    ["217.196.97.93","icmp",10,56,5,"","Rustel проблемы с каналом, если подобные сообщения будут повторяться сообщите на пейджер"],
    ["213.247.190.170","icmp",10,56,5,"","Rustel проблемы с каналом, если подобные сообщения будут повторяться сообщите на пейджер"],
    ["194.186.148.209","icmp",10,56,5,"","Teleros проблемы с каналом, если подобные сообщения будут повторяться сообщите на пейджер"],
);

#--------------------------------------------------
# Service activity ([host, port, timeout, request, answer, action, description])
# Проверка работоспособности сетевых сервисов ([хост, номер порта, таймаут, строка запроса, маска ответа, команда для реакции, название записи])

@conf_service=(
    ["hosting.tyumen.ru",80,5,"HEAD /\n","Apache","/etc/apache_raw_restart.sh",""],
    ["vhosting.tyumen.ru",80,5,"HEAD /\n","Apache","/etc/apache_raw_restart.sh",""],
    ["mail.indus.ru",110,5,"QUIT\n","\\+OK","",""],
    ["mail.tgngu.ru",110,5,"QUIT\n","\\+OK","",""],
    ["mail.tgma.ru",110,5,"QUIT\n","\\+OK","",""],
    ["mail.tgasa.ru",110,5,"QUIT\n","\\+OK","",""],
    ["mail.tgu.ru",110,5,"QUIT\n","\\+OK","",""],
    ["www.tura.ru",25,5,"HELO\n\n\nQUIT\n","ESMTP","",""],
);

#--------------------------------------------------
# Externel testers ([test script, ok mask, actions, description])
# Вызов внешних скриптов проверки ([скрипт, маска удачного завершения, команда для реакции, название записи])

@conf_external=(
## 5 min Load Average < 2.00
#    ['a=`uptime|sed "s/[,.]//g"| awk \'{print $11}\'`; if [ $a -lt 200 ]; then echo ALLOK;else echo $a;fi',  "ALLOK","",""],
## Brouken routing
#    ['a=`netstat -rn|grep \'192.168.4.0\'`; if [ -n "$a" ]; then echo ALLOK;else echo ALERT;fi',"ALLOK","/usr/sbin/gdc restart",""],
## Check interface
#    ['a=`ifconfig|grep \'eth0\'`; if [ -n "$a" ]; then echo ALLOK;else echo ALERT;fi',"ALLOK","/usr/sbin/gdc restart",""],
## Proccess number in system
#    ['a=`ps aux|wc -l`; if [ $a -lt 200 ]; then echo ALLOK $a;else echo $a;fi',"ALLOK","",""],
## Network connections
#    ['a=`netstat -an|wc -l`; if [ $a -lt 500 ]; then echo ALLOK $a;else echo $a;fi',"ALLOK","",""],
## Gated troubles
#    ["/etc/if_gated_up.sh","OK","/usr/sbin/gdc restart",""],
);

# Why in v2.0 removed conf_route and conf_interface section ?
# Use Cisco routers instead of gated and zebra or look to conf_external directive.
###########################################################################
###########################################################################
###########################################################################

use Socket;
use Net::DNS;
use Net::Ping;

$cur_time=time();
$alert_text="";

###########################################################################
sub create_alert{
    my($alert_str)=@_;

#### print "ALERT: $alert_str\n";

    open (SENDMAIL, "|$cmd_mail") || print "ERROR: Can not run sendmail";
    print SENDMAIL "MIME-Version: 1.0\n";
    print SENDMAIL "Content-Type: text/plain; charset=\"koi8-r\"\n";
    print SENDMAIL "Content-Transfer-Encoding: 8bit\n";
    print SENDMAIL "To: $alert_email\n";
    print SENDMAIL "From: MONITORING <root\@$localhost>\n";
    print SENDMAIL "Subject: ALERT: $alert_str $localhost\n\n";
    print SENDMAIL $alert_text . "\n";
    close (SENDMAIL);

    open (LOG, ">>$log_file")|| print "ERROR: Can't open log.\n";
    flock(LOG,2);
    print LOG "$cur_time:=======================================================\n";
    print LOG $alert_text;
    close(CMD);
    print LOG "\n$cur_time -------------------------> [$alert_str] is down !!! Trying to up....\n";
    close(LOG);

    open (LOG, ">>$small_file")|| print "ERROR: Can't open small log.\n";
    flock(LOG,2);
    $alert_str =~ s/[\t\n\r]/ /g;
    print LOG "$cur_time\t$num_of_trap\t$alert_str\t$localhost\t$trap_type\n";
    close(LOG);
}
###########################################################################

sub run_prog{
    my ($cmd) = @_;

    if ($cmd ne ""){
### print "RUN: $cmd\n";
	system($cmd);
    }
}
###########################################################################
#------------------------------------------
# Loookup in DNS database
# in: hostname, out - IP address.

sub check_host {
	my($host,$server) = @_;
	my($res, $query, $rr, $live);

  $res = new Net::DNS::Resolver;
  $res->nameservers($server);

  $query = $res->search($host);
  if ($query) {
      foreach $rr ($query->answer) {
          next unless $rr->type eq "A";
          $live = $rr->address;
      }
  } else {
      $live = -1;
  }
  return $live;
}
# -----------------------------------------------------
sub ping_test {
	my ($host,$protocol,$timeout,$size,$tryes) = @_;
	my ($p, $live, $i);
    
    
   $p= Net::Ping->new($protocol,$timeout,$size) || print "ERROR: ping error ($protocol,$timeout,$size)";
   $live=1;
   for ($i=0; $i < $tryes; $i++){
       if ( $p->ping($host,$timeout) ){
	    return 1;
	} else {
	    $live=-1;
	}
    }
    $p->close;
    return $live;
}
###########################################################################
#------------------------------------------
# return: 1 - ok -1 - not respond;
sub check_service{
    my( $host,$port,$timeout,$request,$answer) = @_;

    $sockaddr = 'S n a4 x8';
    $proto = getprotobyname("tcp");
    $thataddr = (gethostbyname($host))[4] || return -1;
    $that = pack($sockaddr, &AF_INET, $port, $thataddr);
    socket(FS, &AF_INET, &SOCK_STREAM, $proto) || return -2;
    local($/);
    select(FS); $| = 1; select(STDOUT);
    connect(FS, $that) || return -3;
    print FS $request; 
    $/ = "\n";
    vec($rin, fileno(FS),1) = 1;
    if (select($rout=$rin, undef, undef, $timeout)) {
	while (<FS>){
	    if (/$answer/){
		close(FS);
		return 1;
	    }
	}
    } else {
	return -4;
    }
    close(FS);
    return -5;
}

###########################################################################
#--------------------------------------
# Process control
%active_proc=();

    open (CMD, "$cmd_ps|")|| print "ERROR: Cat't run $cmd_ps\n";
    while (<CMD>){
	chomp;
	$line=$_;
	foreach $cur_procconf (@conf_proc){
		$cur_proc = @{$cur_procconf}[0];
	    if ($line =~ /$cur_proc/){
		$proc_cnt{$cur_proc}++;
	    }
	}
	foreach $cur_maxprocconf (@conf_maxproc){
	    $cur_proc = @{$cur_maxprocconf}[0];
	    if (($line =~ /$cur_proc/)&&($conf_proc{$cur_proc} eq "")){
		$proc_cnt{$cur_proc}++;
	    }
	}
    }
    close(CMD);
    $num_of_trap=0;
    foreach $cur_procconf (@conf_proc){
    	$cur_proc = @{$cur_procconf}[0];
        $cur_cmd =  @{$cur_procconf}[1];
        $cur_desc =  @{$cur_procconf}[2]||$cur_proc;
	$num_of_trap++;
	$trap_type=1;
	if ($proc_cnt{$cur_proc} == 0){
	    $alert_text=`($cmd_netstat; $cmd_ps)`;
	    run_prog($cur_cmd);
	    create_alert("$cur_desc not found ");
	}
    }
    $num_of_trap=0;

    foreach $cur_maxprocconf (@conf_maxproc){
        $cur_proc = @{$cur_maxprocconf}[0];
        $cur_limit = @{$cur_maxprocconf}[1];
        $cur_cmd = @{$cur_maxprocconf}[2];
        $cur_desc = @{$cur_maxprocconf}[3]||$cur_proc;
	$num_of_trap++;
	$trap_type=2;
	if ($cur_limit < $proc_cnt{$cur_proc}){
	    $alert_text=`($cmd_netstat; $cmd_ps)`;
	    run_prog($cur_cmd);
	    create_alert("$cur_desc overflow $cur_limit");
	}
    }

undef %active_proc;

#--------------------------------------------------
# Free disk space control
    $num_of_trap=0;
    open (CMD, "$cmd_df|")|| print "ERROR: Cat't run $cmd_df\n";
    while (<CMD>){
	chomp;
	$line=$_;
	foreach $cur_diskspace (@conf_diskspace){
	    $cur_disk=@{$cur_diskspace}[0];
	    if ($line =~ /$cur_disk/){
		($d_dev, $d_blocks, $d_used, $d_free, $d_proc, $d_mount) = split(/\s+/,$line);
		$cur_size = @{$cur_diskspace}[1];
	        $cur_cmd = @{$cur_diskspace}[2];
	        $cur_desc = @{$cur_diskspace}[3]||$cur_disk;
		$num_of_trap++;
		$trap_type=3;
		
		if ($d_free < $cur_size){
		    $alert_text=$line;
		    run_prog($cur_cont);
		    create_alert("$cur_desc low free space");
		}
	    }
	}
    }
    close(CMD);

#--------------------------------------------------
# DNS resolver
    $num_of_trap=0;
    foreach $cur_dns (@conf_dns){
	$cur_host = @{$cur_dns}[0];
	$cur_ns = @{$cur_dns}[1];
	$cur_cmd = @{$cur_dns}[2];
	$cur_desc = @{$cur_dns}[3]||$cur_host;
	$num_of_trap++;
	$trap_type=4;

	if (check_host($cur_host, $cur_ns ) == -1){
	    $alert_text="host $cur_host not resolved by server $cur_ns";
	    run_prog($cur_cmd);
	    create_alert("NS $cur_ns query for $cur_desc");
	}
    }

#--------------------------------------------------
# Host alive 
    $num_of_trap=0;
    foreach $cur_ping (@conf_ping){
	($p_ip,$p_protocol,$p_timeout,$p_byte,$p_tryes,$p_action, $p_desc) = @{$cur_ping};
	if ($p_desc eq ""){ 
	    $p_desc=$p_ip;
	}
	$num_of_trap++;
	$trap_type=5;

	if ($protocol eq ""){ $protocol = "udp";}
	if ($timeout == 0){ $timeout=5;}
	if ($size == 0){ $size=56;}
	if ($tryes == 0){ $tryes=1;}

	if (($p_protocol eq "icmp")&&($internal_icmp_ping ==0)){
	    $ping_output=`$cmd_ping -q -c $tryes -i $timeout -s $size $p_ip`;
	    if ($ping_output =~ /100\% packet loss/){
		$alert_text="host $p_ip (proto:$p_protocol, timeout:$p_timeout, size:$p_byte, try:$p_tryes) not alive";
		run_prog($p_action);
		create_alert("$p_desc. host $p_ip not alive");
	    }
	} elsif (ping_test($p_ip,$p_protocol,$p_timeout,$p_byte,$p_tryes) == -1){
	    $alert_text="host $p_ip (proto:$p_protocol, timeout:$p_timeout, size:$p_byte, try:$p_tryes) not alive";
	    run_prog($p_action);
	    create_alert("$p_desc. host $p_ip not alive");
	}
    }

#--------------------------------------------------
# Service activity 
    $num_of_trap=0;
    foreach $cur_service (@conf_service){
	($s_host,$s_port,$s_timeout,$s_request,$s_answer,$s_action, $s_desc) = @{$cur_service};
	if ($s_desc eq ""){ 
	    $s_desc=$s_host;
	}
	$num_of_trap++;
	$trap_type=6;

	if (($ret_code = check_service($s_host,$s_port,$s_timeout,$s_request,$s_answer)) != 1){
	    if($ret_code == -1){
		$alert_text="Service $s_host:$s_port ($s_desc) host not found.";
	    } elsif($ret_code == -2){
		$alert_text="Service $s_host:$s_port ($s_desc) socket error.";
	    } elsif($ret_code == -3){
		$alert_text="Service $s_host:$s_port ($s_desc) can't connect.";
	    } elsif($ret_code == -4){
		$alert_text="Service $s_host:$s_port ($s_desc) null responce.";
	    } elsif($ret_code == -5){
		$alert_text="Service $s_host:$s_port ($s_desc) invalid respond (mask not found).";
	    } else {
		$alert_text="Service $s_host:$s_port ($s_desc) unknown error.";
	    }
	    run_prog($s_action);
	    create_alert("$alert_text");
	}
    }


#--------------------------------------------------
# Externel testers

    $num_of_trap=0;
    foreach $cur_extern (@conf_external){
	($e_script, $e_ok_mask, $e_actions, $e_desc) = @{$cur_extern};
	if ($e_desc eq ""){ 
	    $e_desc=$e_script;
	}
	$num_of_trap++;
	$trap_type=7;
	$live = -1;
        $alert_text="Script $e_script alert:\n";

        open (CMD, "$e_script|")|| print "ERROR: Cat't run $e_script\n";
	while (<CMD>){
	    $alert_text .= $_;
	    if (/$e_ok_mask/){
		$live = 1;
	    }
	}
	close(CMD);
	
	if ($live == -1){
	    run_prog($e_actions);
	    create_alert("Script $e_desc alert");
	}
    }

