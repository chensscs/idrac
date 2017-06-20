#!/bin/bash
#
user='root'
passwd='calvin'

function sys_reboot {
racadm -r $1 -u $user -p $passwd serveraction powercycle --nocertwarn &> /dev/null
if [ $? -eq 0 ]; then
    echo "$1: server powercycle success"
else
    echo -e "\e[0;31;1m$1:\t server powercycle false\e[0m"
    exit
fi
}

sys_reboot $1
