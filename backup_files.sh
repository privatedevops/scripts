#!/bin/bash

#Website Backup Script
HOSTNAME=`/bin/hostname`

#how old copys to keep
days=6

#Todays date in ISO-8601 format:
DAY0=`date -I`

#Yesterdays date in ISO-8601 format:
DAY1=`date -I -d "1 day ago"`
DELFROM=`date -I -d "$days days ago"`

#The source directory:
BKPDIR="/backups/files/"
SKIPFILES="/root/scripts/bkp_excludes.list"
SRC="IP ADDRESS HERE"
SSHPORT='SSH PORT HERE'


echo "Deleting: $BKPDIR/$SRC/$DELFROM"
if [ -d $BKPDIR/$SRC/$DAY14 ]; then
	echo -e "Deleting backup from: $DELFROM"
	rm -rf $BKPDIR/$SRC/$DELFROM
fi
#exit
for server in $SRC; do
	TRG="$BKPDIR/$server/$DAY0"
	LNK="$BKPDIR/$server/$DAY1"
	OPT="-avh --delete --sparse  --exclude-from=$SKIPFILES --link-dest=$LNK"
	
	if [ ! -d $TRG ]; then
	        mkdir -p $TRG
	fi
    
	echo -e "Starting backups for server: $server"
        ionice -c2 -n7 rsync -e "ssh -p $SSHPORT" $OPT $server:/ $TRG
done
