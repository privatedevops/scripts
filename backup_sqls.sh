#!/bin/bash


#Website Backup Script
HOSTNAME=`/bin/hostname`

#Todays date in ISO-8601 format:
DAY0=`date -I`

#Yesterdays date in ISO-8601 format:
DAY1=`date -I -d "1 day ago"`
DAY30=`date -I -d "30 days ago"`

#The source directory:
BKPDIR="/backups/sqls/"
SKIPFILES="/root/scripts/bkp_excludes.list"
SRC="IP/HOST"
SSHPORT='SSH PORT'

CURDATE=`date  +"%d-%m-%Y-%Hh%Mm"`


#Delete the backup from 30 days ago, if it exists
if [ -d $BKPDIR/$server/$DAY30 ]; then
	echo -e "Deleting backup from: $DAY30"
	sudo rm -rf $BKPDIR/$server/$DAY30
fi
for server in $SRC; do

        ssh -p $SSHPORT root@$server "mysqlcheck -Ar"

	TRG="$BKPDIR/$server/$DAY0"
	LNK="$BKPDIR/$server/$DAY1"
	DBS=`ssh -p $SSHPORT root@$server 'mysql -e "show databases"' | grep -vE 'Database|schema'`	
	if [ ! -d $TRG ]; then
	        mkdir -p $TRG
	fi
	for db in $DBS; do
		echo -e "Starting SQL backups for db $db from server: $server"
	        ionice -c2 -n7 ssh -p $SSHPORT root@$server "mysqldump --events --skip-lock-tables $db" | /usr/bin/bzip2 > $TRG/$db-$CURDATE.bz2
	done

        ssh -p $SSHPORT root@$server "mysqlcheck -Ar"
done
