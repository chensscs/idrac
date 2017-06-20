#!/bin/bash
# chenss
# date : 2016-09-09
#
user='root'
pawd='calvin'
newpawd='Root&9s2'
adduser='admin'
addpawd='Admin&3sf'

function useradd {
racadm -r $1 -u $user -p $pawd set idrac.users.15.username $adduser &> /dev/null
racadm -r $1 -u $user -p $pawd set idrac.users.15.password $addpawd &> /dev/null
racadm -r $1 -u $user -p $pawd set idrac.users.15.Privilege 0x1ff &> /dev/null
racadm -r $1 -u $user -p $pawd set idrac.users.15.enable enabled &> /dev/null
}

function chpawd {
racadm -r $1 -u $adduser -p $addpawd set idrac.users.2.password $newpawd &> /dev/null
}

useradd $1

if racadm -r $1 -u $adduser -p $addpawd get BIOS.SysInformation.SystemServiceTag &> /dev/null; then
    echo -e "$1:\t user $adduser add \e[0;32;1msuccess\e[0m!"
else
    echo -e "$1:\t user $adduser add \e[40;31;5mfailed\e[0m,please re-add!"
fi

chpawd $1
if racadm -r $1 -u $user -p $newpawd get BIOS.SysInformation.SystemServiceTag &> /dev/null; then
    echo -e "$1:\t user root password changed \e[0;32;1msuccess\e[0m!"
else
    echo -e "$1:\t user root password changed \e[40;31;5mfalse\e[0m,please check!"
fi
