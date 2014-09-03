#!/bin/bash

#
# This script is used to test the response time of nodes
#
# June 1, 2010 by Liang Wang
#

user=`id -un`

#
# Test the speed! TELL ME WHICH NODES ARE OVERLOADED NOW!
#
function test_speed()
{
    i=$2; j=$3
    while [ $i -le $j ]; do
        ni=`printf "%03i" $i`  
        node=`echo $1 | sed "s/???/${ni}/"`
        i=`expr $i + 1`
	    t1=`python -c 'import time; print time.time()'`
        cpu=`ssh -o BatchMode=yes -o StrictHostKeyChecking=no $node "uptime; "`
        cpu=`python -c "print '$cpu'.split('load average: ')[-1]"`
	    t2=`python -c 'import time; print time.time()'`
	    rt=`python -c "print str($t2-$t1)[:4]"`
        echo "$node -> rstm:$rt load:$cpu"
    done
}

#
# Main Function
#
if [ $# -ne 3 ]; then
    echo "Usage: test.sh name_pattern start_index end_index"
    echo "Example: test.sh cln??? 1 10"
    exit 1
fi

test_speed $1 $2 $3

exit 0


