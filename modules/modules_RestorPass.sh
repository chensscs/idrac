#!/bin/bash
# chenss
# date : 2016-09-09
#
defuser='root'
defpawd='calvin'
user='JPush'
pawd='JPsh3!2&'

function chpawd {
racadm -r $1 -u $user -p $pawd set idrac.users.2.password $defpawd &> /dev/null
}

chpawd $1

if racadm -r $1 -u $defuser -p $defpawd get BIOS.SysInformation.SystemServiceTag &> /dev/null; then
    echo -e "$1:\t Through insection,The root user password recovery default \e[0;32;1msuccessfully\e[0m!"
else
    echo -e "$1:\t Through insection,The root user password recovery \e[40;31;5mfailedr\e[0m,please retry again!"
fi
