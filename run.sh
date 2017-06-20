#!/bin/bash
# chenss
# date : 2016-09-10

PATH="/opt/dell/srvadmin/bin/:/opt/dell/srvadmin/sbin/:$PATH"
if [ $# -gt 0 ]; then
     echo -e "\e[0;31;1mCorrect syntax: sh run.sh\e[0m"
     exit
fi

start=`date +%s`
NicGetMac='/data/script/idrac/modules/modules_GetNicMac.sh'
CreateRaid='/data/script/idrac/modules/modules/modules_CreateRaid.sh'
AddUser='/data/script/idrac/modules/modules_AddUser.sh'
Check='/data/script/idrac/modules/modules/modules_SetBios.sh'
delvd='/data/script/idrac/modules/modules/modules_DelVds.sh'
disk_convert='/data/script/idrac/modules/modules/modules_DiskModeConvert.sh'
defpass='/data/script/idrac/modules/modules_RestorPass.sh'
reboot='/data/script/idrac/modules/modules/modules_SysReboot.sh'
pxe='/data/script/idrac/modules/bootseq.sh'
idrac_file='/data/script/idrac/hosts'
all='/data/script/idrac/modules/all.sh'

cat << EOF 
########## please option your choice: [1-10] ############
(1)  Get server NIC mac-address
(2)  Remove all or the virtual disk other than the system disk
(3)  Physical Disk mode convert
(4)  Create raid1 or raid5
(5)  Add idrac user (JPush) and change root passwd
(6)  Bios disable F1/F2 errot prompt and setup HDD first boot
(7)  check system boot seq
(8)  Restore the root default password
(9)  reboot system
(10) New server raid、bios init
(99) Execute the command manually
(*) exit script
########################################################
EOF

read -p "please option your choice: " choice
case $choice in
1)script="$NicGetMac";;
2)read -p "This operation will remove virtual disk,Are you sure? [Y|N]" confirm
if [ "$confirm" == "Y" -o "$confirm" == "y" ]; then
    script="$delvd"
    read -p "Romve all or no system virtual disk? [all|nosys]" rmvd
    if [ "$rmvd" != "all" -a "$rmvd" != "nosys" ]; then
         echo -e "\e[0;31;1m: argu error,you can only enter 'all' or 'nosys',please enter again\e[0m"
         exit
    fi
else
    echo -e "\e[0;31;1mYou can only enter 'Y' or 'N',please enter again\e[0m"
    exit
fi;;
3)read -p "This operation will convert disk mode,May be erase disk data,Are you sure? [Y|N]" confirm
if [ "$confirm" == "Y" -o "$confirm" == "y" ]; then
    script="$disk_convert"
else
    echo -e "\e[0;31;1mYou can only enter 'Y' or 'N',please enter again\e[0m"
    exit
fi;;
4)read -p "This operation will create raid,May be erase disk data,Are you sure? [Y|N]" confirm
if [ "$confirm" == "Y" -o "$confirm" == "y" ]; then
    script="$CreateRaid"
else
    echo -e "\e[0;31;1mYou can only enter 'Y' or 'N',please enter again\e[0m"
    exit
fi;; 
5)script="$AddUser";;
6)script="$Check";;
7)script="$pxe";;
8)script="$defpass";;
9)read -p "This operation will reboot system,Are you sure? [Y|N]" confirm
if [ "$confirm" == "Y" -o "$confirm" == "y" ]; then
    script="$reboot"
fi;;
10)read -p "This operation will remove virtual disk,Are you sure? [Y|N]" confirm
if [ "$confirm" == "Y" -o "$confirm" == "y" ]; then
    script="$all"
else
    echo -e "\e[0;31;1mYou can only enter 'Y' or 'N',please enter again\e[0m"
    exit
fi;;
99)read -p "please input command: " a b c d e f g;;
*)echo -e "\e[0;31;1margu error,please check...\e[0m"
exit;;
esac

if egrep -v '^#|^$|^NIC|^RAID' $idrac_file | grep '[^[:digit:]].*-' &> /dev/null; then
    menu_ipseq='1'
else
    menu_ipseq='2'
fi

function ShExec {
	NUM=`grep '^NIC' $idrac_file | awk '{print $2}'`
	mode=`egrep '^mode' $idrac_file | awk '{print $2}'`
	raid_level=`egrep '^RAID' $idrac_file | awk '{print $2}'`
	if [ -n "$a" ]; then
	    racadm -r $idrac_ip -u root -p calvin $a $b $c $d $e $f $g --nocertwarn  | egrep -v -B 9 'Default username'
        elif [ "`basename $script`" == "modules_GetNicMac.sh" ]; then
            sh $script $idrac_ip $NUM
        elif [ "`basename $script`" == "modules_DelVds.sh" ];  then
            sh $script $idrac_ip $rmvd
        elif [ "`basename $script`" == "modules_DiskModeConvert.sh" ];  then
            sh $script $idrac_ip $mode
        elif [ "`basename $script`" == "all.sh" ]; then
            sh $script $idrac_ip $mode $raid_level
        else
            sh $script $idrac_ip $raid_level
        fi
}

function SEQ {
egrep -v '^#|^$' $idrac_file | grep '[^[:digit:]].*-' | while read idracs; do
    prefix=`echo $idracs | awk -F '[.-]' '{print $1"."$2"."$3}'`
    begin=`echo $idracs | awk -F '[.-]' '{print $4}'`
    end=`echo $idracs | awk -F '[.-]' '{print $5}'`
    for i in `seq ${begin} ${end}`; do
        {   
        idrac_ip=${prefix}.$i
        ShExec
        }&  
    done
    wait
done
}

function NOSEQ {
egrep -v '^#|^;|^$' $idrac_file | grep '^[[:digit:]].*$' | while read idracs; do
    {   
    idrac_ip=`echo $idracs | awk '{print $1}'`
    ShExec
    }&  
wait
done
}

case $menu_ipseq in
1) SEQ;;
2) NOSEQ;;
*) echo "usage: error,please check script!"
esac

over=`date +%s`
echo "used time : `expr $over - ${start}`s"
