#!/bin/bash 


#how to fix slave
#MASTER
#use wtcapi;
#FLUSH TABLES WITH READ LOCK;
#mysqldump -u root  --opt wtcapi > wtcapi
#scp wtcapi 185.4.73.138:
#ssh 185.4.73.138 'mysql wtcapi < /root/wtcapi'
#mysql -e 'show master status'
#GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY 'asdHJ2312';

#SLAVE:
#mysql> CHANGE MASTER TO MASTER_HOST='195.154.200.167',MASTER_USER='slave_user', MASTER_PASSWORD='asdHJ2312', MASTER_LOG_FILE='mysql-bin.000019', MASTER_LOG_POS=25389373;

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

slaveip="185.4.73.138"
slavestatus=`ssh $slaveip 'mysql -e "show slave status \G"'`

masterbinlog=`mysql -e 'show master status' | grep mysql-bin | awk '{print $1}'`
slavebinlog=`ssh $slaveip 'mysql -e "show slave status \G"' | grep Relay_Master_Log_File | awk '{print $2}'`

function log_me {
	echo -e "$GREEN[$WHITE+$GREEN]$DBLUE INFO:$BLUE $@$RESET"
	echo -e "[$now] INFO: $@" >> $log
}

function fatal_error {
	echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
	echo -e "[$now] REPLICATION ERROR: $@" >> $log
	tail -n 10 $log | mail -s "MySQL Replication between Master: $host and Slave: $slaveip not OK, trying repair." sanek@slacklinux.net
	echo -e "The error has been reported to: stanislav@bgcode.com\n"
	exit 1;
}

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

if [[ $broken == 1 ]]; then
	log_me "Trying to repair replication"
	log_me "Locking wtcapi tables"
	if ( ! mysql wtcapi -e 'FLUSH TABLES WITH READ LOCK;' ); then
		fatal_error "Unable to lock wtcapi's tables"
	fi
	log_me "MySQLDump wtcapi DB"
	if ( ! mysqldump -u root  --opt wtcapi > /root/wtcapi.sql ); then
		fatal_error "Unable to mysql dump wtcapi from master"
	fi
	log_me "Uploading wtcapi's dump to Slave server via ssh"
	if ( ! scp /root/wtcapi.sql 185.4.73.138:/root/ >> /dev/null); then
		fatal_error "Unable to upload /root/wtcapi.sql to Slave via ssh"
	fi
	log_me "Importing the wtcapi dump to slave's DB wtcapi"
	if ( ! ssh 185.4.73.138 'mysql wtcapi < /root/wtcapi.sql' ); then
		fatal_error "Unable to restore dump for wtcapi from master to slave server"
	fi
	log_me "Sort local grants for replication's user on master"
	if ( ! mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY 'asdHJ2312'" ); then
		fatal_error "Unable to set grant slave user on master server"
	else
		mysql -e 'flush privileges'
	fi
	log_me "Disabling broken slave cluster"
	if ( ! ssh 185.4.73.138 'mysql -e "stop slave"'); then
		fatal_error "Unable to stop slave cluster"
	fi
	log_me "Deleting old slave clustering"
	if ( ! ssh 185.4.73.138 'mysql -e "reset slave"'); then
		fatal_error "Unable to reset slave cluster"
	fi
        position=`mysql -e 'show master status' -ss | awk '{print $2}'`
        binfile=`mysql -e 'show master status' -ss | awk '{print $1}'`
        query="CHANGE MASTER TO MASTER_HOST='195.154.200.167', MASTER_USER='slave_user', MASTER_PASSWORD='asdHJ2312', MASTER_LOG_FILE='"$binfile"', MASTER_LOG_POS=$position"
	sql=`echo -e "$query"`
	echo -e $sql > /root/grant.sql
	scp /root/grant.sql root@185.4.73.138:
        log_me "Addin new master to slave server"
        if ( ! ssh 185.4.73.138 "mysql -e 'source /root/grant.sql'" ); then
		log_me "UNlocking master"
	        if ( ! mysql wtcapi -e "UNLOCK TABLES;" ); then
                	fatal_error "Unable to unlock tables"
        	fi
                fatal_error "Unable to change master on master host - 185.4.73.138"
        fi
	log_me "Starting the cluster"
	if ( ! ssh 185.4.73.138 'mysql -e "start slave"' ); then
		fatal_error "Starting slave replication"
	fi
	log_me "Unlock master tables"
	if ( ! mysql wtcapi -e "UNLOCK TABLES;" ); then
		fatal_error "Unable to unlock tables"
	else
		log_me "MySQL Cluster recovered."
	fi
fi
