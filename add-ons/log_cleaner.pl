#!/usr/bin/perl -w
# Чистильщик логов.
# Можно использовать: 
#    find ./top_logs -type f -maxdepth 4 -mtime +20 -exec rm -f {} \;
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>

use strict;
use File::Path;

# Сколько дней хранятся подробные логи.
my $cfg_log_timetolive = 15;

# За сколько дней сохраняется активный лог со списком проишествий.
my $cfg_alertlist_timetolive = 30;

# Число ротаций лога со списком проишествий
my $cfg_alertlist_rotations = 3;

# Путь к корню директории с логами.
my $cfg_toplogs_dir="/usr/local/alertmon/toplogs";

###############################################################################


my $cfg_alertlist_file = "$cfg_toplogs_dir/alertlist.log";
$cfg_log_timetolive = $cfg_log_timetolive * 24 * 60 * 60;
my $now_time = time();


# -------------------------------------------------
# Читка старых записей с информацией о проишествиях.

opendir( LOGS, "$cfg_toplogs_dir") || die "Cannot open $cfg_toplogs_dir directory !";

# Обходим директории с годами.    
while (my $dir_item = readdir LOGS){
    if (-d "$cfg_toplogs_dir/$dir_item" && $dir_item =~ /^\d\d\d\d$/){
        my $act_month_cnt = clear_year("$cfg_toplogs_dir/$dir_item");
	if ($act_month_cnt == 0){
	    # Директория пустая удаляем ее.
	    rmtree("$cfg_toplogs_dir/$dir_item");
	}
    }
}
closedir(LOGS);

# -------------------------------------------------
# Чистка активного списочного лога.


exit(0);

#############################################################################
# Чистка директорий с месяцами.
sub clear_year {
    my ($year_dir) = @_;
    my $act_month_cnt = 0; # Число непросроченных дневных директорий.
    opendir( MLOGS, "$year_dir") || die "Cannot open $year_dir directory !";
    while (my $dir_item = readdir MLOGS){
        if (-d "$year_dir/$dir_item" && $dir_item =~ /^\d+$/){
	    my $act_day_cnt = clear_month("$year_dir/$dir_item");
	    if ($act_day_cnt == 0){
		# Директория пустая удаляем ее.
		rmtree("$year_dir/$dir_item");
	    } else {
		$act_month_cnt++;
	    }
	}
    }
    closedir(MLOGS);
    return $act_month_cnt;
}

#############################################################################
# Чистка директорий с днями.
sub clear_month {
    my ($month_dir) = @_;
    my $act_day_cnt = 0; # Число непросроченных дневных директорий.
    opendir( DLOGS, "$month_dir") || die "Cannot open $month_dir directory !";
    while (my $dir_item = readdir DLOGS){
        if (-d "$month_dir/$dir_item" && $dir_item =~ /^\d+$/){

	    my $mtime = (stat("$month_dir/$dir_item"))[9];

	    if ($cfg_log_timetolive + $mtime < $now_time){
		rmtree("$month_dir/$dir_item");
	    } else {
		$act_day_cnt++;
	    }
	}
    }
    closedir(DLOGS);
    return $act_day_cnt;
}

#sub rmtree{
#    my ($test) = @_;
#    print "rm $test\n";
#}

