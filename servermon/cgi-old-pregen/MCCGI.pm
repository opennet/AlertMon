#!/usr/bin/perl
# Функции для обработки передаваемых CGI скрипту параметров. Copyright (C) 1999 by Maxim Chirkov <mc@tyumen.ru>

package MCCGI;

require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw();
@EXPORT_OK = qw(cgi_load_param cgi_escape cgi_load_cookies cgi_load_cookie_name cgi_unescape);

%EXPORT_TAGS = (all => [@EXPORT_OK]);
$VERSION = '3.0';
use strict;

# Парсинг заголовка
sub cgi_load_param {
  my ($in) = @_ if @_;
  my ($i, $key, $val);

    my $local_flag = 0;
    
    if (defined $ARGV[0] && $ARGV[0] eq "-local"){
	my $local_flag=1;
	$ENV{'REQUEST_METHOD'} = "GET";
	$ENV{'QUERY_STRING'} = $ARGV[1];
	if (defined $ARGV[2] && $ARGV[2] eq "-host"){
	    $ENV{'HTTP_HOST'}=$ARGV[3];
	}
    }

   # Read in text
    my $input_buf;
    if ($ENV{'REQUEST_METHOD'} eq "GET") {
       $input_buf = $ENV{'QUERY_STRING'};
    } elsif ($ENV{'REQUEST_METHOD'} eq "POST") {
       read(STDIN,$input_buf,$ENV{'CONTENT_LENGTH'});
    }
    my @in = split(/[&;]/,$input_buf); 
    foreach $i (0 .. $#in) {
	# Convert plus to spaces
	$in[$i] =~ s/\+/ /g;
	# Split into key and value.  
	($key, $val) = split(/=/,$in[$i],2); # splits on the first =.
	# Convert %XX from hex numbers to alphanumeric
	$key =~ s/%(..)/pack("c",hex($1))/ge;
        $val =~ s/%(..)/pack("c",hex($1))/ge;
	$val =~ s/[\t]//g;

	# Associate key and value
	if (! defined($$in{$key})){
	    $$in{$key} = $val;
	} else {
	    $$in{$key} .= "\t$val";
	}
    }
    return scalar(@in); 
}

sub cgi_escape {
  my $toencode = shift;
  $toencode=~s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
  return $toencode;
}

sub cgi_unescape {
  my $fromencode = shift;
  $fromencode =~ s/%(..)/pack("c",hex($1))/ge;
  return $fromencode;
}

# Парсинг cookies.
sub cgi_load_cookies{
    my ($cook_arr) = @_;
    foreach (split(/\;\s*/,$ENV{'HTTP_COOKIE'})){
	my ($cur_key, $cur_val) = split(/\=/);
	$$cook_arr{"$cur_key"} = $cur_val;
    }
}
sub cgi_load_cookie_name{
    my ($cookie_name) = @_;
    foreach (split(/\;\s*/,$ENV{'HTTP_COOKIE'})){
	my ($cur_key, $cur_val) = split(/\=/);
	if ($cur_key eq $cookie_name){
	    return $cur_val;
	}
    }
    return undef;
}
				    
###################################################################

1; #return true 

