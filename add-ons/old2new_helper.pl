#!/usr/bin/perl
# Небольшой скрипт для помощи в перевде старого формата конфигурации в новый.
#
# Usage: old2new_helper.pl [путь к alertmon.pl]

# Путь к работающему скрипту alertmon (можно указать как аргумент в командной строке.)
my $cfg_alertmon_path="./alertmon.pl";

# Директория в которую будут помещены файлы конфигурации нового формата.
# Позже их можно включить в основной файл конфигурации через директиву
# <<include externalconfig.rc>>
my $cfg_output_config_dir = ".";

# Далее не редактировать ---------------------------------------

my $cfg_end_of_data_regex = '^use Socket;$';
my $cfg_conf_proc_file = "$cfg_output_config_dir/topmon_proc.conf";
my $cfg_conf_maxproc_file = "$cfg_output_config_dir/topmon_maxproc.conf";
my $cfg_conf_diskspace_file = "$cfg_output_config_dir/topmon_diskspace.conf";
my $cfg_conf_dns_file = "$cfg_output_config_dir/topmon_dns.conf";
my $cfg_conf_ping_file = "$cfg_output_config_dir/topmon_ping.conf";



############################################################################

# Создаем временный файл из старого alertmon.
    open (BINFILE, "<$cfg_alertmon_path")|| die "Can't open alertmon file at $cfg_alertmon_path\n";
    unlink("$cfg_output_config_dir/.alertmon.$$.tmp");
    open (INCFILE, ">$cfg_output_config_dir/.alertmon.$$.tmp")|| die "Can't create tmp file at $cfg_output_config_dir/.alertmon.$$.tmp\n";
    flock(INCFILE, 2);
    while (<BINFILE>){
	if (/$cfg_end_of_data_regex/o){
	    print INCFILE "1;\n";
	    last;
	}
	print INCFILE $_;	
    }
    close (BINFILE);
    close (INCFILE);

# Подгружаем старую конфигурацию 
    require "$cfg_output_config_dir/.alertmon.$$.tmp";

# Преобразуем блоки в новый формат.
    convert_proc($cfg_conf_proc_file, \@conf_proc);
    convert_maxproc($cfg_conf_maxproc_file, \@conf_maxproc);
    convert_diskspace($cfg_conf_diskspace_file, \@conf_diskspace);
    convert_dns($cfg_conf_dns_file, \@conf_dns);
    convert_ping($cfg_conf_ping_file, \@conf_ping);

# Удаляем временный файл.
    unlink("$cfg_output_config_dir/.alertmon.$$.tmp");

exit(0);


############################################################################
# Функции для преобразования.
sub convert_proc{
    my ($cfg_conf_file, $conf_arr) = @_;
    my $i = 0;

    open(NEWCFG, ">$cfg_conf_file") || die "Can't create $cfg_conf_file\n";
    flock(NEWCFG, 2);
    foreach my $cur_conf_item (@$conf_arr){
	my $cur_mask = $$cur_conf_item[0];
	$cur_mask =~ s/\#/\\#/g;
	my $cur_user = "";
	if ($cur_mask =~ /^(.+)\.\*(.+)$/){
	    $cur_mask = $2;
	    $cur_user = $1;
	}
	my $cur_exec = $$cur_conf_item[1];
	$cur_exec =~ s/\#/\\#/g;
	my $cur_desc = $$cur_conf_item[2];
	$cur_desc =~ s/\#/\\#/g;
	my $cur_id = $cur_mask;
	$cur_id =~ s/[^\d\w\_]//g;
	if ($cur_id eq ""){
	    $cur_id = "all$i";
	    $i++;
	}
	
	if ($cur_mask ne ""){
	    print NEWCFG "<proc_mon $cur_id>\n";
	    print NEWCFG "\tmin_limit 1\n";
	    print NEWCFG "\temail_after_probe 1\n";
	    print NEWCFG "\tproc_mask $cur_mask\n";
	    if ($cur_user ne ""){
		print NEWCFG "\tuser_mask $cur_user\n";
	    }
	    if ($cur_exec ne ""){
		print NEWCFG "\taction_cmd $cur_exec\n";
	    }
	    if ($cur_desc ne ""){
		print NEWCFG "\tcomment $cur_desc\n";
	    }
	    print NEWCFG "</proc_mon>\n\n\n";
	} else {
	    print STDERR "Error, Skipping line: $cur_mask,$cur_exec,$cur_desc\n";
	}
    }
    close(NEWCFG);
}

