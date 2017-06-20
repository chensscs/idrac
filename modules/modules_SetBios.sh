#!/bin/bash
# chenss
# date : 2016-09-14
#

source /data/script/idrac/modules/modules_Job.sh
source /data/script/idrac/modules/modules_SysReboot.sh

function BiosSet {
local default_Seq=`racadm -r $1 -u $user -p $passwd get BIOS.BiosBootSettings.BootSeq  | awk -F "[=.]" '/BootSeq/ {print $2}'`
#local def_seq_pend=`racadm -r $1 -u $user -p $passwd get BIOS.BiosBootSettings.BootSeq  | awk -F "[=.]" '/Pending/ {print $2}'`
local BiosErrPrompt=`racadm -r $1 -u $user -p $passwd get BIOS.MiscSettings.ErrPrompt`

# BIOS F1/F2 ErrPrompt
if [ "`echo $BiosErrPrompt | egrep -o 'Disabled' | sort -u`" != "Disabled" ]; then
    racadm -r $1 -u $user -p $passwd set BIOS.MiscSettings.ErrPrompt Disabled &> /dev/null
    if [ $? -eq 0 ]; then
        echo "$1: Successfully disabled BIOS F1/F2 error prompt."
    else
        echo -e "\e[0;31;1m$1: BIOS F1/F2 error prompt is Enabled.please change Disabeld\e[0m"
        exit
    fi
else
    echo "$1: BIOS F1/F2 errot prompt default is Disabled"
fi

# BIOS BOOT Seq 
if [ "$default_Seq" == "HardDisk" ]; then
    echo "$1: Hard disk drive default is the first boot"
else
    BOOTSEQ="HardDisk.List.1-1,NIC.Integrated.1-1-1"
    #BOOTSEQ="HardDisk.List.1-1,NIC.Integrated.1-3-1,NIC.Integrated.1-1-1,NIC.Integrated.1-2-1,NIC.Integrated.1-4-1"
#    racadm -r $1 -u $user -p $passwd set iDRAC.serverboot.FirstBootDevice HDD &> /dev/null
    racadm -r $1 -u $user -p $passwd set BIOS.BiosBootSettings.BootSeq $BOOTSEQ &> /dev/null
    if [ $? -eq 0 ]; then
        echo "$1: Successfully set the hard disk drive as the first boot."
    else
        echo -e "\e[0;31;1m$1: Set failed,The boot sequence: ${default_Seq}.\e[0m"
        exit
    fi
    jobsub_bios $1
#else
#    echo "$1: Hard disk drive default is the first boot"
fi
}

BiosCheck () {
local error_prom_chk=`racadm -r $1 -u $user -p $passwd get BIOS.MiscSettings.ErrPrompt --nocertwarn`
if [ "`echo $error_prom_chk | egrep -o 'Disabled' | sort -u`" == "Disabled" ]; then
        echo "$1: After testing,BIOS F1/F2 error prompt is Disabled."
else
        echo -e "\e[0;31;1m$1: After testing,BIOS F1/F2 error prompt is Enabled.please change Disabeld\e[0m"
        exit
fi

local seq_check=`racadm -r $1 -u $user -p $passwd get BIOS.BiosBootSettings.BootSeq  | awk '/BootSeq/'`
if [ "`echo $seq_check | awk -F "[=.]" '{print $2}'`" == "HardDisk" ]; then
    echo "$1: After testing,Hard disk first boot."
else
    echo -e "\e[0;31;1m$1: After testing,The boot sequence: ${seq_check}.\e[0m"
    exit
fi
}

function main {
jobdel $1
BiosSet $1
if [ "`echo $BiosErrPrompt | egrep -o 'Disabled'`" != "Disabled" -o "$default_Seq" != "HardDisk" ]; then
    BiosCheck $1
fi
}

main $1
