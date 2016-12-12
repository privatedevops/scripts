#!/bin/bash 


#how to fix slave
#MASTER
#use $database;
#FLUSH TABLES WITH READ LOCK;
#mysqldump -u root  --opt $database > $database
#scp $database $slaveip:
#ssh $slaveip 'mysql $database < /root/$database'
#mysql -e 'show master status'
#GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY 'Jash1237AguwfdjsahSA23AJSd';

#SLAVE:
#mysql> CHANGE MASTER TO MASTER_HOST='$slaveip',MASTER_USER='slave_user', MASTER_PASSWORD='Jash1237AguwfdjsahSA23AJSd', MASTER_LOG_FILE='mysql-bin.000019', MASTER_LOG_POS=25389373;

#MASTER
#UNLOCK TABLES;

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

base_dir='/root/scripts/'
shortname="mysql_replica"
host=`hostname`

now=`date "+%d-%h-%Y %H:%M %Z"`
logdir="$base_dir/logs"
log="$logdir/$shortname.log"

broken=0

slaveip="195.154.200.167"
slavedb='cloudapi_db'
RSSHPORT='5698'

replicauser='slave_user'
replicapass='Jash1237AguwfdjsahSA23AJSd'

masterip='163.172.70.21'

database='cloudapi_db'
tables='withdraw_orders topup_orders exchange_transactions socialprofiles payment_systems payment_systems_requests payment_systems_templates'



function log_me {
	echo -e "$GREEN[$WHITE+$GREEN]$DBLUE INFO:$BLUE $@$RESET"
	echo -e "[$now] INFO: $@" >> $log
}

function fatal_error {
	echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
	echo -e "[$now] REPLICATION ERROR: $@" >> $log
	tail -n 10 $log | mail -s "MySQL Replication between Master: $host and Slave: $slaveip not OK, please FIX manually" sanek@slacklinux.net
	tail -n 10 $log | mail -s "MySQL Replication between Master: $host and Slave: $slaveip not OK, please FIX manually" grim6681@gmail.com
	echo -e "The error has been reported to: stanislav@bgcode.com\n"
	mysql $database -e "UNLOCK TABLES;"
	exit 1;
}

log_me "get remote slave status"
slavestatus=`ssh -p $RSSHPORT  $slaveip 'mysql -e "show slave status \G"'`

log_me "get master bing log info"
masterbinlog=`mysql -e 'show master status' | grep mysql-bin | awk '{print $1}'`

log_me "get remote slavebinlog info via ssh"
slavebinlog=`ssh -p $RSSHPORT $slaveip 'mysql -e "show slave status \G"' | grep Relay_Master_Log_File | awk '{print $2}'`

log_me "Checking for logging folder"
if [ ! -d $logdir ]; then
	mkdir -p $logdir
fi
log_me "Checking slave events"
if ( !  echo -en $slavestatus | grep -q  'Waiting for master to send event'  ); then
	log_me "Slave is not waiting for updates from master"
	broken=1
fi

log_me "Checking slave if it is ready for relay"
if ( !  echo -en $slavestatus | grep -q  'Slave has read all relay log; waiting for the slave I/O thread to update it' ); then
	log_me "Slave is not ready to relay log"
fi
log_me "Checking bin logs"
if [[ $masterbinlog == $slavebinlog ]]; then
	log_me "Replication OK"
else
	log_me "Replication Broken"
	broken=1
fi
if [[ $1 == "--force" ]]; then
	broken=1
