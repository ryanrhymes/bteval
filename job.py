#!/usr/bin/python

#
# This script is used for starting peers according to the configuration information
# provided in job.txt.
#
# 2010 by Liang Wang
# Department of Computer Sicence, University of Helsinki, Finland

import re, shlex
import os, sys, subprocess
import random, time, sched

#
# Global variables
#
random.seed(time.time())
path = os.path.dirname(__file__)
peer_list = list()
schd_list = dict()
bt_tracker_cmd = ""
bt_seeder_cmd = ""
bt_peer_cmd = ""

eth0_recv1 = -1
eth0_recv2 = -1
eth0_send1 = -1
eth0_send2 = -1
lo_recv1 = -1
lo_recv2 = -1
lo_send1 = -1
lo_send2 = -1

#
# Scheduler
#
def peer_schd(t):
    for i in schd_list.keys():
        if t >= i:
            for peer in schd_list[i]:
                param = ' '
                if not peer['params'].startswith('*'):
                    param += peer['params']
                cmd = bt_peer_cmd + str(random.randint(11111111,99999999)) + param
                subprocess.Popen(shlex.split(cmd), shell=False)
            del schd_list[i]

#
# Monitor the traffic through eth0 and lo
#
def record_traffic(record_file):
    global eth0_recv1, eth0_recv2, eth0_send1, eth0_send2, lo_recv1, lo_recv2, lo_send1, lo_send2
    interface_type = 0
    p = subprocess.Popen("/sbin/ifconfig", stdout=subprocess.PIPE)
    for line in p.stdout.readlines():
        if line.startswith("lo"):
            interface_type = 1
        elif line.startswith("eth2"):
            interface_type = 2

        m = re.search(r"\s*RX bytes:(\d+).*?TX bytes:(\d+)", line)
        if m and interface_type==2:
            interface_type = 0
            eth0_recv2 = int(m.group(1))
            eth0_send2 = int(m.group(2))
        elif m and interface_type==1:
            interface_type = 0
            lo_recv2 = int(m.group(1))
            lo_send2 = int(m.group(2))

    if eth0_recv1 < 0:
        eth0_recv1 = eth0_recv2
        eth0_send1 = eth0_send2
        lo_recv1 = lo_recv2
        lo_send1 = lo_send2

    f = open(record_file, "w")
    f.write("eth0 traffic in MegeBytes:\n")
    f.write("Recv:" + str((eth0_recv2-eth0_recv1)/2**20) + "\t\tSend:" + str((eth0_send2-eth0_send1)/2**20) + "\n\n")
    f.write("lo traffic in MegaBytes:\n")
    f.write("Recv:" + str((lo_recv2-lo_recv1)/2**20) + "\t\tSend:" + str((lo_send2-lo_send1)/2**20) + "\n")
    f.close()
    pass

#
# Main function
# $1    job configuration file
# $2    torrent file
# $3    target file
#
if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: job.py job.txt torrent target")
        sys.exit(1)
    job_file = sys.argv[1]
    torrent_file = sys.argv[2]
    target_file = sys.argv[3]
    traffic_file = os.path.join(os.path.dirname(target_file), "peer-traffic-"+os.uname()[1]+".txt")
    tracker_log = os.path.join(os.path.dirname(target_file), "dstat")
    
    bt_tracker_cmd = "python "+os.environ["HOME"]+"/BitTorrent-4.0.0-GPL/bttrack.py --port 6969 --dfile "+tracker_log+" --save_as "+target_file
    bt_seeder_cmd = "python "+os.environ["HOME"]+"/BitTorrent-4.0.0-GPL/btdownloadheadless.py "+torrent_file+" --save_as "+target_file+" "
    bt_peer_cmd = "python "+os.environ["HOME"]+"/BitTorrent-4.0.0-GPL/btdownloadheadless.py "+torrent_file+" --save_as "+target_file+"."
    
    # test code: not sure yet
    f = open(target_file, "rb", -1)
    s = f.read()
    
    lines = list()
    # Pick up the jobs for the node on which I am running now
    for line in open(job_file, 'r').readlines():
        if line.startswith(os.uname()[1]):
            lines += [line]

    # Add the jobs to schedule list. Start the tracker and seeder first!
    # REMARK: ONLY ONE TRACKER and MULTIPLE SEEDERS allowed! BE CAREFUL!
    for line in lines:
        n, s, e, p = re.split('\t+', line)
        if s[0]==e[0]==p[0]=='*':
            subprocess.Popen(shlex.split(bt_tracker_cmd), shell=False)
            continue
        if s[0]==e[0]=='*':
            subprocess.Popen(shlex.split(bt_seeder_cmd + p), shell=False)
            continue
        s = int(s)
        peer_list += [dict({'node':n, 'start':s, 'end':e, 'params':p})]
        if s in schd_list.keys():
            schd_list[s] += peer_list[-1:]
        else:
            schd_list[s] = peer_list[-1:]

    time.sleep(3)
    schd = sched.scheduler(time.time, time.sleep)
    while schd_list:
        t = min(schd_list.keys())
        schd.enter(t, 1, peer_schd, ([t]))
        schd.run()

    while True:
        record_traffic(traffic_file)  # need modifications if running on ukko, since multiple ethernet cards are installed on ukko cluster node.
        time.sleep(5)

    sys.exit(0)