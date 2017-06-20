#!/bin/bash
# avoid default passwd change warning message
#
user='root'
passwd='calvin'

source /data/script/phy_manage/idrac/bin/modules_job.sh

if racadm -r $1 -u $user -p $passwd set iDRAC.Tuning.DefaultCredentialWarning Disabled &> /dev/null; then
	echo "$1: idrac default credential warning messages disbaled success"
else
	echo -e "[0;31;1m$1: idrac default credential warning messages disbaled failed"
fi

jobdel $1 
jobsub $1
