#!/bin/env bash

#
# This script reads sys' configuration from config.txt, then deploy and start experiments
# according to the configurations.
#
# July 1, 2010 by Liang Wang
#

# Global configurations, set according to config.txt file
start=1
end=28
bt_dir='unknown'            # BitTorrent application's diretory
conf_dir='unknown'          # dir to store configuration files of jobs
data_dir='unknown'          # dir to store experiment data
deploy_dir='unknown'        # dir to deploy startup scripts
deploy_data_dir='unknown'   # dir to store the distribution content
scripts_dir=`dirname $0`    # dir of the sys' scripts
sleep_interval=20           # sleep interval in seconds, default value is 20s
reset_interval=20           # if not all the peers start up within this interval, the experiment will restart.
exp_interval=3600           # exp interval in seconds, default value is 3600s, which means a single experiment cannot exceed one hour.
node_list=( "unknown" )     # array containing the nodes used in the experiment
files='unknown'             # files as distribution content
tracker_url='unknown'       # the tracker url
tracker_node='unknown'      # the dns name of the tracker
email='unknown'             # email address to receive the experiment notification
fsize=100                   # if no file is specified, this variable indicates the size of the auto-generated file, in MegeBytes
info='unknown'              # simple information for the experiment
fgen_cmd=''                 # command used to generate file -> dd if=/dev/zero of=/tmp/zzz.iso bs=1M count=XXX
torrent_file='unknown'      # torrent file name (complete path)

#
# read_config reads config.txt in the same folder, and set global configurations.
# $1    config file
#
function read_config() {
    config_file="$1"
    if [ ! -f $config_file ]; then
        echo "Error: no config.txt file found!"
        exit 1
    fi
    echo "[*] Reading the config file ..."
    bt_dir=`sed -n 's/\[bt_dir\]://p' < $config_file`
    bt_dir=`$SHELL -c "echo $bt_dir"`     # needs refactoring
    conf_dir=`sed -n 's/\[conf_dir\]://p' < $config_file`
    conf_dir=`$SHELL -c "echo $conf_dir"`     # needs refactoring
    data_dir=`sed -n 's/\[data_dir\]://p' < $config_file`
    data_dir=`$SHELL -c "echo $data_dir"`     # needs refactoring
    deploy_dir=`sed -n 's/\[deploy_dir\]://p' < $config_file`
    deploy_data_dir=`sed -n 's/\[deploy_data_dir\]://p' < $config_file`
    sleep_interval=`sed -n 's/\[sleep_interval\]://p' < $config_file`
    reset_interval=`sed -n 's/\[reset_interval\]://p' < $config_file`
    exp_interval=`sed -n 's/\[exp_interval\]://p' < $config_file`
    tracker_url=`sed -n 's/\[tracker\]://p' < $config_file`
    tracker_node=`echo $tracker_url | sed 's/http:\/\/\(.*\):\([0-9]*\)/\1/'`
    email=`sed -n 's/\[email\]://p' < $config_file`
    files=`sed -n 's/\[files\]://p' < $config_file`
    fsize=`sed -n 's/\[fsize\]://p' < $config_file`
    info="`sed -n 's/\[info\]://p' < $config_file`"
    fgen_cmd="dd if=/dev/zero of=/tmp/zzz.${fsize}.iso bs=1M count=${fsize}"    # needs refactoring
    torrent_file="${deploy_dir}/zzz.${fsize}.${tracker_node}.iso.torrent"       # needs refactoring

    #echo $tracker_url
}

