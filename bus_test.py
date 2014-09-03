#!/usr/bin/python

#
# This script is used for probing the data tranfer rate on system bus
#
# 2010 Liang Wang
# Department of Computer Sicence, University of Helsinki, Finland
usage = "Usage: bus_test.py -[ read | write ]"

import socket
import os
import array
from time import *
from sys import *
from threading import *

#   bsize - in bytes
#   interval - in seconds
def read_test(fname, bsize, interval):
    f = open(fname, 'r', bsize)
    dsize = 0; dtime = time()
    isize = 0; itime = time()
    interval *= 1.0

    now = time()
    while (now - dtime) <= interval :
        f.read(bsize)
        dsize += bsize
        isize += bsize
        if (now - itime) >= 1.0 :
            print("Instant Read Rate -> " + str(int(isize/2**20)) + " MB/s")
            isize = 0;
            itime = now
        now = time()
    
    print("AVG R RATE (buf:" + str(int((bsize/2**10))) + "KB) -> " + str(int( (dsize/2**20)/(now-dtime) )) + " MB/s")
    return int( (dsize/2**20)/(now-dtime) )


def write_test(fname, bsize, interval):
    f = open(fname, 'w', bsize)
    buf = open('/dev/zero', 'r', bsize).read(bsize)
    dsize = 0; dtime = time()
    isize = 0; itime = time()
    interval *= 1.0

    now = time()
    while (now - dtime) <= interval :
        f.write(buf)
        # f.flush()     # Will flush cause any differences?
        dsize += bsize
        isize += bsize
        if (now - itime) >= 1.0 :
            print("Instant Write Rate -> " + str(int(isize/2**20)) + " MB/s")
            isize = 0;
            itime = now
        now = time()
    
    print("AVG W RATE (buf:" + str(int((bsize/2**10))) + "KB) -> " + str(int( (dsize/2**20)/(now-dtime) )) + " MB/s")
    return int( (dsize/2**20)/(now-dtime) )

    
def full_read_test(fname):
    buf_size = (2**10)*1
    step_size = (2**10)*16  # 16KiB
    last_size = (2**20)*20  # 20MiB
    
    while buf_size <= last_size :
        avg_r = read_test(fname, buf_size, 15)
        if buf_size == (2**10)*1 : buf_size = 0
        buf_size += step_size
        open('bus_test_read.log','a').write(str(avg_r)+"\n")


def full_write_test(fname):
    buf_size = (2**10)*1
    step_size = (2**10)*16  # 16KiB
    last_size = (2**20)*20  # 20MiB

    while buf_size <= last_size :
        avg_w = write_test(fname, buf_size, 15)
        if buf_size == (2**10)*1 : buf_size = 0
        buf_size += step_size
        open('bus_test_write.log','a').write(str(avg_w)+"\n")


# network test

# return value is in MB
def net_test_sender(ip, bsize, interval, rate):
    buf = open('/dev/zero', 'r', bsize).read(bsize)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    sock.connect((ip, 8001))

    dsize = 0; dtime = time()
    isize = 0; itime = time()
    interval *= 1.0

    while (time() - dtime) <= interval :
        ssize = sock.send(buf)
        dsize += ssize
        isize += ssize
        if (time() - itime) >= 1.0 :
            print("Instant Write Rate -> " + str(int( isize/((2**20)*(time()-itime)) )) + " MB/s")
            isize = 0;
            itime = time()

    sock.close()    
    w_rate = int( dsize/((2**20)*(time()-dtime)) )
    print("AVG W RATE (buf:" + str(int((bsize/2**10))) + "KB) -> " + str(w_rate) + " MB/s")
    rate[0] = w_rate
    return w_rate


def net_test_receiver(ip, bsize, interval):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
    sock.bind((ip, 8001))  
    sock.listen(5) 
    dsize = 0; dtime = time()

    while True:
        try:
            #print(bsize[0])
            connection,address = sock.accept() 
            connection.settimeout(2)
            while True:
                buf = connection.recv(bsize[0])
                if not buf: break;
                buf = ''    # Test, can it delete buffer?????
                del buf
            connection.close()

        except socket.timeout:
            print 'time out'

    sock.close()
    pass


def full_net_test():
    recv_size = [(2**10)*1]
    send_size = (2**10)*1
    step_size = (2**10)*16  # 16KiB
    last_size = (2**20)*1   # 1MiB
    interval = 30
    rate = [0]
    exp_data = ''
  
    receiver = Thread(target = net_test_receiver, args= (os.uname()[1],recv_size,interval))
    receiver.daemon = False
    receiver.start()

    while recv_size[0] <= last_size:
        while send_size <= last_size:
            sender = Thread(target = net_test_sender, args= (os.uname()[1],send_size,interval,rate))
            sender.daemon = False
    
            sender.start()
    
            sender.join()
            
            exp_data += str(rate[0]) + '\t\t'
            log_str = 'recv='+str(int( recv_size[0]/(2**10) ))+'\t\tsend='+str(int( send_size/(2**10) ))+'\n'   # in KB
            print(log_str)
            open('bus_test_net.log', 'a').write(log_str)
            
            if send_size == (2**10)*1 : send_size = 0
            send_size += step_size
            pass
            
        open('bus_test_net.data', 'a').write(exp_data+'\n')
        exp_data = ''
        if recv_size[0] == (2**10)*1 : recv_size[0] = 0
        recv_size[0] += step_size
        send_size = (2**10)*1
        pass    

    pass


