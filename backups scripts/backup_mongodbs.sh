#!/bin/bash


#Website Backup Script
HOSTNAME=`/bin/hostname`

#how old copys to keep
days=30

#Todays date in ISO-8601 format:
DAY0=`date -I`

#Yesterdays date in ISO-8601 format:
DAY1=`date -I -d "1 day ago"`
DELFROM=`date -I -d "$days days ago"`

#The source directory:
BKPDIR="/backups/mongodumps/"


SRC="127.0.0.1 10.0.0.1 10.0.0.2"

if [[ $1 != '' ]]; then
	SRC=$1
fi

CURDATE=`date  +"%d-%m-%Y-%Hh%Mm"`

MONGOUSER=
MONGOPASS=


for server in $SRC; do
        #Delete the backup from $days days ago, if it exists
        if [ -d $BKPDIR/$server/$DELFROM ]; then
                echo -e "Deleting backup from: $DELFROM"
                sudo rm -rf $BKPDIR/$server/$DELFROM
        fi
	
	TRG="$BKPDIR/$server/$DAY0"
	LNK="$BKPDIR/$server/$DAY1"
	if [ ! -d $TRG ]; then
	        mkdir -p $TRG
	fi
	echo -e "Starting Mongo backups from server: $server"
	mongodump --host $server --username $MONGOUSER --password $MONGOPASS  --gzip -o $TRG

        
done