#
# deploy_job copies the job.py and job.txt to the clusters' file server, it also does
# some other related deployment work.
# $1    file path for the job.py
# $2    file path for the job.txt
#
function deploy_job() {
    echo "[*] Deploying job scritps to the nodes ..."
    cp "$1" "$deploy_dir"
    cat "$2" | sed "1 s/.*/${tracker_node}\t*\t*\t*/" > "$deploy_dir/job.txt"

    if [ "$files" == "" ]; then
        # use auto-generated file
        if [ ! -f $torrent_file ]; then
            echo "[*] Generating iso file -> zzz.${fsize}.iso ..."
            `$fgen_cmd`
            echo "[*] Generating torrent file -> $torrent_file ..."
            python ${bt_dir}/btmaketorrent.py ${tracker_url}/announce /tmp/zzz.${fsize}.iso --target ${torrent_file}
        fi
    else
        if [ ! -f $files ]; then
            echo "Error: $files not exist!"
            exit 1
        elif [ ! -f $torrent_file ]; then
            echo "[*] Generating torrent file -> $torrent_file ..."
            python ${bt_dir}/btmaketorrent.py ${tracker_url}/announce $files --target ${torrent_file}
            echo "[*] torrent file is generated, but you have to deploy them manually ..."
            exit 0
        fi
    fi
    
    echo "[*] Checking distribution file on the nodes ..."
    node_list=( `cat "$deploy_dir/job.txt" | sort | cut -f 1 -s | uniq | tr '\n' ' '` )
    # Ryan: temp banned, for kumpulan day, not collect data after experiments
    #for node in ${node_list[@]}; do
    #    ssh $node   "if [ ! -d ${deploy_data_dir} ]; then
    #                    mkdir -p ${deploy_data_dir}
    #                fi
    #                if [ ! -f ${deploy_data_dir}/zzz.${fsize}.iso ]; then
    #                    dd if=/dev/zero of=${deploy_data_dir}/zzz.${fsize}.iso bs=1M count=${fsize};
    #                fi" &
    #done
    #wait
}

function start_job() {
    echo "[*] Starting the jobs on the nodes ..."
    for node in ${node_list[@]}; do
        ssh $node "python job.py '$deploy_dir/job.txt' '${deploy_dir}/zzz.${fsize}.${tracker_node}.iso.torrent' '${deploy_data_dir}/zzz.${fsize}.iso'" &
    done
}

#
# auto_collect is used to monitor ONE experiment, when the number of downloading peers becomes ZERO,
# it will stop the experiment and collect the data automatically.
# Parameters:   (-1 means no restriction; time is measured in second)
# $1    The tracker's url
# $2    If the startup peers cannot reach $2 number, then return with error. -1 means no limit.
# $3    If the startup peers cannot reach $2 number within $3 interval, then return with error.
# $4    If the experiment cannot finish within $4 time interval, stop by force and collect data.
# $5    String added to the prompt info.
# $6    Subdirectory used to save data under experiment directory, if provided.
#
function auto_collect() {
    exp_data_dir=$data_dir
    if [ "$6" != "" ]; then
        exp_data_dir=$6
    fi
    interval=5
    total_time=0
    num=0
    num_reach=0
    result=0
    rm $conf_dir/index.html*

    while [ true ]; do
        if [ $4 -gt -1 ]; then
            if [ $total_time -ge $4 ]; then
                echo ${node_list[@]} | $scripts_dir/finish.sh -collect $deploy_data_dir $exp_data_dir    # maybe add some info the folder name to indicate the problem
                break
            fi
        fi

        if [ $num -gt $num_reach ]; then
            num_reach=$num
        fi
        if [ $3 -gt -1  -a  $num_reach -lt $2 ]; then
            if [ $total_time -ge $3 ]; then
                result=1
                break
            fi
        fi

	    sleep $interval
	    total_time=`expr $total_time + $interval`
	    wget --quiet $1 -O $conf_dir/index.html
		if [ $? -eq 0 ]; then
	        num=`sed -n 's/<tr>.*<ryan_tag>\([^<]*\)<\/ryan_tag>.*<\/tr>/\1/p' $conf_dir/index.html`
            #if [ $num -lt 30  -a  $num_reach -gt 0 ]; then  # Ryan: temp use, since in large-scale experiment, there are always some processes become zombie.
	        if [ $num -eq 0  -a  $num_reach -gt 0 ]; then
		        # Ryan: temp banned, for kumpulan day, not collect data after experiments
		        # echo ${node_list[@]} | $scripts_dir/finish.sh -collect $deploy_data_dir $exp_data_dir
		        break
	        fi
	        printf "\033[31m $5$num peers downloading ... `date` \033[0m"
	    fi
    done

    rm $conf_dir/index.html*
    return $result
}

