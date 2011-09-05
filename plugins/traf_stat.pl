#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# traf_stats.pl <interface> <query_type> [<min_limit> <max_limit>]
# Анализирует счетчики сетевого трафика  и выводит число запросов
# указанного типа по сравнению с прошлым вызовом.

#   query_type:
#	in
#	out
#	in_pkt
#	out_pkt




use strict;

my $cfg_stats_file = "/proc/net/dev";
my $cfg_stats_dump_file = "/usr/local/alertmon/toplogs/traf_stat";
my $cfg_netstat_cmd = "netstat -inb";
my $cfg_request_idle = 550; # Промежуток между выборками.
my %cfg_query_map=(

# cat /proc/net/dev
# Inter-|   Receive                                                |  Transmi
# face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
#   eth0: 8491879   13241    0    0    0     0          0         0  2090814   14118    0    0    0     0       0          0
    'linux' => {
	'in' => 1,
	'out' => 9,
	'in_pkt' => 2,
	'out_pkt' => 10,
    },

# netstat -inb 
# Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
# em0    1500 <Link#1>      00:30:48:56:a7:bc 1023973707     0 1910958698 1255492205     0 2252791936     0
    'bsd' => {
	'in' => 6,
	'out' => 9,
	'in_pkt' => 4,
	'out_pkt' => 7,
    }
);
###########################################################################
if (! defined $ARGV[0]){
    die "Usage: traf_stats.pl <interface> <query_type> [<min_limit> <max_limit>]\n";
}
my $iface = $ARGV[0];
my $query_type = $ARGV[1];
my $min_limit = $ARGV[2] || "none";
my $max_limit = $ARGV[3] || "none";
my $old_val = 0;
my $new_val = 0;


if (-f "$cfg_stats_dump_file.$iface"){

    # Читаем значения для текущей выборки.
    my $stat_now_dump = load_stats($iface, "");
    my $sys_type= pop(@$stat_now_dump);
    
    if (! defined $cfg_query_map{$sys_type}{$query_type}){
	print "-1 ALERT\n";
	exit;
    }

    # Читаем значения предыдущей выборки.
    my $stat_old_dump = load_stats($iface, "$cfg_stats_dump_file.$iface");
    
    my $inc_val = $$stat_now_dump[$cfg_query_map{$sys_type}{$query_type}] - $$stat_old_dump[$cfg_query_map{$sys_type}{$query_type}];
    if ($inc_val <= 0){
	print "0\n";
    } else {
	if (($min_limit ne "none" && $inc_val < $min_limit) || ($max_limit ne "none" && $inc_val > $max_limit)){
	    print "$inc_val ALERT\n";
	} else {
	    print "$inc_val\n";
	}
    }
    # Если есть необходимость, генерируем итерацию с новой выборкой статистики.
    if ((stat("$cfg_stats_dump_file.$iface"))[9] + $cfg_request_idle < time()){
	save_stats("$cfg_stats_dump_file.$iface", $stat_now_dump );
    }
} else {
    # первый запуск
    print "0\n";
    my $stat_dump = load_stats($iface);
    save_stats("$cfg_stats_dump_file.$iface", $stat_dump );
}

exit;

sub load_stats{
    my ($iface, $force_file) = @_;
    my $type = 'null';

    if ($force_file ne ""){
	# старый лог
	open(STATS, "<$force_file");
	$type = 'old';
    } elsif (-f $cfg_stats_file){
	# Linux
	open(STATS, "<$cfg_stats_file");
	$type = 'linux';
    } else {
	# BSD
	open(STATS, "$cfg_netstat_cmd|");
	$type = 'bsd';
    }
	
    while(<STATS>){
        chomp();
        if (/^\s*($iface\:?\s.*)$/){
    	    my @tmp=split(/\s+/, $1);
    	    $tmp[0]=$iface;
    	    push @tmp, $type;
    	    close(STATS);
	    return \@tmp;
	}
    }
    close(STATS);
    my @tmp=();
    return \@tmp;
}

sub save_stats{
    my ($file, $stat_dump ) = @_;

    open(STAT, ">$file.$$");
    print STAT join(' ', @$stat_dump) . "\n";
    close(STAT);
    rename("$file.$$", $file);
}