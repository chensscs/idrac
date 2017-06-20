#!/bin/bash
#
trap 'echo quit; exit 1' SIGINT
user='root'
passwd='calvin'
controller=`racadm -r $1 -u $user -p $passwd storage get controllers --nocertwarn | sed 's/\r/\n/g' | egrep "RAID"`

#racadm -r $1 -u $user -p $passwd get nic.NICConfig.3.LegacyBootProto
start=`racadm -r $1 -u $user -p $passwd get BIOS.BiosBootSettings.BootSeq --nocertwarn | egrep 'BootSeq'`
fir_start=`echo $start | awk -F "[=.]" '{print $2}'`

if [[ "$fir_start" != "HardDisk" ]]; then
    echo -e "\e[0;31;1m$1: $start"
else
    echo "$1: First start from the HardDisk"
fi