# -----------------------------------------------------------
sub convert_maxproc{
    my ($cfg_conf_file, $conf_arr) = @_;
    my $i = 0;

    open(NEWCFG, ">$cfg_conf_file") || die "Can't create $cfg_conf_file\n";
    flock(NEWCFG, 2);
    foreach my $cur_conf_item (@$conf_arr){
	my $cur_mask = $$cur_conf_item[0];
	$cur_mask =~ s/\#/\\#/g;
	my $cur_user = "";
	if ($cur_mask =~ /^(.*)\.\*(.*)$/){
	    $cur_mask = $2;
	    $cur_user = $1;
	}
	my $cur_limit = $$cur_conf_item[1];
	my $cur_exec = $$cur_conf_item[2];
	$cur_exec =~ s/\#/\\#/g;
	my $cur_desc = $$cur_conf_item[3];
	$cur_desc =~ s/\#/\\#/g;
	my $cur_id = $cur_mask;
	$cur_id =~ s/[^\d\w\_]//g;
	if ($cur_id eq ""){
	    $cur_id = "all$i";
	    $i++;
	}
	
	if ($cur_mask ne ""){
	    print NEWCFG "<proc_mon $cur_id>\n";
	    print NEWCFG "\tmax_limit $cur_limit\n";
	    print NEWCFG "\tgraph_name proc_cnt\n";
	    print NEWCFG "\temail_after_probe 1\n";
	    print NEWCFG "\tproc_mask $cur_mask\n";
	    if ($cur_user ne ""){
		print NEWCFG "\tuser_mask $cur_user\n";
	    }
	    if ($cur_exec ne ""){
		print NEWCFG "\taction_cmd $cur_exec\n";
	    }
	    if ($cur_desc ne ""){
		print NEWCFG "\tcomment $cur_desc\n";
	    }
	    print NEWCFG "</proc_mon>\n\n\n";
	} else {
	    print STDERR "Error, Skipping line: $cur_mask,$cur_exec,$cur_desc\n";
	}
    }
    close(NEWCFG);
}

# -----------------------------------------------------------
sub convert_diskspace{
    my ($cfg_conf_file, $conf_arr) = @_;
    my $i = 0;

    open(NEWCFG, ">$cfg_conf_file") || die "Can't create $cfg_conf_file\n";
    flock(NEWCFG, 2);
    foreach my $cur_conf_item (@$conf_arr){
	my $cur_device = $$cur_conf_item[0];
	my $cur_min_limit = $$cur_conf_item[1];
	my $cur_exec = $$cur_conf_item[2];
	$cur_exec =~ s/\#/\\#/g;
	my $cur_desc = $$cur_conf_item[3];
	$cur_desc =~ s/\#/\\#/g;
	
	if ($cur_device ne ""){
	    print NEWCFG "<disk_mon $cur_device>\n";
	    print NEWCFG "\tmin_size_limit $cur_min_limit\n";
	    print NEWCFG "\tmin_inode_limit 4000\n";
	    print NEWCFG "\tgraph_name disk\n";
	    print NEWCFG "\temail_after_probe 1\n";
	    print NEWCFG "\tdevice $cur_device\n";
	    if ($cur_exec ne ""){
		print NEWCFG "\taction_cmd $cur_exec\n";
	    }
	    if ($cur_desc ne ""){
		print NEWCFG "\tcomment $cur_desc\n";
	    }
	    print NEWCFG "</disk_mon>\n\n\n";
	} else {
	    print STDERR "Error, Skipping line: $cur_mask,$cur_exec,$cur_desc\n";
	}
    }
    close(NEWCFG);
}

