# date : 2016-09-14
#
user='root'
passwd='calvin'
controller=`racadm -r $1 -u $user -p $passwd storage get controllers --nocertwarn | sed 's/\r/\n/g' | egrep "RAID"`
jobview=`racadm -r $1 -u $user -p $passwd jobqueue view --nocertwarn | sed -n '/---/,$p' | wc -l`

# delete jobqueue
function jobdel {
echo "$1: start jobqueue delete."
while [[ $jobview -ne 2 ]]; do
    racadm -r $1 -u $user -p $passwd jobqueue delete --all --nocertwarn &> /dev/null
    local jobview=`racadm -r $1 -u $user -p $passwd jobqueue view --nocertwarn | sed -n '/---/,$p' | wc -l`
done
echo "$1: jobqueue delete success."
}

function get_job_id {
# 如果LC禁用，则启用
if  echo $JOBTASK | egrep 'RAC1155' &> /dev/null; then
    echo -e "\e[0;31;1m$1: ERROR: RAC1155: Unable to complete the operation because Lifecycle Controller is disabled.\e[0m"
    echo "$1: start enable LC"
    racadm -r $1 -u $user -p $passwd set LifeCycleController.LCAttributes.LifecycleControllerState 1 || exit
elif echo $JOBTASK | egrep 'Commit JID' &> /dev/null; then
    JOBID=`echo $JOBTASK | awk '/Commit JID/ {print $4}' | sed 's/\r//'`
fi

racadm -r $1 -u $user -p $passwd serveraction powercycle --nocertwarn &> /dev/null
echo "$1: start jobqueue create time: `date +%Y/%m/%d-%H:%M:%S`,system rebooting,please wait 5min"
while true; do
local jobpcert=`racadm -r $1 -u $user -p $passwd jobqueue view --nocertwarn | egrep -A7 "$JOBID" | awk -F "=" '/Percent Complete/ {print $2}'`
if [ -z "$jobpcert" ]; then
    echo -e "\e[0;43;1m$1: jobqueue no task.\e[0m" 
    exit
elif echo $jobpcert | egrep '100' &> /dev/null; then
    break
fi
sleep 10
done
echo "$1: jobqueue create success."
}

function jobsub_bios {
local JOBTASK=`racadm -r $1 -u $user -p $passwd jobqueue create BIOS.Setup.1-1 --nocertwarn | egrep 'RAC1155|Commit JID'`
get_job_id $1
}

# job submit
function jobsub {
local JOBTASK=`racadm -r $1 -u $user -p $passwd jobqueue create $controller -s TIME_NOW -r forced --nocertwarn | egrep 'RAC1155|Commit JID'`
get_job_id $1
}

