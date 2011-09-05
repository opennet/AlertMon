#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# host_alive.pl <host> <tcp|udp|icmp> <packet_size> <tryes>
#     Проверка echo replay (ping) ответа от заданного хоста. На выходе: время ответа или 0 при ошибке.
#     Например: plugin_param 192.168.4.1 icmp 56 5
###########################################################################

# 0 - тестировать icmp через вызов системной утилиты ping, 
# иначе через модуль Net::Ping, который требует для своей работы root привелегий.
$cfg_internal_icmp_ping = 0; #  0 - system ping utitlity instead of perl function.
$cmd_ping="ping";

#-----------------------------------------
use Net::Ping;;

use constant TCP_QUERY_TIMEOUT => 10;

if (! defined $ARGV[0] || ! defined $ARGV[1] || ! defined $ARGV[2] || ! defined $ARGV[3]){
    die "Usage: host_alive.pl <host> <tcp|udp|icmp> <packet_size> <tryes>\n";
}

my $cfg_host = $ARGV[0];
my $cfg_proto = $ARGV[1];
my $cfg_packet_size = $ARGV[2];
my $cfg_tryes = $ARGV[3];
my $responce_time;

if (($cfg_proto eq "icmp") && ($cfg_internal_icmp_ping == 0)){
    $responce_time = system_ping($cfg_host, $cfg_packet_size, $cfg_tryes);

} elsif ($cfg_proto eq "icmp" || $cfg_proto eq "udp" || $cfg_proto eq "tcp"){
    $responce_time = net_ping($cfg_host, $cfg_proto, $cfg_packet_size, $cfg_tryes);

} else {
    die "Invalid protocol, set 'tcp', 'udp' or 'icmp'\n";
}

# $responce_time =~ s/[^\d\-]//g;

if ($responce_time > 0){
    print "$responce_time\n";
    exit(0);
} else {
    print "ALERT\n";
    exit(1);
}

# -----------------------------------------------------
# Проверяем активность хоста используя Net::Ping
sub net_ping {
	my ($host, $protocol, $timeout, $size, $tryes) = @_;
	my ($p, $live, $i);
    
    
   $p = Net::Ping->new($protocol, $timeout, $size) || die "ping error ($protocol,$timeout,$size)\n";
   $live = 1;
   for ($i=0; $i < $tryes; $i++){
       if ($p->ping($host, $timeout)){
	    return 1;
	} else {
	    $live = -1;
	}
    }
    $p->close();
    return $live;
}
#--------------------------------------------------
# Проверяем активность хоста используя внешнюю утилиту ping
sub system_ping{
    my ($host, $size, $tryes) = @_;
    my ($ping_output);
    my $return_code = -2;

    eval {
        local $SIG{ALRM} = sub { print STDERR "timeout during ping\n"; die "timeout"; };
        alarm(TCP_QUERY_TIMEOUT);
	open(PING, "$cmd_ping -q -c $tryes -s $size $host|")|| print STDERR "Can't run $cmd_ping\n";
	while (<PING>){
	    chomp;
	    $ping_output = $_;
	    if ($ping_output =~ /100\% packet loss/i){
		$return_code = -1;
	    }
            if ($ping_output =~ /^round\-trip[^\=]+\=\s*[\d\.\,]+\/([\d\.\,]+)\/[\d\.\,]+.*/i){
		$return_code = $1;
            }
	}
	close(PING);
        alarm(0);
   };
   return $return_code;
}
