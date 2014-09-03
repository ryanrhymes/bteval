#!/bin/bash

#
# The script has the similar function as cron. It will run forever,
# and perform various pre-defined functions.
#

counter=0
scripts_dir=`dirname $0`
config_file="$scripts_dir/config.txt"
node_pattern=`sed -n 's/\[node_pattern\]://p' < $config_file`

# main loop here
function run_forever()
{
    while true; do
        printf "[*] %s\n" "`date`"
        
        perform_tasks $counter
        
        sleep 60
        counter=`expr $counter + 1`
    done
}


# carry out various tasks here
# $1 - miniutes elapsed
function perform_tasks()
{
    if [ `expr $1 % 10` -eq 0 ]; then
        task_scan_available_nodes
    fi
}


# Following functions implement various tasks
function task_scan_available_nodes()
{
    printf "[\033[31m+\033[0m] \033[31mscan available nodes ...\033[0m "
    exec 5<&1; exec 6<&2; exec 1>/dev/null; exec 2>/dev/null
    $scripts_dir/utility.sh -available $node_pattern 1 240
    exec 1<&5; exec 2<&6
    i=`wc -l < $scripts_dir/available_nodes_cache.txt`
    i=`expr $i - 1`
    printf "[ $i found ]\n"
}


#
# Main function
#
printf "[*] \033[31mmyCron starts working now ...\033[0m \n"
printf "[*] Press Ctrl-C to stop the myCron\n"
run_forever