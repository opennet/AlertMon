#!/usr/bin/perl
# См. DoS_prevent.txt
# Это просто файл заглушка

my $cfg_cache_dir="/usr/local/alertmon/cache";

my %cfg_apache_server = (
    "apache1" => {
	log_path => "/usr/local/apache/logs/",
	htaccess_file => "/usr/local/apache/htdocs/.htaccess";
	log_file_mask => "^access_.*";
	    },
);
# Время выборки 10 мин.
# число запросов с одного IP (act:ip-block).
my $cfg_max_one_ip
# всего запросов одного CGI с одинаковыми параметрами (act:cgi-cache).
my $max_one_cgi_param_requiets 
# всего запросов одного CGI (act:cgi-limit).
my $max_one_cgi_requiets 
# всего запросов одного не CGI URL (act:url-rate-limit).
my $max_one_url_requiets 
# всего запросов cgi-скриптов (act:all-rate-limit).
my $max_cgi_requiets 
# всего запросов (act:all-rate-limit).
my $max_all_requests 
# число разных IP за за период (act:all-rate-limit).
my $max_diff_ip 
# процент от max_traffic для одного URL (act:url-rate-limit).
my $max_traffic_url_percent 
# максимальное значение трафика (act:all-rate-limit).
my $max_traffic 
