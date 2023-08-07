#!/bin/bash
#
#       Copyrights Private Devops LTD. - https://privatedevops.com
#

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

SRC="127.0.0.1 127.0.0.2 127.0.0.3"

SSHPORT='5698'

if [[ $1 != '' ]]; then
        SRC=$1
fi

CURDATE=`date  +"%d-%m-%Y-%Hh%Mm"`

for server in $SRC; do
        #Delete the backup from 30 days ago, if it exists
        if [ -d $BKPDIR/$server/$DAY30 ]; then
                echo -e "Deleting backup from: $DAY30"
                sudo rm -rf $BKPDIR/$server/$DAY30
        fi
        ssh -p $SSHPORT root@$server "mysqlcheck -Ar"

        TRG="$BKPDIR/$server/$DAY0"
        LNK="$BKPDIR/$server/$DAY1"
        DBS=`ssh -p $SSHPORT root@$server 'mysql -e "show databases"' | grep -vE 'Database|schema'`
        if [ ! -d $TRG ]; then
                mkdir -p $TRG
        fi
        for db in $DBS; do
                echo -e "Starting SQL backups for db $db from server: $server"
                ionice -c2 -n7 ssh -p $SSHPORT root@$server "mysqldump --single-transaction --quick  --events $db" | /usr/bin/bzip2 > $TRG/$db-$CURDATE.bz2
        done


done
