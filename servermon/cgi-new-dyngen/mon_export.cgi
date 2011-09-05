#!/usr/bin/perl -w
##############################################################################
my $cfg_log_dir = "/usr/local/alertmon/toplogs";
print "Content-type: text/plain\n\n";
# Счетчики для рисования графиков.
open (TOP, "<$cfg_log_dir/snmp.status") || print STDERR "Can't open top file: $cfg_log_dir/snmp.status\n";
flock(TOP, 2);
while (<TOP>){
    print $_;
}
close(TOP);
