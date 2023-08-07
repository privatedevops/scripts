#!/bin/bash
#
#       Copyrights Private Devops LTD. - https://privatedevops.com
#

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



backupbucket=pms1backup
BFOLDERS="bin etc home lib lib64 root sbin usr var"
THISYEAR=`date +"%Y"`
LASTBKP=`ls -1At /mnt/s3-backups/ | grep $THISYEAR |  head -n1`

base_dir=`pwd`
now=`date "+%d-%h-%Y %H:%M %Z"`
logdir="$base_dir"
shortname=s3-backupserver
log="$logdir/$shortname.log"


#Todays date in ISO-8601 format:
DAY0=`date -I`
 
#Yesterdays date in ISO-8601 format:
DAY1=`date -I -d "1 day ago"`
DAY15=`date -I -d "15 days ago"`
 
#The source directory:
BKPDIR="/mnt/s3-backups/"
SKIPFILES="/root/scripts/bkp_excludes.list"
SRC="/home/"
vm=$SRC

function log_me {
	echo -e "$GREEN[$WHITE+$GREEN]$DBLUE INFO:$BLUE $@$RESET"
	echo -e "[$now] INFO: $@" >> $log
}

function fatal_error {
	echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
	echo -e "[$now] FATAL ERROR: $@" >> $log
	tail -n 50 $log | mail -s "XML update for $shortname error on $host" sanek@slacklinux.net
	echo -e "The error has been reported to: sanek@slacklinux.net\n"
	exit 1;
}

log_me "Running ldconfig"
ldconfig

log_me "Cheking for fuse module loaded"
if ( ! lsmod | grep -q fuse ); then
	log_me "WARRNIG: fuse module not loadded, loading it."
	if (! /sbin/modprobe fuse ); then
		fatal_error "ERROR: Unable to laod fuse module"
	fi
fi
log_me "Cheking for backup s3 mount"
if ( ! mount | grep -q s3-backups ); then
	log_me "Mount not found, creating the mount."
	if ( ! /usr/local/bin/s3fs -o passwd_file=/etc/passwd-s3fs  -o use_cache=/tmp/cache $backupbucket /mnt/s3-backups/ ); then
		fatal_error "ERROR: Unable to mount s3 bucket $backupbucket to /mnt/s3-backups folder."
	fi
fi

TRG="$BKPDIR/$DAY0"
LNK="$BKPDIR/$DAY1"
#OPT="-avHP --delete --exclude-from=$SKIPFILES --link-dest=$LNK"
#OPT="-avHP --delete --exclude-from=$SKIPFILES"
#ionice -c2 -n7 nice -n19 rsync $OPT $SRC $TRG


mkdir $TRG


for dir in $BFOLDERS ; do
	log_me "Syncing $dir to s3://$backupbucket/$DAY0/$dir"
	ionice -c2 -n7 nice -n19  /usr/bin/aws s3 sync --delete /$dir/ s3://$backupbucket/$DAY0/$dir/ >> /dev/null
done

#keep only last 35 days backups
for oldbackup in `aws s3 ls  s3://$backupbucket/ | awk '{print $2}' | grep '-' | head -n -2` ; do
        #rm -rf /mnt/s3-backups/$oldbackup
        aws s3 rm --recursive s3://$backupbucket/$oldbackup
done
