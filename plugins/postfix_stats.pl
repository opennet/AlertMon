#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# postfix_stats.pl <query_type> <maillog_path> [<min_limit> <max_limit>]
# Анализирует лог постфикса и выводит число записей с момента предыдущего вызова, -1 - ошибка.
#   query_type:
#	connect
#	relay
#	mailbox
#	reject
#	deferred

use strict;

# Директория для сохранения промежуточного статус-файла.
my $cfg_tmp_dir = "/usr/local/alertmon/toplogs"; 

# Промежуток между выборками, без нового парсинга лога.
my $cfg_request_idle = 300; 

my %cfg_query_types=(
    "connect" =>  ' connect from [\d\w\-\.]+\[\d+\.\d+\.\d+\.\d+\]', 
    "relay" =>    'sent \(250',
    "mailbox" =>  'status=sent \(mailbox\)', 
    "reject" =>   '\: reject\:', 
    "deferred" => 'status=deferred'
);


###########################################################################
if (! defined $ARGV[1]){
    die "Usage: postfix_stats.pl <query_type> <maillog_path> [<min_limit> <max_limit>]\n";
}
my $query_type = $ARGV[0];
my $maillog_path = $ARGV[1];
my $min_limit = $ARGV[2] || "none";
my $max_limit = $ARGV[3] || "none";

if (! -f $maillog_path){
    die "File $maillog_path not exists.";
}

if (! defined $cfg_query_types{$query_type}){
    die "Unknown query type '$query_type'.";
}

    my $stats_file = $maillog_path;
    $stats_file =~ s/[^\d\w]//g;
    $stats_file = "$cfg_tmp_dir/" . $stats_file . ".postfix_stats";

    if (-f $stats_file){


	# Читаем значения выборки.
	my ($cur_val, $cur_position) = load_stats($stats_file, $query_type);

	# Если есть необходимость, генерируем итерацию с новой выборкой статистики.
        if ((stat($stats_file))[9] + $cfg_request_idle < time()){
		update_postfix_stats($stats_file, $maillog_path, $cur_position);
		($cur_val, $cur_position) = load_stats($stats_file, $query_type);
	}
	if (($min_limit ne "none" && $cur_val < $min_limit) || ($max_limit ne "none" && $cur_val > $max_limit)){
	    print "$cur_val ALERT\n";
	} else {
	    print "$cur_val\n";
	}

    } else {
	update_postfix_stats($stats_file, $maillog_path, -1);
	# первый запуск
        print "0\n";
    }
exit;

#---------------------------------------------------------------------
# Парсинг postfix лога и апдейт временного файла.
sub update_postfix_stats{
    my ($stats_file, $maillog_path, $last_position) = @_;

    my %sum_stats = ();

    my $log_size = (stat($maillog_path))[7];
    
    if ($last_position < 0){
	# Первый запуск. Пишем позицию в файл.
	store_stats($stats_file, $log_size, \%sum_stats);
	return 0;
    }
    
    if ($log_size < $last_position){
	    # Лог после ротации.
            $last_position = 0;
    }

    open(MAILLOG, "<$maillog_path") || return -1;
    if ($last_position > 0){
        if (seek(MAILLOG, $last_position, 0) != 1){
	    die("ERROR:seek() return error: $!");
	}
    }

    while(<MAILLOG>){
	my $cur_line = $_;
	while (my ($cur_query, $cur_mask) = each(%cfg_query_types)){
	    if ($cur_line =~ /$cur_mask/){
		$sum_stats{$cur_query}++;
		# print "$cur_query\t$cur_line\n";
	    }
	}
    }

    my $new_position = tell(MAILLOG);
    close(MAILLOG);

    store_stats($stats_file, $new_position, \%sum_stats);
    return 0;

}

#---------------------------------------------------------------------
# Чтение данных из временного файла
sub load_stats{
    my ($stats_file, $query_type) = @_;

    my $last_position=0;
    open(STATS, "<$stats_file") || return (-1,0);
    flock(STATS, 1);
    chomp($last_position = <STATS>);
    while(<STATS>){
	chomp();
	if (/^$query_type\s+(\d+)$/){
	    close(STATS);
	    return ($1, $last_position);
	}
    }
    close(STATS);
    return (0, $last_position);
}

#---------------------------------------------------------------------
# Запись дампа данных во временный файл
sub store_stats{
    my ($stats_file, $new_position, $sum_stats) = @_;

    open(STATS, ">$stats_file.new") || return -1;
    flock(STATS, 2);
    print STATS "$new_position\n";
    while( my( $key, $val) = each (%$sum_stats)){
	print STATS "$key $val\n";
    }
    close(STATS);
    rename("$stats_file.new", $stats_file);
    return 0;
}



