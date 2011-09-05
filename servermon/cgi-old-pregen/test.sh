#!/bin/sh

# host
# mon_block 
# group
# name 

# g_days=N - сколько дней выводить на графике.
# g_skip_days=N - сколько дней пропустить, т.е. 1 - начиная со вчера, 7 - с прошлой недели.
# g_width=N
# g_height=N
# g_bold=N
# g_store_on_disk=file_path


#./create_one.cgi --host zhadum --host vsluh --group web_proc --g_days 1  --g_skip_days=20

./create_one.cgi --id=opennet.la_mon.la5:100 --id=opennet.netstat_mon.all_conn --id=opennet.proc_mon.max_all  --id=opennet.proc_rss_mon.all_rss:0.001 --id=opennet.proc_mon.max_postgres --id=opennet.proc_mon.max.ftp --g_days=1  --g_skip_days=20