fi
if [[ $broken == 1 ]]; then
	tail -n 10 $log | mail -s "MySQL Replication between Master: $host and Slave: $slaveip not OK, trying repair." sanek@slacklinux.net
	log_me "Trying to repair replication"
	log_me "Locking $database tables"
	if ( ! mysql $database -e 'FLUSH TABLES WITH READ LOCK;' ); then
		fatal_error "Unable to lock $database's tables"
	fi
	log_me "Checking if sqldump's folder exist"
	if [ ! -d /root/sqls ]; then
		log_me "/root/sql not found, creating it"
		mkdir -p /root/sqls
	fi
	log_me "Dumping tables from $database"
	for table in $tables ; do
	log_me "Dumping $table to $masterip on /root/sqls folder"
		if ( ! mysqldump $database $table >  /root/sqls/$table ); then
			fatal_error "Unable to dump on master - $masterup - table sqltable $database.$table to /root/sqls/$table"
		fi
	done
	log_me "Uploading $database's dump to Slave server via scp"
	if ( ! scp -P $RSSHPORT -r /root/sqls $slaveip: >> /dev/null); then
		fatal_error "Unable to upload /root/sqls dumps to Slave via scp"
	fi
        log_me "Disabling broken slave cluster"
        if ( ! ssh -p $RSSHPORT root@"$slaveip" 'mysql -e "STOP SLAVE"'); then
                fatal_error "Unable to stop slave cluster"
        fi
        log_me "Reseting old slave clustering"
        if ( ! ssh -p $RSSHPORT root@"$slaveip" 'mysql -e "RESET SLAVE"'); then
                fatal_error "Unable to reset slave cluster"
        fi
	for table in $tables ; do
	log_me "Dropping $table from $slavedb on $slaveip"
		if ( ! ssh -p $RSSHPORT root@"$slaveip" "mysql $slavedb -e '"DROP TABLE IF EXISTS $table"'" ); then
			fatal_error "Unable to drop table $table on slave - $slaveip"
		else
			log_me "Table $slavedb.$table on slave dropped"
		fi
	done    
	log_me "Import on slave for db/tables started"
	for table in $tables ; do
	log_me "Importing $table to $slavedb on $slaveip"
		if ( ! ssh -p $RSSHPORT root@"$slaveip" "mysql $slavedb < /root/sqls/$table" ); then
			fatal_error "Unable to import table $table to $slavedb on slave - $slaveip"
		fi
	done
	log_me "Sort local grants for replication's user on master"
	if ( ! mysql -e "GRANT REPLICATION SLAVE ON *.* TO '"$replicauser"'@'%' IDENTIFIED BY '"$replicapass"'" ); then
		fatal_error "Unable to set grant slave user on master server"
	else
		mysql -e 'flush privileges'
	fi
	
	#gen some vars again
	position=`mysql -e 'show master status' -ss | awk '{print $2}'`
	binfile=`mysql -e 'show master status' -ss | awk '{print $1}'`
	query="CHANGE MASTER TO MASTER_HOST='"$masterip"', MASTER_USER='$replicauser', MASTER_PASSWORD='"$replicapass"', MASTER_LOG_FILE='"$binfile"', MASTER_LOG_POS=$position"
	sql=`echo -e "$query"`

	if ( ! echo -e $sql > /root/grant.sql ); then
		fatal_error "Unable to create on master - $masterip /root/grant.sql"
	fi
	log_me "Uploading /root//grant.sql from master to slave"
	if ( ! scp -P $RSSHPORT /root/grant.sql root@"$slaveip":/root/ >> /dev/null ); then
		fatal_error "Unable to upload /root/grant.sql to slave - $slaveip"
	fi
	log_me "Addin new master to slave server"
	if ( ! ssh -p $RSSHPORT root@"$slaveip" "mysql -e 'source /root/grant.sql'" ); then
		log_me "UNlocking master"
		if ( ! mysql $database -e "UNLOCK TABLES;" ); then
			fatal_error "Unable to unlock tables"
		fi
			fatal_error "Unable to change master on slave host - $slaveip"
	else
		log_me "Deleting from $slaveip /root/grant.sql"
		if ( ! ssh -p $RSSHPORT root@"$slaveip" "rm -f /root/grant.sql" ); then
			fatal_error "Unable to delete /root/grant.sql on - $slaveip ++++++++++++ PLEASE DELETE IT MANUALY ++++++++++++++"
		fi
		if ( !  rm -f /root/grants.sql ); then
			fatal_error "Unable to delete /root/grants.sql on  master - $masterip"
		fi
	fi
	log_me "Starting the cluster"
	if ( ! ssh -p $RSSHPORT root@"$slaveip" 'mysql -e "start slave"' ); then
		fatal_error "Starting slave replication"
	fi
	log_me "Unlock master tables"
	if ( ! mysql $database -e "UNLOCK TABLES;" ); then
		fatal_error "Unable to unlock tables"
	else
		log_me "MySQL Cluster recovered."
	fi
fi
