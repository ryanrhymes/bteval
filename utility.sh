#!/bin/bash

#
# This script is used to provide some utility functions for others.
# Serving like a functions library somewhat
#
# August 6, 2010 by Liang Wang


# takes you the node you want
# $1 - node pattern
# $2 - node index
function to_node()
{
    node=`echo $1 | sed "s/???/$2/"`
    ssh $node
}


# scan available nodes in the cluster
# $1 - node pattern
# $2 - start index
# $3 - stop index
function scan_available_nodes()
{
    fn="available_nodes_cache.txt"
    scan_available_nodes_helper $1 $2 $3 > $fn
    sleep 5
    pkill -KILL -u `id -un` -f hostname

    node_prefix=`echo $1 | sed "s/???//"`
    cat $fn | grep -o -E ^${node_prefix}[0-9]+ | sort | sed "1 i `date`" > $fn
}
function scan_available_nodes_helper()
{
    i=$2; j=$3
    while [ $i -le $j ]; do
	p=`printf "%03i" $i`
	node=`echo $1 | sed "s/???/$p/"`
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no -q -q $node "hostname; exit;" &
	i=`expr $i + 1`
    done
}


#
# Main Function
#
case $1 in
    "-tonode")
    to_node $2 $3
    ;;
    "-available")
    scan_available_nodes $2 $3 $4
    ;;
    "")
    echo -e "$0 is a script function library. \n -tonode"
    ;;
esac

exit 0