#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# file_size.pl file_path
# Вывод размера файла.
#<external_mon awl_size>
#	plugin_path /usr/local/alertmon/plugins/file_size.pl
#	plugin_param /usr/local/amavis/db/auto_whitelist 
#	alert_mask ALERT
#        max_limit 10000
#	email_after_probe 1
#	comment Auto whitelist file size
#</external_mon>

###########################################################################

if (! defined $ARGV[0]){
    die "Usage: file_size.pl <file path>\n";
}

my $cfg_file = $ARGV[0];
if (! -f $cfg_file){
    print "ALERT\n";
    exit(1);
} else {
    $file_size = (stat($cfg_file))[7];
    print "$file_size\n";
    exit(0);
}

