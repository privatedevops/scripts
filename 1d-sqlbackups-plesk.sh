#!/bin/bash

MYSQL_PWD=`cat /etc/psa/.psa.shadow`
EXCLUDE="'Database|Database|information\_schema|performance\_schema|Database'"
DESTINATION=/root/sql/
CURDATE=`date  +"%d-%m-%Y-%Hh%Mm"`


if [ ! -d $DESTINATION ]; then
	mkdir $DESTINATION
fi

for db in `mysql -u admin -p$MYSQL_PWD -e 'show databases' | grep -Ev "$EXCLUDE"`; do 
	echo -e "Dumping MySQL DB: $db"
	mysqldump --single-transaction=TRUE --skip-add-locks -u admin -p$MYSQL_PWD --events $db | gzip > $DESTINATION/$db.$CURDATE.sql.gz
done

#keep only last 24 hours backups
find $DESTINATION -type f -mtime +1 -exec rm -f {} \;
