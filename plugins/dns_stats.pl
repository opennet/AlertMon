#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# dns_stats.pl <query_type> [<min_limit> <max_limit>]
# Анализирует файл со статистикой named'а и выводит число запросов
# указанного типа по сравнению с прошлым вызовом.
# Если named был перезапущен - выводит 0.

#   query_type:
#	success
#	referral
#	nxrrset
#	nxdomain
#	recursion
#	failure

use strict;

my $cfg_stats_file = "/usr/local/bind/etc/namedb/named.stats";
my $cfg_rndc_cmd = "/usr/local/sbin/rndc -s 127.0.0.1 stats";
my $cfg_named_owner = "bind";
my $cfg_request_idle = 250; # Промежуток между выборками.

###########################################################################
if (! defined $ARGV[0]){
    die "Usage: dns_stats.pl <query_type> [<min_limit> <max_limit>]\n";
}
my $query_type = $ARGV[0];
my $min_limit = $ARGV[1] || "none";
my $max_limit = $ARGV[2] || "none";
my $old_val = 0;
my $new_val = 0;

if (-f $cfg_stats_file){

    # Если есть необходимость, генерируем итерацию с новой выборкой статистики.
    if ((stat("$cfg_stats_file"))[9] + $cfg_request_idle < time()){
	rename($cfg_stats_file, "$cfg_stats_file.old");
	my (undef,undef, $uid, $gid) = getpwnam($cfg_named_owner);
	open(STATS, ">$cfg_stats_file");
	close(STATS);
	chown ($uid, $gid, $cfg_stats_file);
	system($cfg_rndc_cmd);
    }

    # Читаем значения предыдущей выборки.
    $old_val = load_stats("$cfg_stats_file.old", $query_type);

    # Читаем значения для текущей выборки.
    $new_val = load_stats($cfg_stats_file, $query_type);
    
    my $inc_val = $new_val - $old_val;
    if ($inc_val <= 0){
	print "0\n";
    } else {
	if (($min_limit ne "none" && $inc_val < $min_limit) || ($max_limit ne "none" && $inc_val > $max_limit)){
	    print "$inc_val ALERT\n";
	} else {
	    print "$inc_val\n";
	}
    }
} else {
    # первый запуск
    print "0\n";
}

exit;

sub load_stats{
    my ($stats_file, $query_type) = @_;

    open(STATS, "<$stats_file");
    flock(STATS, 1);
    while(<STATS>){
	chomp();
	if (/^$query_type\s+(\d+)$/){
	    close(STATS);
	    return $1;
	}
    }
    close(STATS);
    return 0;
}


