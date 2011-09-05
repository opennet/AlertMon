#!/usr/bin/perl
# Почтовый фильтр, при приеме письма от altertmon начинает пищать привлекая внимание.
#
# В /etc/aliases:
#  beeper: "|/usr/local/alertmon/add-ons/beeper.pl"
# или в .forward:
#  |/usr/local/alertmon/add-ons/beeper.pl
#
# Внимание ! Для работы должны быть выставлены права доступа 
# для записи в /dev/dsp0 от пользователя nobody.

use strict;

my $cfg_iteration=30;
my $cfg_prog_play="/usr/bin/play";
my $cfg_alert_wav="/usr/local/netsaint/share/media/hostdown.wav";
my $replay_mail="";
my $subject="";

while (<STDIN>){
    my $line = $_;
    if ($replay_mail eq "" && $line =~ /^Reply\-To\: (.*)$/){
	$replay_mail = $1;
    }
    if ($replay_mail eq "" && $line =~ /^From\: (.*)$/i){
	$replay_mail = $1;
    }
    if ($line =~ /^Subject\: (.*)$/i){
	$subject = $1;
    }
}

if ($replay_mail =~ /EMERGENCY/i && $subject=~ /EMERGENCY/i ){
    # Издаем сигнал.
    for(;$cfg_iteration > 0; $cfg_iteration--){
        open(SPK, ">>/dev/console");
	print SPK '\033[10;150]\033[11;600]\007' . "\n";
    	close(SPK);
	if (-f $cfg_alert_wav){
	    system($cfg_prog_play, "-v", "100", $cfg_alert_wav);
	} else {
	    sleep(1);
	}
    }
}