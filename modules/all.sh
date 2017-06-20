#!/bin/bash
#
cd /data/script/idrac/modules/
sh modules_DelVds.sh $1 all
sh modules_DiskModeConvert.sh $1 $2
sh modules_CreateRaid.sh $1 $3
sh modules_SetBios.sh $1
