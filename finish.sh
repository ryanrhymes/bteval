#!/bin/env bash

#
# This script is used to stop the tracker, and all the peers.
# Gathering all the experiment data, and copy them to specific folder.
# Delete everything generated in the experiment on the test node.
#
# Remark: this script denpends on the topology of the file system severely,
#         so, DO modify this script when migrate to another test environment.
#
# May 29, 2010 by Liang Wang

user=`id -un`
node_list=( "unknown" )

#
# Stop all the peers, flush the log into the logfile, prepare for collecting 
# the data. Remark: this function won't do the cleaning job.
#
function stop_experiment()
{
    for node in ${node_list[@]}; do
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no $node "pkill -INT -u $user -f ^python.+BitTorrent && exit;" &
    done
    wait

    pkill -INT -u $user -f ^ssh.+python
}

#
# collect_data function is used to collect experiment data from all nodes in parallel
# Parameters:
# $1    src  dir: where the exp data are generated
# $2    dest dir: where to save exp data under experiment directory
#
function collect_data()
{
    stop_experiment
    sleep 3
    folder="$2/data-`date +%Y%m%d%H%M%S`"
    if [ ! -d $folder ]; then
        mkdir -p $folder
    fi

    for node in ${node_list[@]}; do
    	scp -r ${node}:$1/peer* $folder &
    done
    wait
}


#
# Stop trancker and all the peers, delete download(ed/ing) files
# Send SIGINT (Ctrl+C) to all the relevant processes.
# $1    deploy_data_dir: the directory needs to be cleaned
#
function clear_data()
{
    for node in ${node_list[@]}; do
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no $node "pkill -KILL -u $user python; cd $1 && rm -rf zzz.*.iso.* .bittorrent* peer-* dstat || mkdir -p $1; uname -n;" &
    done
    wait
}

#
# clean all the nodes in the cluster
# $1    deploy_data_dir: the directory needs to be cleaned
# $2    pattern of the node name, such as cln???.hpc.hiit.fi
# $3    start index
# $4    end index
#
function clear_all()
{
    i=$3; j=$4
    while [ $i -le $j ]; do
        ni=`printf "%03i" $i`
        node=`echo $2 | sed "s/???/${ni}/"`
        i=`expr $i + 1`
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no $node "pkill -KILL -u $user python; if [ -d $1 ]; then cd $1; rm -rf *; else mkdir -p $1; fi; uname -n; exit;" &
    done
    wait
}
# Almost the same as clear_all, but doesn't delete zzz.fsize.iso
function clear_some()
{
    i=$3; j=$4
    while [ $i -le $j ]; do
        ni=`printf "%03i" $i`
        node=`echo $2 | sed "s/???/${ni}/"`
        i=`expr $i + 1`
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no $node "pkill -KILL -u $user python; if [ -d $1 ]; then cd $1; rm -rf zzz.*.iso.* .bittorrent* peer-* dstat; else mkdir -p $1; fi; uname -n; exit;" &
    done
    wait
}

#
# Main Function
#
if [ "$1" == -collect ]; then
    node_list=( `cat -` )
    collect_data $2 $3
elif [ "$1" == -clearall ]; then
    clear_all $2 $3 $4 $5
elif [ "$1" == -clearsome ]; then
    clear_some $2 $3 $4 $5
elif [ "$1" == -cleardata ]; then
    node_list=( `cat -` )
    clear_data $2
fi

exit 0