def net_test_opt_sender(ip, bsize, interval, rate):
    buf = array.array('c', 'a'*bsize)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOCK_STREAM, socket.SO_SNDBUF, bsize)
    sock.connect((ip, 8001))

    dsize = 0; dtime = time()
    isize = 0; itime = time()
    interval *= 1.0

    while (time() - dtime) <= interval :
        ssize = sock.send(buf)
        dsize += ssize
        isize += ssize
        if (time() - itime) >= 1.0 :
            print("Instant Write Rate -> " + str(int( isize/((2**20)*(time()-itime)) )) + " MB/s")
            isize = 0;
            itime = time()
    
    sock.shutdown(socket.SHUT_RDWR)
    sock.close()
    w_rate = int( dsize/((2**20)*(time()-dtime)) )

    print("sender: AVG W RATE (buf:" + str(int((bsize/2**10))) + "KB) -> " + str(w_rate) + " MB/s")
    rate[0] = w_rate
    return w_rate


def net_test_opt_receiver(ip, bsize, interval):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
    sock.bind((ip, 8001))  
    sock.listen(5) 
    dsize = 0; dtime = time()
    buf = array.array('c', '')

    while True:
        try:
            connection,address = sock.accept() 
            connection.settimeout(2)
            if bsize[0] != len(buf):
                print('server: change buf_size to '+str(int((bsize[0]/2**10)))+'KB')
                connection.setsockopt(socket.SOCK_STREAM, socket.SO_RCVBUF, bsize[0])
                buf = array.array('c', ' '*bsize[0])
            while True:
                i = connection.recv_into(buf)
                if i==0: break;
            print('server: close connection!\n')
            connection.close()
        except socket.timeout:
            print 'time out'

    sock.close()
    pass
        
        
def net_test_ex(recv_size, send_size):
    recv_size = [recv_size]
    interval = 60
    rate = [0]

    receiver = Thread(target = net_test_receiver, args= (os.uname()[1],recv_size,interval))
    receiver.daemon = False
    receiver.start()

    sender = Thread(target = net_test_sender, args= (os.uname()[1],send_size,interval,rate))
    sender.daemon = False
    sender.start()
    sender.join()

    pass




def net_test_opt(recv_size, send_size):
    recv_size = [recv_size]
    interval = 60
    rate = [0]

    receiver = Thread(target = net_test_opt_receiver, args= (os.uname()[1],recv_size,interval))
    receiver.daemon = False
    receiver.start()

    sender = Thread(target = net_test_opt_sender, args= (os.uname()[1],send_size,interval,rate))
    sender.daemon = False
    sender.start()
    sender.join()

    pass


def full_net_opt_test():
    recv_size = [(2**10)*16]
    send_size = (2**10)*16
    step_size = (2**10)*16  # 16KiB
    last_size = (2**20)*1   # 1MiB
    interval = 5
    rate = [0]
    exp_data = ''
  
    receiver = Thread(target = net_test_opt_receiver, args= (os.uname()[1],recv_size,interval))
    receiver.daemon = False
    receiver.start()

    while recv_size[0] <= last_size:
        while send_size <= last_size:
            sender = Thread(target = net_test_opt_sender, args= (os.uname()[1],send_size,interval,rate))
            sender.daemon = False
    
            sender.start()
    
            sender.join()
            
            exp_data += str(rate[0]) + '\t\t'
            log_str = 'recv='+str(int( recv_size[0]/(2**10) ))+'\t\tsend='+str(int( send_size/(2**10) ))+'\n'   # in KB
            print(log_str)
            open('bus_test_net.log', 'a').write(log_str)
            
            if send_size == (2**10)*1 : send_size = 0
            send_size += step_size
            pass
            
        open('bus_test_net.data', 'a').write(exp_data+'\n')
        exp_data = ''
        if recv_size[0] == (2**10)*1 : recv_size[0] = 0
        recv_size[0] += step_size
        send_size = (2**10)*16
        pass    

    pass



# Max connections test
def net_maxconns_client(ip, port):
    conns_pool = []

    while True:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((ip, port))
        sock.send("Hello")
        conns_pool += [sock]
        sleep(0.3)
    pass

def net_maxconns_server(ip, port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
    sock.bind((ip, port))  
    sock.listen(5) 
    conns_pool = []

    while True:
        try:
            connection,address = sock.accept() 
            connection.settimeout(2)
            msg = connection.recv(64)
            conns_pool += [connection]
            print('%i connectionns, msg: %s' % (len(conns_pool), msg))
        except socket.timeout:
            print 'time out'

    sock.close()
    pass
    
def net_maxconns(port):
    """port = 8001
    for p in range(port, port+1000):
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.bind((ip,p))
            port = p
            sock.close()
            break
        except:
            sock.close()
    print("Listen on port %i" % port)"""

    receiver = Thread(target = net_maxconns_server, args= (os.uname()[1], port))
    receiver.daemon = False
    receiver.start()

    sender = Thread(target = net_maxconns_client, args= (os.uname()[1], port))
    sender.daemon = False
    sender.start()
    sender.join()

    pass
        

#
# Main function
#
if __name__ == '__main__':
    try:
        if argv[1] == '-read':
            full_read_test('/dev/zero')
        elif argv[1] == '-write':
            full_write_test('/dev/zero')
        elif argv[1] == '-net':
            full_net_test()
        elif argv[1] == '-netex':
            net_test_ex(int(argv[2]), int(argv[3]))
        elif argv[1] == '-netopt':
            full_net_opt_test()
        elif argv[1] == '-maxconns':
            net_maxconns(int(argv[2]))
        else:
            print usage
    except:
        print usage
        exit(1)
        
    exit(0)
