#!/usr/bin/perl

# v 3.0 Template manipulation library. Copyright (C) 1999-2003 by Maxim Chirkov <mc@tyumen.ru>
#
# %template_array = load_template($template_path [, allow_empty_template_lines_flag]);
# $output = print_template($block_name, \%template_array);
#
# Includes "%%name%%" interpreted as "$template_array{tpl_name}".
# Includes "%%name[N]%%" interpreted as "$template_array{tpl_name}[N]".
# Includes "%%name[VAR]%%" interpreted as "$template_array{tpl_name}[tpl_VAR]".
# Includes "%%#PROC_name%%" interpreted as function "$template_array{&name($iter_num)}".
# <!--include:filename-->
# %%INCLUDE:file%%
# %%INCLUDE:cgi_script%% - путь к скрипту отосительно cgi-bin.
# %%#VAR_variable%%
# %%#LOOP_ARRAY_BEGIN:array%% 
# %%#LOOP_PROC_BEGIN:max_counter:procedure%% - procedure($iter_num) run for each iteration
# 					      if "procedure" begin from ":" (%%#LOOP_PROC_BEGIN:max_counter::procedure%%) - not run procedure.
# %%#LOOP_NUM_BEGIN:max_counter%% - procedure($iter_num) run for each iteration
# %%name[]%% - current array cell in loop
# %%LOOP_CNT%% - current iteration number
# %%#LOOP_END:procedure%% or %%LOOP_END:array%%
#
# %%#IF:VAR1=CONST?CONST_IF_EQ:CONST_IF_NE:FI%%  - compare 
# %%#IF:VAR1>CONST?CONST_IF_EQ:CONST_IF_NE:FI%% 
# %%#IF:VAR1<CONST?CONST_IF_EQ:CONST_IF_NE:FI%% 
# %%#IF:VAR1!CONST?CONST_IF_EQ:CONST_IF_NE:FI%%	
# Если CONST отстутствует берется номер текущей итерации цикла,
# Пустые поля определяются как ''
#
# TODO: Неработают вложенные циклы.
######################################################################

package MCTemplate;

require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw();
@EXPORT_OK = qw(load_template print_template);

%EXPORT_TAGS = (all => [@EXPORT_OK]);
$VERSION = '3.0';
use strict;

my %stored_loop_array = ();
my %stored_loop_proc = ();

##############################################################################
# Load template to hash.
sub load_template {
    my ($file_name, $allow_empty_template_lines) = @_;  
    my ($name, $loop_flag, $tpl_name);

	my %template=();
	my @include_files=();
	$file_name =~ /^(.+)\/[^\/]+$/;
	$template{"-templates_root_dir-"}=$1;
	$template{"-allow_empty_template_lines-"} = $allow_empty_template_lines || 0;

	$loop_flag = 0;
	$tpl_name = $file_name;
NEXT_FILE:
	$name='';
	open(TEMPLATE,"<$tpl_name") || die "Can't open template $tpl_name";
	flock(TEMPLATE,1);
	while (<TEMPLATE>){
	    if (/\<\!\-\-include\:([\w\d_\.\/]+)\-\-\>/){
		if ($loop_flag == 0){	
		    push @include_files, $1;
		}
	    }

	    if (/\<\!\-\-\/([\w\d_]*)\-\-\>/){
		if ($name eq $1){
		    $name='';
		}
	    }
	    if (defined $name && $name ne ""){
		$template{$name} = $template{$name} . $_;
	    }
	    if (/\<\!\-\-([\w\d_]*)\-\-\>/){
		$name="$1";
	    }
	}
	close(TEMPLATE);
	$loop_flag=1;
	if ( defined($tpl_name = pop(@include_files))){
		$tpl_name = "$template{'-templates_root_dir-'}/$tpl_name";
		goto NEXT_FILE;
        }
	return %template;
}
######################################################################

