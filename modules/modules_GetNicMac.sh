#!/bin/bash
# chenss
# date : 2016-09-09
#
user='root'
passwd='calvin'

get_nic () {
case $2 in
1)racadm -r $1 -u $user -p $passwd  getsysinfo -s --nocertwarn | egrep '1-1-1' | awk -v ip="$1" 'BEGIN{FS="="} {print ip"\t""EM1"$2};';;
2)racadm -r $1 -u $user -p $passwd  getsysinfo -s --nocertwarn | egrep '1-2-1|2-1-1' | awk -v ip="$1" 'BEGIN{FS="="} {print ip"\t""EM2"$2};';;
3)racadm -r $1 -u $user -p $passwd  getsysinfo -s --nocertwarn | egrep '1-3-1|3-1-1' | awk -v ip="$1" 'BEGIN{FS="="} {print ip"\t""EM3"$2};';;
4)racadm -r $1 -u $user -p $passwd  getsysinfo -s --nocertwarn | egrep '1-4-1|4-1-1' | awk -v ip="$1" 'BEGIN{FS="="} {print ip"\t""EM4"$2};';;
*)racadm -r $1 -u $user -p $passwd  getsysinfo -s --nocertwarn | egrep 'Ethernet' | awk -v ip="$1" '{print ip"\t",$0};';;
esac
}

get_nic $1 $2

