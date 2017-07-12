#!/bin/bash

# Author: stanislav@bgcode.com
# https://hostingidol.com

base_dir='/root/scripts/megaclicheck'
shortname="raid_checker"
now=`date "+%d-%h-%Y %H:%M %Z"`
logdir="/var/log/"
log="$logdir/$shortname.log"

BEEP="\x07"
ESC="\x1b["
RED=$ESC"31;01m"
GREEN=$ESC"32;01m"
YELLOW=$ESC"33;01m"
DBLUE=$ESC"34;01m"
MAGENTA=$ESC"35;01m"
BLUE=$ESC"36;01m"
WHITE=$ESC"37;01m"
GREY=$ESC"30;01m"
RESET=$ESC"39;49;00m"

MEGACLI='/opt/MegaRAID/MegaCli/MegaCli64'
MAILTO='mail@domain.com'
SLACKHOOKURL='https://hooks.slack.com/....'
AWKFILE="$base_dir/megacli.awk"
HOSTNAME=$(/bin/hostname)

check=$($MEGACLI -CfgDsply -aALL -nolog |grep -E 'State.*\ :' | grep -v Optimal);
arrayoutput=$($MEGACLI -PdList -aALL | awk -f $AWKFILE)


function log_me {
	echo -e "$GREEN[$WHITE+$GREEN]$DBLUE INFO:$BLUE $@$RESET"
	echo -e "[$now] INFO: $@" >> $log
}

function fatal_error {
	echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
	echo -e "[$now] FATAL ERROR: $@" >> $log
	echo -e "$arrayoutput" | mail -s "$HOSTNAME array issues" $MAILTO
	echo -e "The problem has been reported to: $MAILTO\n"
	curl -s -X POST --data-urlencode 'payload={"channel": "#alerts", "text": "RAID Array issue '"$HOSTNAME"':  '"\n$arrayoutput"' "}' $SLACKHOOKURL >> /dev/null
	exit 1;
}



#log_me "Checking RAID Arrays"
if [ ! -z "$check" ]; then
	fatal_error "RAID ARRAY ERRORS FOUND\n $arrayoutput"
fi
