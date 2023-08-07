#!/bin/bash
#
# Backup a Postgresql database into a daily file.
#
#
#       Copyrights Private Devops LTD. - https://privatedevops.com
#

BACKUP_DIR=/root/pgsql
DAYS_TO_KEEP=14

PASSWORD=''
USER=postgres


HOST=''

DBS=$(PGPASSWORD=${PASSWORD} psql -w -h ${HOST} -U postgres -lAt | gawk -F\| '$1 !~ /^template/ && $1 !~ /^postgres/ && NF > 1 {print $1}')


for DATABASE in $DBS
do
	echo -e "Backuping: ${DATABASE}"
	FILE_SUFFIX=_${DATABASE}.sql
	FILE=`date +"%Y%m%d%H%M%S"`${FILE_SUFFIX}

	OUTPUT_FILE=${BACKUP_DIR}/${FILE}


	if [ ! -d $BACKUP_DIR ]; then
		mkdir -p $BACKUP_DIR
	fi

	# do the database backup (dump)
	# use this command for a database server on localhost. add other options if need be.
	PGPASSWORD=${PASSWORD} pg_dump -h ${HOST} -U ${USER} ${DATABASE} -F p -f ${OUTPUT_FILE}

	# gzip the mysql database dump file
	gzip $OUTPUT_FILE

	# DEBUG show the user the result
	#echo "${OUTPUT_FILE}.gz was created:"
	#ls -l ${OUTPUT_FILE}.gz

	# prune old backups
	find $BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP -name "*${FILE_SUFFIX}.gz" -exec rm -rf '{}' ';'
done
