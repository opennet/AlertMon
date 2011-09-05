#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# ups_apc_stats.pl <L|F|C> <device> [<min_limit> <max_limit>]
# Слежение за параметрами работы источника бесперибойного питания, 
# для оценки температуры в помещении и напряжения в сети.
# L - Напряжение на входе
# F - Частота на входе.
# C - Температура.

use strict;
use Device::SerialPort;

# Директория для сохранения промежуточного статус-файла.
my $cfg_tmp_dir = "/usr/local/alertmon/toplogs"; 

# Промежуток между выборками, без нового парсинга лога.
my $cfg_request_idle = 300; 

###########################################################################
if (! defined $ARGV[1]){
    die "Usage: ups_apc_stats.pl <L|F|C> <device> [<min_limit> <max_limit>]\n";
}
my $sensor_type = $ARGV[0];
my $serial_device = $ARGV[1];
my $min_limit = $ARGV[2] || "none";
my $max_limit = $ARGV[3] || "none";

if (! -c $serial_device){
    die "$serial_device device not exists.";
}

if ($sensor_type !~ /^[LCF]$/ ){
    die "Unknown sensor type '$sensor_type', use L,C,F";
}

    my $stats_file = $serial_device;
    $stats_file =~ s/[^\d\w]//g;
    $stats_file = "$cfg_tmp_dir/" . $stats_file . ".ups_apc_stats";

    my $cur_val = 0;
    # Если есть необходимость, генерируем итерацию с новой выборкой статистики.
    if ((! -f $stats_file) || ((stat($stats_file))[9] + $cfg_request_idle < time())){
    	my %status_hash=();
	my $err_code = read_ups_apc_stat($serial_device, \%status_hash);
	if ($err_code  < 0){
	    die "Can't Fetch statistic, error code $err_code";
	}
	store_stats($stats_file, \%status_hash);
	$cur_val = $status_hash{$sensor_type};
    } else {
        # Читаем значения кэша выборки.
        $cur_val = load_stats($stats_file, $sensor_type);
    }
        
    if (($min_limit ne "none" && $cur_val < $min_limit) || ($max_limit ne "none" && $cur_val > $max_limit)){
        print "$cur_val ALERT\n";
    } else {
        print "$cur_val\n";
    }
exit(0);

#---------------------------------------------------------------------
# Чтение данных из временного файла
sub load_stats{
    my ($stats_file, $query_type) = @_;

    open(STATS, "<$stats_file") || return -1;
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

#---------------------------------------------------------------------
# Запись дампа данных во временный файл
sub store_stats{
    my ($stats_file, $sum_stats) = @_;

    open(STATS, ">$stats_file.new") || return -1;
    flock(STATS, 2);
    while( my( $key, $val) = each (%$sum_stats)){
	print STATS "$key $val\n";
    }
    close(STATS);
    rename("$stats_file.new", $stats_file);
    return 0;
}

#---------------------------------------------------------------------
# Чтение информации со статусом USP
sub read_ups_apc_stat {
    my ($serial_device, $stats_hash) = @_;
    my ($count, $str);

    $|= 1;
    my $serial_conn = new Device::SerialPort($serial_device) || return -1;
    $serial_conn->baudrate("2400");
    $serial_conn->databits(8);
    $serial_conn->parity("none");
    $serial_conn->stopbits(1);
    $serial_conn->lookclear();
    $serial_conn->read_const_time(100);
    $serial_conn->read_char_time(5);

    # Start UPS session
    ($count)=$serial_conn->write("Y");
    $str = read_serial_str($serial_conn);
    $str =~ s/[^\d\.\w]//g;
    if ($str ne "SM"){
	# Нет ответа от UPS
	return -2;
    }

    # Напряжение на входе
    ($count)=$serial_conn->write("L");
    $str = read_serial_str($serial_conn);
    $str =~ s/[^\d\.\w]//g;
    if ($str =~ /^[\d\.]+$/){
	$$stats_hash{"L"} = int($str);
    } else {
	return -3;
    }

    # Частота на входе
    ($count)=$serial_conn->write("F");
    $str = read_serial_str($serial_conn);
    $str =~ s/[^\d\.\w]//g;
    if ($str =~ /^[\d\.]+$/){
	$$stats_hash{"F"} = int($str);
    } else {
	return -4;
    }
    
    # Температура
    ($count)=$serial_conn->write("C");
    $str = read_serial_str($serial_conn);
    $str =~ s/[^\d\.\w]//g;
    if ($str =~ /^[\d\.]+$/){
	$$stats_hash{"C"} = int($str);
    } else {
	return -5;
    }
    
    # Конец сеанса.
    ($count)=$serial_conn->write("R");
    $str = read_serial_str($serial_conn);
    $str =~ s/[^\d\.\w]//g;
    if ($str ne "BYE"){
	return -6;
    }
    undef $serial_conn;
    return 0;
}

#----------------------------------------------
# Чтение строки из serial порта.
sub read_serial_str{
    my ($serial_conn)=@_;
    my $got="";
    my ($count, $str)=$serial_conn->read(1);
    while ($count > 0) {
    	($count, $got) = $serial_conn->read(1);
	$str .= $got;
    }
    return $str;
}


