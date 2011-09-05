#!/usr/bin/perl
# alertmon package v.3, http://www.opennet.ru/dev/alertmon/
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>
#
# dns_resolver.pl <ns_server> <tested_host>
#    Проверка работы DNS сервера. На выходе, 1 - OK или 0 - ALERT
#    Например: plugin_param 192.168.4.1 www.altavista.com

###########################################################################
use Net::DNS::Resolver;

use constant TCP_QUERY_TIMEOUT => 10;


if (! defined $ARGV[0] || ! defined $ARGV[1]){
    die "Usage: dns_resolver.pl <ns_server> <tested_host>\n";
}
my $cfg_ns_server = $ARGV[0];
my $cfg_tested_host = $ARGV[1];

if (check_host($cfg_tested_host, $cfg_ns_server) == -1){
    print "ALERT\n";
    exit(1);
} else {
    print "OK\n";
    exit(0);
}

#------------------------------------------
# Loookup in DNS database

sub check_host {
	my($host, $server) = @_;
	my($res, $query, $rr, $live);

  $res = new Net::DNS::Resolver;
  $res->nameservers($server);
  $res->tcp_timeout(TCP_QUERY_TIMEOUT);
  
  $query = $res->search($host);

  if ($query) {
      foreach $rr ($query->answer){
          next unless $rr->type eq "A";
          $live = $rr->address;
      }
  } else {
      $live = -1;
  }
  return $live;
}