sub print_template {

    my ($block_name, $template_array, $first_flag) = @_;  
    my ($output, $includes, $tmp_output, $before_line, $after_line, $var_name);
    my ($loop_array, $loop_flag, $loop_proc, $loop_name, $loop_iteration);

    if (!defined $first_flag || $first_flag == 0){
	%stored_loop_array = ();
	%stored_loop_proc = ();
    }

    $loop_iteration = 0;
    $tmp_output ="";
    $loop_iteration = 0;
    $output = "";
    $includes="";
    $loop_flag = 0;
    $loop_proc = "";

	foreach ( split(/\n/, $$template_array{$block_name})) {
NEXT_INC:
	    my $cur_line=$_;

	    # Встретился конец цикла.
	    if ($cur_line =~ /\%\%#LOOP_END\:([^%]+)\%\%/){
		    $loop_name = $1; 
		    $loop_array = $stored_loop_array{$loop_name};
		    $loop_proc = $stored_loop_proc{$loop_name};
		    $loop_flag = 0;
		    for ($loop_iteration = 0; $loop_iteration < $loop_array; $loop_iteration++){
			if ($loop_proc ne "" && $loop_proc !~ /^\:/){
			    &$loop_proc ($loop_iteration);
			}
			$$template_array{"tpl_LOOP_CNT"} = $loop_iteration + 1;
		        $tmp_output .= print_template ("\@current_array_$loop_name\@", $template_array, 1);
		    }
		    $loop_iteration=0;
		    next;
	    } else {
		if ( $loop_flag == 1){
		    $$template_array{"\@current_array_$loop_name\@"} .= "$cur_line\n";
		    next;
		}
	    }
		if ($cur_line =~ /^(.*?)\%\%([^\%]+)\%\%(.*)$/){
		    $before_line = $1;
		    $after_line = $3;
		    $var_name = $2;
		    if ($var_name =~ /^INCLUDE\:([\w\d_\.\/]+)$/){
			$includes = "";
			my $include_text_file=$1;
			if (-x "./$include_text_file"){
			    open(INC_FILE, "./$include_text_file|");
			    <INC_FILE>;
			} else {
			    open(INC_FILE, "<$$template_array{'-templates_root_dir-'}/$include_text_file");
			}
			while(<INC_FILE>){
			    if (/\<\!\-\-\#include\ file\=\"([^\"]+)\"\-\-\>/){
				open(INC_SUBFILE,"<$$template_array{'-templates_root_dir-'}/$1");
				while(<INC_SUBFILE>){
				    $includes .= $_;			
				}
				close(INC_SUBFILE);
			    } else {
				$includes .= $_;			
			    }
			}
			close(INC_FILE);
		    } elsif ($var_name =~ /^#IF\:([\w\d_]+)([\=\!\<\>])([^?]*)\?([^:]*)\:([^:]*)\:FI$/){
				    
			my $if_var = $$template_array{"tpl_$1"};
			my $if_oper=$2;
			my $if_const=$3 || $$template_array{"tpl_LOOP_CNT"};
			my $if_restrue=$4;
			my $if_resfalse=$5;
			if ($if_const eq "''"){
			    $if_const = "";
			}
			if ($if_oper eq '='){
			    if (($if_var == $if_const && $if_const =~ /^\d+$/) || 
			        ($if_var eq $if_const && $if_const !~ /^\d+$/)){
				$includes = "$if_restrue";
			    } else {
				$includes = "$if_resfalse";
			    }
			} elsif ($if_oper eq '<'){
			    if ($if_var < $if_const){
				$includes = "$if_restrue";
			    } else {
				$includes = "$if_resfalse";
			    }
			} elsif ($if_oper eq '>'){
			    if ($if_var > $if_const){
				$includes = "$if_restrue";
			    } else {
				$includes = "$if_resfalse";
			    }
			} elsif ($if_oper eq '!'){
			    if (($if_var != $if_const && $if_const =~ /^\d+$/) || 
			        ($if_var ne $if_const && $if_const !~ /^\d+$/)){
				$includes = "$if_restrue";
			    } else {
				$includes = "$if_resfalse";
			    }
			} else {
			    $includes="ERROR:UNDEFINED OPERATOR '$if_oper'";
			}
    
		    } elsif ($var_name =~ /^#PROC\_([\w\d_]+)$/){

			&{$$template_array{"tpl_$1"}}($$template_array{"tpl_LOOP_CNT"}-1, $template_array);

		    } elsif ($var_name =~ /^([\w\d_]+)\[(\d+)\]$/){
			$includes = $$template_array{"tpl_$1"}[$2];

		    } elsif ($var_name =~ /^([\w\d_]+)\[([\d\w\_]+)\]$/){
			my $tmp = $$template_array{"tpl_$1"};
			$includes = $$template_array{"tpl_$1"}[$tmp];

		    } elsif ($var_name =~ /^([\w\d_]+)\[\]$/){

			$includes = $$template_array{"tpl_$1"}[$$template_array{tpl_LOOP_CNT}-1];
		    } elsif ($var_name =~ /^#LOOP_ARRAY_BEGIN:([\w\d_]+)$/){

			$loop_flag = 1;
			$loop_name = $1;
			$$template_array{"\@current_array_$loop_name\@"}="";
			$loop_array = scalar @{$$template_array{"tpl_$1"}};
			$loop_proc = "";
			$stored_loop_array{$loop_name} = $loop_array;
		        $stored_loop_proc{$loop_name} = $loop_proc ;
			next;
		    } elsif ($var_name =~ /^#LOOP_PROC_BEGIN:([\d]+)\:(\:[\w\d_]+)$/){

			$loop_flag = 1;
			$loop_array = $1;
			$loop_proc = $2;
			$loop_name = $2;
			$loop_name =~ s/\://g;
			$stored_loop_array{$loop_name} = $loop_array;
		        $stored_loop_proc{$loop_name} = $loop_proc ;
			$$template_array{"\@current_array_$loop_name\@"}="";
			next;
		    } else {
			$includes = $$template_array{"tpl_$var_name"};
		    }
		    if ( ($includes ne "")||($$template_array{"-allow_empty_template_lines-"} == 0)){
			$_ = $after_line;
			$tmp_output .= $before_line . $includes;
			goto NEXT_INC;
            	    } else { # ignore lines with empty includes.
                	$tmp_output="";
                	$_="";
            	    }	
		} else {
		    $output = $output . $tmp_output . $_ . "\n";
	    	    $tmp_output = "";	
		}
	}
	return $output;
}

######################################################################
1; #return true

