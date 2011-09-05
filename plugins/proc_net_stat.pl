#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# proc_net_stat.pl <ip_conntrack|arp_cache|rt_cache> [<min_limit> <max_limit>]
# Анализирует число активных сессий для ip_conntrack или размер тиблаицы маршрутизации в Linux

use strict;

# Директория для сохранения промежуточного статус-файла.
my $cfg_proc_net_stat_dir = "/proc/net/stat"; 
my %cfg_proc_net_files = ("ip_conntrack" => 1, "arp_cache" => 1, "rt_cache" => 1);

###########################################################################
my $stat_file = $ARGV[0] || "";
my $min_limit = $ARGV[1] || "none";
my $max_limit = $ARGV[2] || "none";

if (! defined $cfg_proc_net_files{$stat_file}){
    die "Usage: proc_net_stat.pl <ip_conntrack|arp_cache|rt_cache> [<min_limit> <max_limit>]\n";
}


if (! -f "$cfg_proc_net_stat_dir/$stat_file"){
    die "$cfg_proc_net_stat_dir/$stat_file not found.";
}

my $cur_entries = load_stats("$cfg_proc_net_stat_dir/$stat_file");
        
if (($min_limit ne "none" && $cur_entries < $min_limit) || ($max_limit ne "none" && $cur_entries > $max_limit)){
    print "$cur_entries ALERT\n";
} else {
    print "$cur_entries\n";
}
exit(0);

#---------------------------------------------------------------------
# Чтение данных из временного файла
sub load_stats{
    my ($stats_file) = @_;

    open(STATS, "<$stats_file") || return -1;
    <STATS>; # Заголовки.
    my $line=<STATS>; # Данные.
    my $entries = (split(/\s+/, $line))[0];
    close(STATS);
    return hex($entries);
}