# -----------------------------------------------------------
sub convert_dns{
    my ($cfg_conf_file, $conf_arr) = @_;
    my $i = 0;

    open(NEWCFG, ">$cfg_conf_file") || die "Can't create $cfg_conf_file\n";
    flock(NEWCFG, 2);
    foreach my $cur_conf_item (@$conf_arr){
	my $cur_host = $$cur_conf_item[0];
	my $cur_ns = $$cur_conf_item[1];
	my $cur_exec = $$cur_conf_item[2];
	$cur_exec =~ s/\#/\\#/g;
	my $cur_desc = $$cur_conf_item[3];
	$cur_desc =~ s/\#/\\#/g;
	my $cur_id = $cur_ns;
	$cur_id =~ s/[^\d\w\_]/_/g;
	
	if ($cur_ns ne "" && $cur_host ne ""){
	    print NEWCFG "<external_mon dns_$cur_id>\n";
	    print NEWCFG "\tplugin_path /usr/local/alertmon/plugins/dns_resolver.pl\n";
	    print NEWCFG "\tplugin_param $cur_ns $cur_host\n";
	    print NEWCFG "\talert_mask ALERT\n";
	    print NEWCFG "\temail_after_probe 1\n";
	    if ($cur_exec ne ""){
		print NEWCFG "\taction_cmd $cur_exec\n";
	    }
	    if ($cur_desc ne ""){
		print NEWCFG "\tcomment $cur_desc\n";
	    }
	    print NEWCFG "</external_mon>\n\n\n";
	} else {
	    print STDERR "Error, Skipping line: $cur_mask,$cur_exec,$cur_desc\n";
	}
    }
    close(NEWCFG);
}

# -----------------------------------------------------------
sub convert_ping{
    my ($cfg_conf_file, $conf_arr) = @_;
    my $i = 0;

    open(NEWCFG, ">$cfg_conf_file") || die "Can't create $cfg_conf_file\n";
    flock(NEWCFG, 2);
    foreach my $cur_conf_item (@$conf_arr){
	my $cur_host = $$cur_conf_item[0];
	my $cur_proto = $$cur_conf_item[1];
	my $cur_timeout = $$cur_conf_item[2];
	my $cur_size = $$cur_conf_item[3];
	my $cur_tries = $$cur_conf_item[4];
	my $cur_exec = $$cur_conf_item[5];
	$cur_exec =~ s/\#/\\#/g;
	my $cur_desc = $$cur_conf_item[6];
	$cur_desc =~ s/\#/\\#/g;
	my $cur_id = $cur_host;
	$cur_id =~ s/[^\d\w\_]/_/g;
	
	if ($cur_host ne "" && $cur_proto ne ""){
	    print NEWCFG "<external_mon ping_$cur_id>\n";
	    print NEWCFG "\tplugin_path /usr/local/alertmon/plugins/host_alive.pl\n";
	    print NEWCFG "\tplugin_param $cur_host $cur_proto $cur_size $cur_tries\n";
	    print NEWCFG "\talert_mask ALERT\n";
	    print NEWCFG "\temail_after_probe 1\n";
	    if ($cur_exec ne ""){
		print NEWCFG "\taction_cmd $cur_exec\n";
	    }
	    if ($cur_desc ne ""){
		print NEWCFG "\tcomment $cur_desc\n";
	    }
	    print NEWCFG "</external_mon>\n\n\n";
	} else {
	    print STDERR "Error, Skipping line: $cur_mask,$cur_exec,$cur_desc\n";
	}
    }
    close(NEWCFG);
}
