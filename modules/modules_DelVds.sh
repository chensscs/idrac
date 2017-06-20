#!/bin/bash
# chenss
# date : 2016-09-11
#
trap 'echo quit; exit 1' SIGINT

source /data/script/idrac/modules/modules_Job.sh
source /data/script/idrac/modules/modules_SysReboot.sh

controller=`racadm -r $1 -u $user -p $passwd storage get controllers --nocertwarn | sed 's/\r/\n/g' | egrep "RAID"`
vds=`racadm -r $1 -u $user -p $passwd storage get vdisks -o -p Size,MediaType --nocertwarn`
vdnosys=`racadm -r $1 -u $user -p $passwd storage get vdisks -o -p Size,MediaType --nocertwarn | egrep -A2 '^Disk' | xargs -n 8 | awk '! /Disk.Virtual.0/ {print $1}'`

# Remove all virtual disks
function clear_raid {
sys_reboot $1
jobreset=`racadm -r $1 -u $user -p $passwd storage resetconfig:$controller --nocertwarn`
if [ $? -eq 0 ]; then
    jobsub $1
else
    echo -e "\e[3;33;1m$1: clean all raid config failure!\e[0m"
fi
}

function delallvdchk {
vdcheck=`racadm -r $1 -u$user -p$passwd storage get vdisks --nocertwarn | egrep -o 'No virtual disks'`
if [ "$vdcheck" == "No virtual disks" ]; then
    echo "$1: The default no raid"
else
    echo "$1: start clear all raid ..."
    clear_raid $1 
    vdchkagain=`racadm -r $1 -u$user -p$passwd storage get vdisks --nocertwarn | egrep -o 'No virtual disks'`
    if [ "$vdchkagain" == "No virtual disks" ]; then
        echo "$1: Through insection,Successfully remove all virtual disks"
    else
        echo -e "\e[0;31;1m$1: Through insection,Delete all virtual disks failed.\e[0m"
        exit
    fi
fi
}

# Remove the virtual disk other than the system disk
function delvd {
if [ -n "$vdnosys" ]; then
sys_reboot $1
for i in $vdnosys; do
    racadm -r $1 -u $user -p $passwd storage deletevd:$i --nocertwarn &> /dev/null
    if [ $? -ne 0 ]; then
        echo -e "\e[0;33;1m$1: storage deletevd:$i failed.\e[0m"
    exit
    fi
done
else 
    echo -e "\e[0;32;0m$1: There is no virtual disk other than the system disk\e[0m"
    exit
fi
jobsub $1
}


function delnosyschk {
vdamount=`racadm -r $1 -u $user -p $passwd storage get vdisks --nocertwarn | wc -l`
if [ $vdamount -eq 1 ]; then
    echo "$1: Through insectioin,Remove the virtual disk other than the system disk success"
else
    echo -e "\e[0;33;1m$1: Thourgh insectioin,Remove the virtual disk other than the system disk failuer,Try a sencond time to delete\e[0m"
        echo "$1: Through insectioin,Remove the virtual disk other than the system disk sccuss"
	exit
fi
}

function main {
if [ "$2" == "all" ]; then
    delallvdchk $1
elif [ "$2" == "nosys" ]; then
    delvd $1
    delnosyschk $1
else
    echo -e "\e[0;31;1m$1: argu error,raid can't clear,please check\e[0m"
    exit
fi
sys_reboot $1
}

main $1 $2
