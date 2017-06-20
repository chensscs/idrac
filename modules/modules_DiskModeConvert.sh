#!/bin/bash
# chenss
# date : 2016-09-11
#
if [ $# -ne 2 ]; then
    echo -e "\e[0;31;1m$1: Current syntax: sh \$script \$disk_mode,please check hosts file format\e[0m"
    exit
fi

trap 'echo quit; exit 1' SIGINT

source /data/script/idrac/modules/modules_Job.sh
source /data/script/idrac/modules/modules_SysReboot.sh

pdisks=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType --nocertwarn | sed 's/\r//g'`
pdisks_pending=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType -pending --nocertwarn | sed 's/\r//g'`
HDD_SYS=`echo $pdisks | xargs -n 11 | awk '$10 < 600 && $10 > 500 {print $1}'`
SSD_SRC_pending=`echo $pdisks_pending | xargs -n 11 | awk '$NF=="SSD" {print $0}'`
SSD_SRC=`echo $pdisks | xargs -n 11 | awk '$NF=="SSD" {print $0}'`
SSD=`echo $pdisks | xargs -n 11 | awk '$NF=="SSD" {print $1}'`
HDD=`echo $pdisks | xargs -n 11 | awk '$NF=="HDD" {print $1}'`
power_status=`racadm -r $1 -u $user -p $passwd serveraction powerstatus --nocertwarn | egrep -o 'ON|OFF'`



# Disk mode convert prompt
function convert_prompt {
    if [ $? -eq 0 ]; then
        echo "$1: $i  mode convert success."
    else
        echo -e "\e[0;31;1m$1: $i mode convert failed,please check!\e[0m"
        exit
    fi
}

# 转换所有磁盘格式为nonraid
function HDD_NORAID {
echo "$1: start convert disk mode to no raid."
for i in $HDD; do
    if echo $pdisks_pending | xargs -n 11 | awk '$NF=="HDD" && $(NF-4) > 600' | grep $i |  egrep 'Ready|Online' &> /dev/null; then
        racadm -r $1 -u $user -p $passwd storage converttononraid:$i --nocertwarn  &> /dev/null
        convert_prompt 
    else
        echo "$1: $i current mode is noraid"
    fi
done
jobsub $1
local pdisks=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType --nocertwarn | sed 's/\r//g'`
for i in $HDD; do
    if echo $pdisks | xargs -n 11 | awk '$NF=="HDD"' | grep $i |  egrep 'Ready|Online' &> /dev/null; then
         echo -e "\e[0;31;1m$1: Through inspection,$i mode is online\e[0m"
    else
         echo "$1: Through inspecion,$i mode is Non-Raid"
    fi
done
echo "$1: HDD convert over ..."
}

# 转换硬盘模式为TORAID
function HDD_TORAID {
echo "$1: start HDD convert to raid ."
for i in $HDD; do
    if  echo $pdisks_pending | xargs -n 11 | egrep $i | egrep Non-Raid &> /dev/null; then
        racadm -r $1 -u $user -p $passwd storage converttoraid:$i --nocertwarn  &> /dev/null
        convert_prompt $1
    else
        echo "$1: $i current mode is raid"
    fi
done
jobsub $1
local pdisks_chk=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType --nocertwarn | sed 's/\r//g'`
for i in $HDD; do
    if echo $pdisks_chk | xargs -n 11 | awk '$10 > 1000 {print $0}' | grep $i |  egrep 'Non-Raid' &> /dev/null; then
         echo -e "\e[0;31;1m$1: Through inspection,$i mode is Non-Raid\e[0m"
    else
         echo "$1: Through inspecion,$i mode is Online"
    fi
done
echo "$1: HDD convert over ..."
}

function SSD_TORAID {
if  echo $SSD_SRC_pending | xargs -n 11 | egrep 'Non-Raid' &> /dev/null ; then
    for i in $SSD; do
        racadm -r $1 -u $user -p $passwd storage converttoraid:$i --nocertwarn &> /dev/null
        if [ $? -eq 0 ]; then
            echo "$1: $i disk mode convert to Riad scccess..."
        else
            echo "$1: $i disk current mode is already online..."
        fi
    done
    jobsub $1
    sleep 5
# 检查模式转换后磁盘状态
    local SSD_SRC_CHK=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType --nocertwarn 2> /dev/null | sed 's/\r//g' | xargs -n 11 | awk '$NF=="SSD"'`
    for i in $SSD; do
        racadm -r $1 -u $user -p $passwd storage converttoraid:$i --nocertwarn &> /dev/null
        if [ $? -eq 0 ]; then
            echo "$1: $i disk mode convert TO-Riad scccess..."
        else
            echo "$1: $i current mode is online"
        fi
    done
fi
}

function SSD_JOBD {
if echo $SSD_SRC_pending | xargs -n 11 | egrep 'Online|Ready' &> /dev/null; then
    for i in $SSD; do
        racadm -r $1 -u $user -p $passwd storage converttononraid:$i --nocertwarn &> /dev/null
        if [ $? -eq 0 ]; then
            echo "$1: $i disk mode convert Non-Riad scccess..."
        else
            echo "$1: $i disk mode is already Non-Raid..."
        fi
    done
    jobsub $1
    sleep 5
    local SSD_SRC_CHK=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType --nocertwarn 2> /dev/null | sed 's/\r//g' | xargs -n 11 | awk '$NF=="SSD"'`
    if echo $SSD_SRC_CHK | xargs -n 11 | egrep 'Online|Ready' &> /dev/null; then
         echo -e "\e[0;31;1m$1: Through inspection,Disk mode converted abnormal\[0m"
		 exit
    else
         echo "THrough insepction,SSD mode is Non-Raid"
    fi 
fi
}

function ALL_TORAID {
echo "$1: start all disk convert to raid ."
for i in `echo "$pdisks" | xargs -n 11 | awk '{print $1}'`; do
    if  echo $pdisks_pending | xargs -n 11 | egrep $i | egrep Non-Raid &> /dev/null; then
        racadm -r $1 -u $user -p $passwd storage converttoraid:$i --nocertwarn  &> /dev/null
        convert_prompt $1
    else
        echo "$1: $i current mode is raid"
    fi
done
jobsub $1
sleep 5
local pdisks_chk=`racadm -r $1 -u $user -p $passwd storage get pdisks -o -p State,Size,MediaType --nocertwarn 2> /dev/null | sed 's/\r//g'`
for i in `echo "$pdisks" | xargs -n 11 | awk '{print $1}'`; do
    if echo $pdisks_chk | xargs -n 11 | grep $i |  egrep 'Non-Raid' &> /dev/null; then
         echo -e "\e[0;31;1m$1: Through inspection,$i mode is Non-Raid\e[0m"
    else
         echo "$1: Through inspection,$i mode is Online"
    fi
done
echo "$1: All disk convert over ..."
}

############################# 以上均为变量与函数，下部分为执行部分######################################

function power_status {
# check power status; if power off ; then power up
if [ "$power_status" == "OFF" ]; then
    racadm -r $1 -u $user -p $passwd serveraction powerup --nocertwarn &> /dev/null 
    if [ $? -eq 0 ]; then
        echo "$1 server power start successfully."
    else
        echo -e "\e[0;31;1m$1 server power start failed." 
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

function main {
power_status $1
jobdel $1
case $2 in
hdd_raid)HDD_TORAID $1;;
hdd_jobd)HDD_NORAID $1;;
ssd_raid)SSD_TORAID $1;;
ssd_jobd)SSD_JOBD $1;;
all_raid)ALL_TORAID $1;;
*) echo -e "\e[0;31;1m$1:Privide the raid argu error,Please check hosts.conf file\e[0m";;
esac
sys_reboot $1
echo "Operation is completed..."
}

# main函数会判断是安装系统还是转换硬盘模式
main $1 $2
