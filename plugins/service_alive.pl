#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# service_alive.pl <host> <port> <service>
#    Проверка валидного ответа от заданного сервиса. На выходе: 1 - OK или 0 - ALERT.
#    Список поддерживаемых сервисов smtp|pop3|http|ssh|ftp|nntp|imap, полный 
#    список можно найти внутри service_alive.pl
#    Например: plugin_param 192.168.4.1 25 smtp
###########################################################################

# Список tcp сервисов.
%cfg_services = (
    #сервис => [запрос, 	маска приема, 		команда выхода.],
    "http" => ["HEAD /\n", 	"Apache", 		""],
    "pop3" => ["", 		"\\+OK", 		"QUIT\n"],
    "imap" => ["", 		"\\* OK", 		"a1 LOGOUT\n"],
    "smtp" => ["", 		"^220", 		"QUIT\n"],
    "ssh" => ["", 		"SSH", 			"QUIT\n"],
    "ftp" => ["", 		"^220", 		"QUIT\n"],
    "nntp" => ["", 		"^(200|201)", 		"QUIT\n"],
);

#-------------------------------------------------------
use Socket;
use constant TCP_QUERY_TIMEOUT => 10;

if (! defined $ARGV[0] || ! defined $ARGV[1] || ! defined $ARGV[2]){
    die "Usage: service_alive.pl <host> <port> <service>\n";
}

my $cfg_host = $ARGV[0];
my $cfg_port = $ARGV[1];
my $cfg_service = $ARGV[2];
my ($ret_code, $alert_text);

if (! defined $cfg_services{$cfg_service}){
    die "Service '$cfg_service' not defined in cfg_services\n";
}

if (($ret_code = check_service($cfg_host,$cfg_port,TCP_QUERY_TIMEOUT,
		 $cfg_services{$cfg_service}[0], $cfg_services{$cfg_service}[1],
		 $cfg_services{$cfg_service}[2])) != 0){
    if($ret_code == -1){
	$alert_text="host not found.";
    } elsif($ret_code == -2){
	$alert_text="socket error.";
    } elsif($ret_code == -3){
	$alert_text="can't connect.";
    } elsif($ret_code == -4){
	$alert_text="null responce.";
    } elsif($ret_code == -5){
	$alert_text="invalid respond (mask not found).";
    } else {
	$alert_text="unknown error.";
    }
    print "ALERT: $alert_text\n";
    exit(1);
} else {
    print "OK\n";
    exit(0);
}





###########################################################################
# Тестирование доступности сервиса.
# return: 0 - ok -1 - not respond;

sub check_service{
    my( $host, $port, $timeout, $request_cmd, $answer_mask, $quit_cmd) = @_;
    my( $sockaddr, $proto, $thataddr, $that, $rin, $rout);
    my $return_flag = 0;
    $sockaddr = 'S n a4 x8';
    $proto = getprotobyname("tcp");
    $thataddr = (gethostbyname($host))[4] || return -1;
    $that = pack($sockaddr, &AF_INET, $port, $thataddr);
    socket(FS, &AF_INET, &SOCK_STREAM, $proto) || return -2;
    local($/);
    select(FS); 
    $| = 1; 
    select(STDOUT);
    connect(FS, $that) || return -3;
    if ($request_cmd ne ""){
	print FS $request_cmd; 
    }
    $/ = "\n";
    vec($rin, fileno(FS),1) = 1;
    if (select($rout=$rin, undef, undef, $timeout)) {
	while (<FS>){
	    if (/$answer_mask/){
		if ($quit_cmd ne ""){
		    print FS $quit_cmd;
		}
		# close(FS);
		$return_flag = 1;
	    }
	}
    } else {
	return -4;
    }
    close(FS);
    if ($return_flag == 1){
	return 0;
    } else {
	return -5;
    }
}
