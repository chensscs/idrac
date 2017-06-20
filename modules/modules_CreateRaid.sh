#!/bin/bash
# chenss
# date : 2016-09-11
#
if [ $# -ne 2 ]; then
    echo -e "\e[0;31;1m$1: Current syntax: sh \$script \$raid_level,please check hosts file format\e[0m"
    exit
fi

trap 'echo quit; exit 1' SIGINT

source /data/script/idrac/modules/modules_Job.sh
source /data/script/idrac/modules/modules_SysReboot.sh

pdisks=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType --nocertwarn | egrep 'Disk.Bay|State|Size|MediaType' | sed 's/\r//g'`
pdisks_pending=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType -pending --nocertwarn | egrep 'Disk.Bay|State|Size|MediaType' | sed 's/\r//g'`
HDD_SYS_NUM=`echo $pdisks | xargs -n 11 | awk '$7 < 600 && $7 > 500 {print $1}' | wc -l`
HDD_SYS_STATE=`echo $pdisks | xargs -n 11 | awk '$7 < 600 && $7 > 500 {print $4}' | uniq`
HDD_SYS=`echo $pdisks | xargs -n 11 | awk '$7 < 600 && $7 > 500 {print $1}'`
HDD_SYS_VD=`echo $HDD_SYS | awk 'gsub(/ /,",")'`
SSD_NUM=`echo $pdisks | xargs -n 11 | awk '$NF == "SSD" {print $1}' | wc -l`
SSD_SRC_pending=`echo $pdisks_pending | xargs -n 11 | awk '$NF=="SSD"'`
SSD_SRC=`echo $pdisks | xargs -n 11 | awk '$NF=="SSD"'`
SSD=`echo $pdisks | xargs -n 11 | awk '$NF=="SSD" {print $1}'`
SSD_STATE=`echo $pdisks | xargs -n 11 | awk '$NF=="SSD" {print $4}' | uniq`
HDD_NUM=`echo $pdisks | xargs -n 11 | awk '$7 > 1000 {print $1}' | wc -l`
HDD_STATE=`echo $pdisks | xargs -n 11 | awk '$7 > 1000 {print $4}' | uniq`
HDD=`echo $pdisks | xargs -n 11 | awk '$NF=="HDD" {print $1}'`
HDD_VD=`echo $pdisks | xargs -n 11 | awk '$7 > 1000 && $NF=="HDD" {print $1}' | sed  "s/\n/,/g" | sed ":label;N;s/\n/,/;b label"`
vdisks=`racadm -r $1 -u $user -p $passwd storage get vdisks -o -p State,Size,MediaType --nocertwarn`
sys_size=`echo $vdisks | xargs -n 11 | awk '/Disk.Virtual.0/ {print $9}'`
power_status=`racadm -r $1 -u $user -p $passwd serveraction powerstatus --nocertwarn | egrep -o 'ON|OFF'`

# 判断558G的系统磁盘
function SYSTEM_RAID  {
if [ $HDD_SYS_NUM -eq 2 ]; then
    racadm -r $1 -u $user -p $passwd storage createvd:$controller -rl r1 -pdkey:$HDD_SYS_VD --nocertwarn &> /dev/null 
    if [ $? -eq 0 ]; then
        echo "$1: TWO 558G HD raid1 create successfully."
    else
        echo -e "\e[0;31;1m$1: TWO 558G HD raid1 create failure.\e[0m"
        exit
    fi
    jobsub $1
    local vd_sys=`racadm -r $1 -u $user -p $passwd storage get vdisks -o -p State,Size,MediaType --nocertwarn| xargs -n 11 | awk '/Disk.Virtual.0/ {print $9}'`
    if [ $vd_sys -gt 500 -a $vd_sys -lt 600 ]; then
         echo "$1: Through inspection, vd0 create success"    
    else
         echo -e "\e[0;31;1m$1: Through inspection, vd0 create failure\e[0m" 
         exit
    fi
fi
}

# HDD单盘做raid0
function HDD_RAID0 {
echo "$1: start raid0 create ..."
for i in $HDD; do
    racadm -r $1 -u $user -p $passwd storage createvd:$controller -rl r0 -pdkey:$i --nocertwarn &> /dev/null
    if [ $? -eq 0 ]; then
        echo "$1: raid 0 create successfully."
    else
        echo -e "\e[0;31;1m$1: raid 0 create flase.\e[0m"
        exit
    fi
done
jobsub $1
echo "$1: raid0 create over..."
}

# 包含2块558G系统盘的raid5
function RAID15 {
echo "$1: start create disk to raid5..."
racadm -r $1 -u $user -p $passwd storage createvd:$controller -rl r5 -pdkey:$HDD_VD --nocertwarn &> /dev/null 
if [ $? -eq 0 ]; then
    echo "$1: virtual disk 1 create success for raid5"
else
    echo -e "\e[0;31;1m$1: virtual disk 1 create failure with raid5.Disk mode may be wrong,please check\e[0m"
    exit
fi
jobsub $1

local vds=`racadm -r $1 -u $user -p $passwd storage get vdisks -o -p State,Size,MediaType --nocertwarn`
if echo $vds | xargs -n 11 | egrep 'Disk.Virtual.1' &> /dev/null; then
    echo "$1: Through inspection, vd1 create success with raid5"    
else
    echo -e "\e[0;31;1m$1: Through inspection, vd1 create failure with raid5\e[0m" 
    exit
fi
}

# 不包含2块500G系统盘的raid5
function RAID5 {
echo "$1: start craete disk equal to 300g for vd0 with raid5..."
racadm -r $1 -u $user -p $passwd storage createvd:$controller -rl r5 -size 300g -pdkey:$HDD_VD --nocertwarn &> /dev/null
if [ $? -eq 0 ]; then
    echo "$1: 300g virtual disk 0 created success with raid5."
else
    echo -e "\e[0;31;1m$1: 300g virtual disk 0 create failure with raid5.Disk mode may be wrong,please check\e[0m"
    exit
fi

echo "$1: start craete disk the rest part for vd1 with raid5"
racadm -r $1 -u $user -p $passwd storage createvd:$controller -rl r5 -pdkey:$HDD_VD --nocertwarn &> /dev/null
if [ $? -eq 0 ]; then
    echo "$1: virtual disk 1 create success for raid5."
else
    echo -e "\e[0;31;1m$1: raid5 virtual disk 1 create failure.\e[0m"
    exit
fi
jobsub $1

local vds=`racadm -r $1 -u $user -p $passwd storage get vdisks -o -p State,Size,MediaType --nocertwarn`
if echo $vds | xargs -n 11 | egrep 'Disk.Virtual.0' &> /dev/null; then
    echo "$1: Through inspection, 300g virtual disk sda create success with raid5"    
else
    echo -e "\e[0;31;1m$1: Through inspection, 300g virtual disk  create failure with raid5\e[0m" 
    exit
fi

if echo $vds | xargs -n 11 | egrep 'Disk.Virtual.1' &> /dev/null; then
    echo "$1: Through inspection, virtual disk sdb create success with raid5"    
else     
    echo -e "\e[0;31;1m$1: Through inspection, virtual disk sdb create failure with raid5\e[0m" 
    exit
fi
}

############################# 以上均为变量与函数，下部分为执行部分######################################

function power_status {
# check power status; if power off ; then power up
if [ "$power_status" == "OFF" ]; then
    racadm -r $1 -u $user -p $passwd serveraction powerup --nocertwarn &> /dev/null 
    if [ $? -eq 0 ]; then
        echo "$1 server power start successfully."
    else
        echo -e "\e[0;31;1m$1 server power start failure." 
        exit
    fi
elif [ "$power_status" == "ON" ]; then
	racadm -r $1 -u $user -p $passwd serveraction powercycle --nocertwarn &> /dev/null	
    echo "$1: serveraction powercycle!"
else
    echo -e "\e[0;31;1m$1: server abnormal;May be network impassability\e[0m"
    exit
fi
}

function sys_install {
power_status $1
jobdel $1
echo "$1: It may take 15 minutes,Please wait..."
case $2 in 
1)SYSTEM_RAID $1;;
5)
if [ $HDD_SYS_NUM -eq 2 ]; then
    SYSTEM_RAID $1
    RAID15 $1
elif [ $HDD_SYS_NUM -eq 0 ]; then
    RAID5 $1
fi
;;
*)echo -e "\e[0;31;1m$1:Privide the raid argu error,Please check hosts.conf file\e[0m";;
esac
sys_reboot $1
echo "$1: Operation is completed..."
}

function create_raid {
if [ -z "$sys_size" ]; then
    sys_install $1 $2
elif [ $sys_size -lt 600 ]; then
    sys_install $1 $2
else
    clear_raid $1
    sys_install $1 $2
fi
}

create_raid $1 $2