#
# batch_job is used for a batch of jobs. The experiment configuration file should be put
# in batch folder in advance.
# $1    path for batch dir
#
function batch_job() {
    exp_data_dir="$data_dir/batch-`date +%Y%m%d%H%M%S`"
    batch_dir=$conf_dir
    if [ "$1" != "" ]; then
        batch_dir="$1"
    fi
    if [ ! -d $batch_dir ]; then
        echo "Error: batch directory doesn't exist!"
        exit 1
    fi

    jid=1
    while [ -f $batch_dir"/job_$jid.txt" ]; do
        deploy_job "$scripts_dir/job.py" "$batch_dir/job_$jid.txt"
        start_job $start $end

        n1=`cat $batch_dir"/job_$jid.txt" | wc -l`; # n1 needs improvement; temp use; last line of job.txt cannot be empty!!!
        n1=`expr $n1 - 1`
        auto_collect $tracker_url $n1 $reset_interval $exp_interval "[job "$jid"]: "  $exp_data_dir
        job_ok=$?

        sleep $sleep_interval
        echo ${node_list[@]} | $scripts_dir/finish.sh -cleardata $deploy_data_dir; sleep $sleep_interval
        echo ${node_list[@]} | $scripts_dir/finish.sh -cleardata $deploy_data_dir; sleep $sleep_interval
        
        if [ $job_ok == 0 ]; then
            log_me $batch_dir/log.log "job_$jid Done."
            jid=`expr $jid + 1`
        else
            log_me $batch_dir/log.log "job_$jid Failed."
        fi
    done
    cp -r $batch_dir $exp_data_dir/job_batch
    echo "All jobs done!"
}

#
# batches is used for batches of jobs. The experiment configuration file should be put
# in batch_1, batch_2, batch_3 ... folders in advance.
#
function batches() {
    batches_dir=$conf_dir
    if [ ! -d $batches_dir ]; then
        echo "Error: batches directory doesn't exist!"
        exit 1
    fi

    bid=1
    while [ -d $batches_dir"/batch_$bid" ]; do
        batch_job "$batches_dir/batch_$bid"
        bid=`expr $bid + 1`
        sleep $sleep_interval
    done
    echo "All batches done!"
}

#
# log_me function is used to log some basic info generated during the process of experiment
# Parameters:
# $1    the name of log file
# $2    information need to be logged
#
function log_me() {
    echo -e "[`date +'%Y-%m-%d %H:%M:%S'`]\t$2" >> $1
    cat $1 | mail -s "Report: $2 ($info)" $email
}


#
# Main Function
#
if [ "$1" == "" ]; then
    tcf="$scripts_dir/config.txt"
else
    tcf="$1"
    if [ ! -f "$tcf" ]; then
        echo "Error: the $tcf doesn't exist!"
        exit 1
    fi
fi
read_config $tcf

if [ "$1" == -test ]; then
    echo "Hello world!"
    auto_collect abc 2
    echo $?
else
    if [ -f $conf_dir/job.txt ]; then
        deploy_job "$scripts_dir/job.py" "$conf_dir/job.txt"
        start_job $start $end
    elif [ -f $conf_dir/job_1.txt ]; then
        batch_job
    elif [ -d $conf_dir/batch_1 ]; then
        batches
    else
        echo "[*] Error: cannot find any jobs!"
    fi
fi


exit 0