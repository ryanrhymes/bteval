#!/bin/bash

#
# This script is used for probing the current network rate of a specific machine.
# Or you can use it to probe the rate of loopback, with the switch -lo
#
# Example: rate.sh cln001; rate.sh cln001 -c 10; rate.sh -lo; rate -eth0; rate.sh -eth0 -c 8; rate.sh -all cln??? 1 28
#
# 2010 by Liang Wang
#

function get_rate() {
    info=`ssh $1 "ifconfig eth0; sleep 1; ifconfig eth0" | sed -n 's/\s*\(RX bytes:\)/\1/p';`
    rx1=`echo $info | sed -n 's/RX bytes:\([0-9]*\).*/\1/p'`
    tx1=`echo $info | sed -n 's/RX.*TX bytes:\([0-9]*\).*RX.*/\1/p'`
    rx2=`echo $info | sed -n 's/RX.*TX.*RX bytes:\([0-9]*\).*/\1/p'`
    tx2=`echo $info | sed -n 's/RX.*TX.*RX.*TX bytes:\([0-9]*\).*/\1/p'`

    rx=`echo "scale=2; ($rx2-$rx1)/1024" | bc`
    tx=`echo "scale=2; ($tx2-$tx1)/1024" | bc`
    rate="[R:$rx KB/s]\t[S:$tx KB/s]"
    echo $rate
}

function get_rate_local() {
    info=`ifconfig $1; sleep 1; ifconfig $1 | sed -n 's/\s*\(RX bytes:\)/\1/p';`
    rx1=`echo $info | sed -n 's/.*RX bytes:\([0-9]*\).*TX.*RX.*/\1/p'`
    tx1=`echo $info | sed -n 's/.*RX.*TX bytes:\([0-9]*\).*RX.*/\1/p'`
    rx2=`echo $info | sed -n 's/.*RX.*TX.*RX bytes:\([0-9]*\).*/\1/p'`
    tx2=`echo $info | sed -n 's/.*RX.*TX.*RX.*TX bytes:\([0-9]*\).*/\1/p'`

    rx=`echo "scale=2; ($rx2-$rx1)/1024" | bc`
    tx=`echo "scale=2; ($tx2-$tx1)/1024" | bc`
    rate="[R:$rx KB/s]\t[S:$tx KB/s]"
    echo $rate
}

function probe_all() {
    i=$2; j=$3
    while [ $i -le $j ]; do
        ni=`printf "%03i" $i`
        node=`echo $1 | sed "s/???/${ni}/"`
        i=`expr $i + 1`
        echo -n "$node rate: "
        rate=`get_rate $node`
        echo -e $rate
    done
}

#
# Main Function
#
count=1

if [ "$1" == "" ]; then
    echo "Usage: rate.sh TRAGET_NODE [ -c NUM | -m ]"
    exit 1
elif [ "$1" == -all ]; then
    if [ $# -ne 4 ]; then
        echo "Usage: rate.sh -all name_pattern start_index end_index"
        echo "Example: rate.sh -all cln??? 1 10"
        exit 1
    fi
    probe_all $2 $3 $4
    exit 0
elif [ "$2" == -c ]; then
    if [ "$3" == "" ]; then
        echo "Usage: rate.sh TRAGET_NODE [ -c NUM | -m ]"
    exit 1
    else
        count=$3
    fi
fi

echo "$1 rate:"
while [ $count -gt 0 ]; do
    if [ "$1" == -lo ]; then
        rate=`get_rate_local lo`
    elif [ "$1" == -eth0 ]; then
        rate=`get_rate_local eth0`
    else
        rate=`get_rate $1`
    fi
    echo -e $rate
    count=`expr $count - 1`
done

exit 0
