#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2004 by Maxim Chirkov. <mc@tyumen.ru>
#
# amavis_stats.pl <query_type> <maillog_path> [<min_limit> <max_limit>]
# Анализирует лог записи amavisd-new фильтра и выводит число записей заданного
# типа с момента предыдущего вызова, -1 - ошибка.
# Тестировалось при "$log_level = 2;" в amavised.conf
#   query_type:
#	spam 
#	nospam (пропущено клиенту (CLEAN) не включая спам, но считая BAD-HEADER)
#       infected (INFECTED + BANNED)
#	passed
#	bloked


use strict;

# Директория для сохранения промежуточного статус-файла.
my $cfg_tmp_dir = "/usr/local/alertmon/toplogs"; 

# Промежуток между выборками, без нового парсинга лога.
my $cfg_request_idle = 250; 

my %cfg_query_types=(
    "spam"     => ['SPAM'],
    "nospam"   => ['CLEAN','BAD-HEADER'],
    "infected" => ['INFECTED','BANNED'],
    "passed"   => ['Passed'],
    "blocked"   => ['Blocked'],
);

###########################################################################
if (! defined $ARGV[1]){
    die "Usage: amavis_stats.pl <query_type> <amavislog_path> [<min_limit> <max_limit>]\n";
}
my $query_type = $ARGV[0];
my $amavislog_path = $ARGV[1];
my $min_limit = $ARGV[2] || "none";
my $max_limit = $ARGV[3] || "none";

if (! -f $amavislog_path){
    die "File $amavislog_path not exists.";
}

if (! defined $cfg_query_types{$query_type}){
    die "Unknown query type '$query_type'.";
}

    my $stats_file = $amavislog_path;
    $stats_file =~ s/[^\d\w]//g;
    $stats_file = "$cfg_tmp_dir/" . $stats_file . ".amavis_stats";

    if (-f $stats_file){

	# Читаем значения выборки.
	my ($cur_val, $cur_position) = load_stats($stats_file, $query_type);

	# Если есть необходимость, генерируем итерацию с новой выборкой статистики.
        if ((stat($stats_file))[9] + $cfg_request_idle < time()){
		update_amavis_stats($stats_file, $amavislog_path, $cur_position);
		($cur_val, $cur_position) = load_stats($stats_file, $query_type);
	}
	if (($min_limit ne "none" && $cur_val < $min_limit) || ($max_limit ne "none" && $cur_val > $max_limit)){
	    print "$cur_val ALERT\n";
	} else {
	    print "$cur_val\n";
	}

    } else {
	update_amavis_stats($stats_file, $amavislog_path, -1);
	# первый запуск
        print "0\n";
    }
exit;

#---------------------------------------------------------------------
# Парсинг amavis лога и апдейт временного файла.
sub update_amavis_stats{
    my ($stats_file, $amavislog_path, $last_position) = @_;

    my %sum_stats = ();

    my $log_size = (stat($amavislog_path))[7];
    
    if ($last_position < 0){
	# Первый запуск. Пишем позицию в файл.
	store_stats($stats_file, $log_size, \%sum_stats);
	return 0;
    }
    
    if ($log_size < $last_position){
	    # Лог после ротации.
            $last_position = 0;
    }

    open(AMAVISLOG, "<$amavislog_path") || return -1;
    if ($last_position > 0){
        if (seek(AMAVISLOG, $last_position, 0) != 1){
	    die("ERROR:seek() return error: $!");
	}
    }
    my $iter_flag=0;
    while(<AMAVISLOG>){
	my $cur_line = $_;

	if ($cur_line =~ /^.*amavis\[\d+\]\: \([\d\-]+\) (Passed|Blocked) ([A-Z\d\-]+)[, ].*$/){
	    if ($iter_flag != 0){
		# Дублирующаяся запись для одной проверки.
		next;
	    }
	    $iter_flag = 1;
	    my $cur_status = $1; # Passed|Blocked
	    my $cur_type = $2; # CLEAN|BAD-HEADER|SPAM|INFECTED|BANNED
	    while (my ($cur_query, $cur_mask_ar) = each(%cfg_query_types)){
		foreach my $cur_mask (@$cur_mask_ar){
	    	    if ($cur_type eq $cur_mask || $cur_status eq $cur_mask){
			$sum_stats{$cur_query}++;
	    		# print "$cur_query\t$cur_line\n";
		    }
		}
	    }
	} else {
	    $iter_flag = 0;
	}
    }

    my $new_position = tell(AMAVISLOG);
    close(AMAVISLOG);

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



