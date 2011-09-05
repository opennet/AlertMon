#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# disk_alert.pl <alert|stat_tps|stat_rs|stat_ws> 
# alert - автоматически выявляет проблемы связанные дисками, например, переполнением
#         разделов, исчерпанием inode, вылетанием диска из raid, фиксация сбоя по SMART 
# 	  По умолчанию показывает поцент занятого места на диске, если сбой выводится +1000%.
# выводятся наихудшее значение для всех дисков в системе.
# TODO: 
#  stat_tps|stat_rs|stat_ws - выводит параметры нагрузки на диск.
#  мониторинг raid

use strict;

# Директория для сохранения промежуточного статус-файла.
my $cfg_proc_df = "df"; 
my $cfg_dev_mask='\/dev\/';
###########################################################################

# Проверяем свободное место.
my $max_percent=0;
my $max_mount="";

open(DF, "$cfg_proc_df|");
while (<DF>){
    chomp;
    my $line=$_;
    if ($line =~ /^$cfg_dev_mask[^\s]+\s+\d+\s+\d+\s+\d+\s+(\d+)\%\s+(.*)$/){
	my $cur_percent = $1;
	my $cur_mount = $2;
	if ($cur_percent > $max_percent){
	    $max_percent = $cur_percent;
	    $max_mount = $cur_mount;
	}
    }
}
close(DF);

open(DF, "$cfg_proc_df -i|");
while (<DF>){
    chomp;
    my $line=$_;
    if ($line =~ /^$cfg_dev_mask[^\s]+\s+\d+\s+\d+\s+\d+\s+(\d+)\%\s+([^\s]+)$/
        || $line =~ /^$cfg_dev_mask[^\s]+\s+\d+\s+\d+\s+\d+\s+\d+\%\s+\d+\s+\d+\s+(\d+)\%\s+([^\s]+)$/){
	my $cur_percent = $1;
	my $cur_mount = $2;
	if ($cur_percent > $max_percent){
	    $max_percent = $cur_percent;
	    $max_mount = $cur_mount;
	}
    }
}
close(DF);
        
if ($max_percent > 95){
    $max_percent = $max_percent * 10;
    print "$max_percent ALERT\n";
} else {
    print "$max_percent\n";
}
exit(0);

