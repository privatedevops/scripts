#!/bin/bash
#
# WordPress duplicator Tool for Vesta Panel 
# 
#

clear
############

display_usage() {
        echo "Vesta Hosting Panel WordPress duplicator"
        echo -e "\nUsage: $0 fromlocaldomain user todomain \n"
        exit
        }

if [  $# -lt 3 ] ; then
                display_usage
                exit 1
fi

if [  $# -gt 3 ] ; then
                display_usage
                exit 1
fi

if [[ ( $# == "--help") ||  $# == "-h" ]]; then
        display_usage
        exit 0
fi


#ARG vars

cloneodmain=$1
vestauser=$2
newdomain=$3

#script vars
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

shortname='wpcp'
base_dir="/root/scripts/$shortname/"

host=`hostname`

now=`date "+%d-%h-%Y %H:%M %Z"`
logdir="$base_dir/logs"
log="$logdir/$shortname.log"

#main IP of the account
ipaddress='107.170.104.183'

vlistdomains=$(/usr/local/vesta/bin/v-list-web-domains $vestauser | awk '{print $1}' | grep '\.')
listpasswdusers=$(awk -F ':' '{print $1}' /etc/passwd )
listips=$(ip a | grep inet | grep global | awk '{print $2}' | sed 's/\/.*//g') 

#clone vars from
clonewpfolder="/home/$vestauser/web/$cloneodmain/public_html/"

clonedb=$(grep DB_NAME /home/$vestauser/web/$cloneodmain/public_html/wp-config.php | awk -F "'" '{print $4}')
clonedbuser=$(grep DB_USER /home/$vestauser/web/$cloneodmain/public_html/wp-config.php | awk -F "'" '{print $4}')
clonedbpwd=$(grep DB_PASSWORD /home/$vestauser/web/$cloneodmain/public_html/wp-config.php | awk -F "'" '{print $4}')

#new domain vars
newdomainroot="/home/$vestauser/web/$newdomain/public_html/"
newdb="$vestauser_$(head /dev/urandom | tr -dc a-z0-9 | head -c 4 ; echo '')"
newdbuser="$vestauser_u$(head /dev/urandom | tr -dc a-z0-9 | head -c 4 ; echo '')"
newdbpwd=$(head /dev/urandom | tr -dc a-zA-Z0-9 | head -c 16 ; echo '')


#logging functions
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
if [ ! -d $log ]; then
	touch $log
fi

log_me "Checking for logging folder"
if [ ! -f $logdir ]; then
	mkdir -p $logdir
fi


#check if domain exist
log_me "checking if domain exist"
if ( echo -e "$vlistdomains" | grep -Eiq ^"$newdomain$"$  ); then
	fatal_error "Domain $newdomain already exsist on this server"
fi

#check if user exist
log_me 'checking if user exist'
if ( ! echo -e "$listpasswdusers" | grep -Eiq ^"$vestauser"$ ); then
	fatal_error "User $vestauser does NOT exist"
fi

#check if IP exist
log_me "checking if IP exist"
if ( ! echo -e "$listips" | grep -Eiq ^"$ipaddress"$  ); then
	fatal_error "IP address - $ipaddress is not active on this host"
fi

#adding domain
log_me "adding domain $newdomain"
if ( ! /usr/local/vesta/bin/v-add-domain $vestauser $newdomain $ipaddress restart ); then
	fatal_error "Unable to add $newdomain, please report to your sysadmin"
fi

#checking if the new domain is pointed to our server
#log_me "checking if the new domain - $newdomain is already pointed to our server"
#if ( ! host $newdomain | grep 'address' | awk '{print $4}' | grep -Eiq ^"$ipaddress"$ ); then
#	fatal_error "The $newdomain is not yet pointed to $ipaddress, please fix and restart the process"
#fi

#generating letsencrypt SSL
#log_me "adding LetsEncrypt SSL for $newdomain"
#if ( ! /usr/local/vesta/bin/v-add-letsencrypt-domain $vestauser $newdomain "www."$newdomain no ); then
#	fatal_error "Unable to add free LetsEncrypt SSL for $newdomain, please report to your sysadmin"
#fi

#moving WP files to new domain folder
log_me "moving WP files to new domain folder"
if ( ! rsync -aH $clonewpfolder $newdomainroot >> /dev/null ); then
	fatal_error "Unable to move WP files to from $clonewpfolder $newdomainroot"
fi

#dumping DB from skell domain
log_me "dumping DB from skell domain"
if ( ! mysqldump $clonedb > $base_dir/tmp/clonedb.sql ); then
	fatal_error "Unable to mysqldump the DB $clonedb from $cloneodmain"
fi

#changing DB's hostname
log_me "fixing SQL dump, setting correct new domain name - $newdomain $base_dir/tmp/clonedb.sql"
if ( ! sed -i "s/$cloneodmain/$newdomain/g" $base_dir/tmp/clonedb.sql ); then
	fatal_error "Unable to update the domain name into the mysqldump - $base_dir/tmp/clonedb.sql"
fi

#creating DB info for new domain and importing DB
log_me "creating new DB and DB credentials [ DB: $newdb DBUSR: $newdbuser DBPWD: $newdbpwd ]"
if ( ! /usr/local/vesta/bin/v-add-database $vestauser $newdb $newdbuser $newdbpwd ); then
	fatal_error "Unable to create DB info"
fi

#import sql dump to new db
log_me "Importing SQL dump to DB sam_$newdb"
if ( ! mysql sam_$newdb < $base_dir/tmp/clonedb.sql ); then
	fatal_error "Unable to import $base_dir/tmp/clonedb.sql to sam_$newdb"
fi
log_me "deleting the temporary sql dump"
if [ -f $base_dir/tmp/clonedb.sql ]; then
	if ( ! rm -f $base_dir/tmp/clonedb.sql ); then
		fatal_error "Unable to delete the temporary SQL dump - $base_dir/tmp/clonedb.sql"
	fi
fi

#fix DB info in wp-config.php
log_me "FIXING DB info in $newdomainroot/wp-config.php"
if ( ! sed -i -e "s/DB_NAME', .*/DB_NAME', 'sam_$newdb');/" -e "s/DB_USER', .*/DB_USER', 'sam_$newdbuser');/" -e "s/DB_PASSWORD', .*/DB_PASSWORD', '$newdbpwd');/" $newdomainroot/wp-config.php ); then
	fatal_error "Unable to fix DB info in $newdomainroot/wp-config.php"
fi

#fix ownerships
log_me "Fixing $newdomainroot ownerships"
if ( !  chown "$vestauser":  $newdomainroot -R ); then
	fatal_error "Unable to fix $newdomainroot ownerships"
fi
