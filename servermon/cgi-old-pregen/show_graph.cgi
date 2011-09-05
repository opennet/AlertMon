#!/usr/bin/perl -I ./
# - Сводные гроафики по каждому хосту.
# - График по хосту
# - График по группам.
# - График по группам разных хостов.
# Copyright (c) 1998-2002 by Maxim Chirkov. <mc@tyumen.ru>

my $cfg_graph_path = "./graph";
my $cfg_href_graph_path = "graph";

my $cfg_template_path = "./templates/show_graph.html";
my $cfg_show_graph_timeout = 24*60*60; # Если график не обновлялся более суток, не показываем его.
my $cfg_rm_graph_timeout = 3*24*60*60; # Если график не обновлялся более 3 суток, удаляем его.

################################################################
use strict;
use MCTemplate qw(print_template load_template);
use MCCGI qw(cgi_load_param);

my %input=();
my %handlers = (
	"sum"		=>	\&h_view_sum,
	"host"		=>	\&h_view_host_mon,
	"host_mon"		=>	\&h_view_host_mon,
	"host_group"		=>	\&h_view_host_group,
	"group"		=>	\&h_view_group,
	"group_mixhost"	=>	\&h_view_group_mixhost,
    );

    print "Content-type: text/html\n\n";
    cgi_load_param(\%input);
    my %item_tpl = load_template("$cfg_template_path", 0);
    print print_template("header", \%item_tpl);

    my $in_host = $input{"host"};
    my $in_group = $input{"group"};

    $item_tpl{"tpl_HOST"} = $in_host;
    $item_tpl{"tpl_GROUP"} = $in_group;

    my $act_flag = 0;
    foreach my $cur_act (keys (%handlers)){
        if (defined $input{"act_$cur_act"}){
		$handlers{$cur_act}->();
		$act_flag = 1;
	}
    }
    if ($act_flag == 0){
        h_view_sum();
    }

    print print_template("footer", \%item_tpl);    
    exit(0);
# ----------------- END

###############################################################################
sub h_view_sum{
    print print_template("sum_header", \%item_tpl);    
    my @graph_items = ();
    load_graph_items("$cfg_graph_path/sum", \@graph_items);

    $item_tpl{"tpl_ACT_LINK"} = "act_host";
    $item_tpl{"tpl_CUR_GROUP"} = "";
    foreach my $cur_item (@graph_items){
	$item_tpl{"tpl_IMG_URL"} = "$cfg_href_graph_path/sum/$cur_item.png";
	$item_tpl{"tpl_CUR_HOST"} = $cur_item;
	print print_template("image_block", \%item_tpl);    
    }
    print print_template("sum_footer", \%item_tpl);    
}
###############################################################################
sub h_view_host_mon{
    print print_template("host_header", \%item_tpl);    
    my @graph_items = ();
    load_graph_items("$cfg_graph_path/host", \@graph_items);

    $item_tpl{"tpl_ACT_LINK"} = "act_group";
    $item_tpl{"tpl_CUR_HOST"} = $in_host;
    foreach my $cur_item (@graph_items){
	if ($cur_item =~ /^$in_host\.(.*)$/){
	    my $cur_group = $1;
	    $item_tpl{"tpl_IMG_URL"} = "$cfg_href_graph_path/host/$cur_item.png";
	    $item_tpl{"tpl_CUR_GROUP"} = $cur_group;
	    print print_template("image_block", \%item_tpl);    
	}
    }
    print print_template("host_footer", \%item_tpl);    
}
###############################################################################
sub h_view_host_group{
    print print_template("host_header", \%item_tpl);    
    my @graph_items = ();
    load_graph_items("$cfg_graph_path/host_group", \@graph_items);

    $item_tpl{"tpl_ACT_LINK"} = "act_group";
    $item_tpl{"tpl_CUR_HOST"} = $in_host;
    foreach my $cur_item (@graph_items){
	if ($cur_item =~ /^$in_host\.(.*)$/){
	    my $cur_group = $1;
	    $item_tpl{"tpl_IMG_URL"} = "$cfg_href_graph_path/host_group/$cur_item.png";
	    $item_tpl{"tpl_CUR_GROUP"} = $cur_group;
	    print print_template("image_block", \%item_tpl);    
	}
    }
    print print_template("host_footer", \%item_tpl);    
}
###############################################################################
sub h_view_group{
    print print_template("group_header", \%item_tpl);    
    my @graph_items = ();
    load_graph_items("$cfg_graph_path/group", \@graph_items);

    $item_tpl{"tpl_ACT_LINK"} = "act_sum";
    $item_tpl{"tpl_CUR_HOST"} = "";
    foreach my $cur_item (@graph_items){
        $item_tpl{"tpl_IMG_URL"} = "$cfg_href_graph_path/group/$cur_item.png";
        $item_tpl{"tpl_CUR_GROUP"} = $cur_item;
        print print_template("image_block", \%item_tpl);    
    }
    print print_template("group_footer", \%item_tpl);    
}
###############################################################################
sub h_view_group_mixhost{
    print print_template("group_mixhost_header", \%item_tpl);    
    my @graph_items = ();
    load_graph_items("$cfg_graph_path/host", \@graph_items);

    $item_tpl{"tpl_ACT_LINK"} = "act_host";
    $item_tpl{"tpl_CUR_GROUP"} = $in_group;
    foreach my $cur_item (@graph_items){
	if ($cur_item =~ /^([^\.]+)\.$in_group$/){
	    my $cur_host = $1;
	    $item_tpl{"tpl_IMG_URL"} = "$cfg_href_graph_path/host/$cur_item.png";
	    $item_tpl{"tpl_CUR_HOST"} = $cur_host;
	    print print_template("image_block", \%item_tpl);    
	}
    }
    print print_template("group_mixhost_footer", \%item_tpl);    
}
##############################################################################
# Получение списка хостов.
sub load_graph_items{
    my ($base_dir, $data_arr) = @_;

    opendir(DIR, "$base_dir")|| return -1;
    while (my $cur_file = readdir(DIR)){ 
	if (-f "$base_dir/$cur_file" &&  $cur_file =~ /^([\d\w\_\-\.]+)\.png$/){
	    my $mod_time = (stat("$base_dir/$cur_file"))[9];
	    my $now_time = time();
	    if ($now_time - $mod_time < $cfg_show_graph_timeout){
		# График актуален.
		my $cur_item = $1;
		push @$data_arr, $cur_item;
	    }
	    if ($now_time - $mod_time > $cfg_rm_graph_timeout){
		# График можно удалить
		unlink("$base_dir/$cur_file");
	    }
	}
    }    
    close(DIR);
    return 0;
}
