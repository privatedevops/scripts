#!/bin/bash
 
#Website Backup Script
HOSTNAME=`/bin/hostname`


#Todays date in ISO-8601 format:
DAY0=`date -I`
 
#Yesterdays date in ISO-8601 format:
DAY1=`date -I -d "1 day ago"`
DAY7=`date -I -d "7 days ago"`
 
#The source directory:
BKPDIR="/backups/files/"
SKIPFILES="/root/scripts/bkp_excludes.list"
SRC="bin etc home lib lib64 root sbin var usr"

if ( ! mount | grep -q sdb ); then
	echo "ERROR BKP: mount not found"
	echo "ERROR BKP: mount not found" | mail -s "$HOSTNAME backups issue" sanek@slacklinux.net
	exit 1;
fi


TRG="$BKPDIR/$DAY0"
LNK="$BKPDIR/$DAY1"
OPT="-aH --delete --exclude-from=$SKIPFILES --link-dest=$LNK"

if [ ! -d $TRG ]; then
	mkdir -p $TRG
fi

for dir in $SRC; do
	echo -e "Syncing: $dir"
	ionice -c2 -n7 rsync $OPT /$dir/ $TRG/$dir/
done

#Delete the backup from 7 days ago, if it exists
if [ -d $BKPDIR/$DAY7 ]; then
	echo -e "Deleting backup from: $DAY7"
	sudo rm -rf $BKPDIR/$DAY7
fi
