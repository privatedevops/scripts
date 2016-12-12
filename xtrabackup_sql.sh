#!/bin/bash
#
# Usage: sqlbackup.sh [ backup/backup cron; restore/restore replaceall ]
#
# xtrabckups.sh backup
# xtrabckups.sh backup cron
#
# xtrabckups.sh list 
#
# xtrabckups.sh restore backuppoint_from_list
# xtrabckups.sh restore backuppoint_from_list replaceall
#
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

base_dir=/root/scripts/
shortname="xtrabackups"

host=`/bin/hostname`
now=`date "+%d-%h-%Y %H:%M %Z"`

logdir="$base_dir/logs"
log="$logdir/$shortname.log"

BKPMUSR='backup user here'
BKPMPASS='backup user pass here'
BKPDEST="/backups/sqlbackups/"
BKPSLIST=`ls -1A $BKPDEST | grep -v restores`
BKPCOUNT=`ls -1A $BKPDEST| wc -l`
MAXBACKUPSWEKEEP=5

function log_me {
	echo -e "$GREEN[$WHITE+$GREEN]$DBLUE INFO:$BLUE $@$RESET"
	echo -e "[$now] INFO: $@" >> $log
}

function fatal_error {
	echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
	echo -e "[$now] FATAL ERROR: $@" >> $log
	tail -n 50 $log | mail -s "Backups failed for $shortname on $host" sanek@slacklinux.net
	echo -e "The error has been reported to: sanek@slacklinux.net\n"
	exit 1;
}

# Gotta be root.
if [ $UID -ne 0 ]; then 
	echo "Run this as root"
	exit
fi

if [ ! -d $BKPDEST ]; then
	log_me "Backups destination dir not found, creating $BKPDEST"
	mkdir -p $BKPDEST
fi
if [ ! -d $logdir ]; then
	log_me "Log dir not found, creating $logdir"
	mkdir -p $logdir
fi

if [[ $1 == "backup" ]]; then
	log_me "Starting full MySQL backup creation"
	if ( ! /usr/bin/innobackupex --backup --user=$BKPMUSR --password=$BKPMPASS --compress --compress-threads=10  --parallel=10 --no-lock $BKPDEST > /dev/null 2>&1 ); then
		fatal_error "ERROR: Xtrabackup not finished"
	fi
	if [[ $2 == "cron" ]]; then
		log_me "Checking for older than $MAXBACKUPSWEKEEP days backups from $BKPDEST"	
		if [ $BKPCOUNT -gt $MAXBACKUPSWEKEEP ]; then
			log_me "Deleting old backups"
			if ( ! find /backups/sqlbackups/ -maxdepth 1 -type d -mtime $MAXBACKUPSWEKEEP -exec rm -rf "{}" \; ); then
				fatal_error "ERROR: Unable to clean old backups"
			fi
		fi
	fi
	log_me "Backup done, you can run "$0 list" to list all Xtrabackups"
	
fi

if [[ $1 == "list" ]]; then
	log_me "List with all backups/restorepoints:"
	echo -e "$BKPSLIST"
	exit 1;
fi

if [[ $1 == "restore" ]]; then
	RESTOREPOINT=$2
	RESTORETMP="$BKPDEST/restores/"
	log_me "Starting SQL backup restore for backup: $RESTOREPOINT"
	log_me "Syncing a copy of the backup to $BKPDEST/restores/"
	if [ ! -d $RESTORETMP ]; then
		log_me "Creating $RESTORETMP"
		mkdir -p $RESTORETMP
	fi
	log_me "Start syncing a copy of $RESTOREPOINT to $RESTORETMP .."
	if ( ! /usr/bin/rsync -aH  $BKPDEST/$RESTOREPOINT/  $RESTORETMP/$RESTOREPOINT/ > /dev/null 2>&1 ); then
		fatal_error "ERROR: Unable to sync a copy of $RESTOREPOINT to $RESTORETMP"
	fi
	log_me "Decompresing files..."
	if ( ! /usr/bin/innobackupex --decompress $RESTORETMP/$RESTOREPOINT/ > /dev/null 2>&1 ); then
		fatal_error "ERROR: Unable to decompress Xtrabckup $RESTOREPOINT"
	fi
	log_me "Set Apply Log"
	if ( ! /usr/bin/innobackupex --apply-log $RESTORETMP/$RESTOREPOINT/  > /dev/null 2>&1 ); then
		fatal_error "ERROR: Unable to set apply-log to $RESTORETMP/$RESTOREPOINT/"
	fi
	log_me "Removing old compressed files"
	if ( !  $RESTORETMP/$RESTOREPOINT/ -iname "*\.qp" -exec rm -f {} \; > /dev/null 2>&1 ); then
		fatal_error "ERROR: Unable to remove old .qp compressed files"
	fi
	if [[ $3 == "replaceall" ]]; then
		log_me "You choose full mysql restore, that will overwrite all current mysql databases with databases from backup $RESTOREPOINT"
		echo -n "Is this ok, do you want to to continue with full restore ? (y/n) "
		read yesno < /dev/tty
		if [ "x$yesno" = "xy" ]; then
			log_me "Continue with full restore"
			mv /var/lib/mysql /var/lib/mysql-R
			#mkdir /var/lib/mysql
			if ( ! /usr/bin/innobackupex --copy-back $RESTORETMP/$RESTOREPOINT/ > /dev/null 2>&1 ); then
				fatal_error "ERROR: Full MySQL restore from backup $RESTOREPOINT failed."
			else
				chown -R mysql:mysql /var/lib/mysql
				log_me "Restore completed successful"
				exit 1;
			fi
		else
		    log_me "Restore Cancelled!"
		    log_me "Removing $RESTORETMP/$RESTOREPOINT/"
		    if ( ! rm -rf $RESTORETMP/$RESTOREPOINT > /dev/null 2>&1 ); then
				fatal_error "ERROR: Unable to delete folder $RESTORETMP/$RESTOREPOINT"
			fi
			fatal_error "Operation aborted."
		fi
	fi
	log_me "Starting 2nd MySQL instance on port 3307"
	log_me "Initialize MySQL datadir - $RESTORETMP/$RESTOREPOINT/"
	if ( ! /usr/bin/mysql_install_db --basedir=/usr --datadir=$RESTORETMP/$RESTOREPOINT  > /dev/null 2>&1 ); then
		fatal_error "ERROR: Unable to initialize MySQL datadir"
	else
		mysqld --basedir=/usr --datadir=$RESTORETMP/$RESTOREPOINT -P 3307 &
		log_me "Please use mysql port 3307 to connect to new mysql server with backuped databases, also for mysqldump use port 3307."
		log_me "Please when finish with the restore kill 3307 mysql server and remove - rm -rf $RESTORETMP/$RESTOREPOINT folder."
		exit 1;
	fi
fi

exit 0;
