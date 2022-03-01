#!/bin/bash


#Website Backup Script
HOSTNAME=`/bin/hostname`

#Todays date in ISO-8601 format:
DAY0=`date -I`

#Yesterdays date in ISO-8601 format:
DAY1=`date -I -d "1 day ago"`
DAY7=`date -I -d "6 days ago"`

#The source directory:
BKPDIR="/backups/sql/"

SRC="____ADD SERVER IP HERE_____"

SSHPORT='___ SSH PORT HERE ___'

if [[ $1 != '' ]]; then
  SRC=$1
fi

CURDATE=`date  +"%d-%m-%Y-%Hh%Mm"`

for server in $SRC; do
  if ( ! ssh -p $SSHPORT $server 'hostname' ); then
    curl -X POST --data-urlencode 'payload={"channel": "#alerts", "text": "FAIL to run backup sqls for '"$server"'"}' https://hooks.slack.com/services/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
    continue
  fi        
  #Delete the backup from 30 days ago, if it exists
  if [ -d $BKPDIR/$server/$DAY7 ]; then
    echo -e "Deleting backup from: $DAY7"
    sudo rm -rf $BKPDIR/$server/$DAY7
  fi

  TRG="$BKPDIR/$server/$DAY0"
  LNK="$BKPDIR/$server/$DAY1"
  DBS=`ssh -p $SSHPORT root@$server 'mysql -e "show databases"' | grep -vE 'Database|schema|sys'`

  if [ ! -d $TRG ]; then
   mkdir -p $TRG
  fi

  for db in $DBS; do
    echo -e "Dumping tables for DB $db"
    tables=$(ssh -p $SSHPORT root@$server "mysql $db -e 'show tables' | grep -v 'Tables\_in\_'")


    TABLETGR="$BKPDIR/$server/$DAY0/$db-$CURDATE"
    if [ ! -d $TABLETGR ]; then
        mkdir -p $TABLETGR
    fi

    for table in $tables; do
      echo -e "Dumping $db table $table to - $TABLETGR/$table-$CURDATE.bz2"
      ionice -c2 -n7 ssh -p $SSHPORT root@$server "mysqldump --events --quick --skip-lock-tables $db $table" | /usr/bin/gzip > $TABLETGR/$table.gz
    done

  done

done