#!/bin/bash
#
#       Copyrights Private Devops LTD. - https://privatedevops.com
#

mail='setmailhere@toanydomain.com'
cp_accs=`cat /etc/userdomains | awk '{print $2}' | sort | uniq | grep -v nobody`
sys_mysql_dbs=`mysql -e 'show databases' | grep -v '\_' | grep -v Database`

cpm_dir="/home/cpmoves"
smdbkpdir="$cpm_dir/system"

if [ ! -d $cpm_dir ]; then
	echo "Creating $cpm_dir"
	mkdir $cpm_dir
else
	echo "Cleaning $cpm_dir"
	rm -f $cpm_dir/cpmove-*
fi



for account in $cp_accs; do
	dbaccount=`echo  $account | cut -c 1-8`
	acc_dbs=`mysql -e "show databases" | grep $dbaccount`
	
	for udb in $acc_dbs; do
		echo "Dumping: $udb mysql DB"
		if ! ( mysqldump $udb  | gzip > /home/$account/$udb.gz ); then
			echo "ERROR: MySQL DB dump for db $udb" | mail -s 'VM1 mysqldump issue' $mail
		else
			chown $account: /home/$account/$udb.gz
		fi
	done
	
	/scripts/pkgacct --skiphomedir --skipacctdb $account
	mv /home/cpmove-$account.tar.gz $cpm_dir
done


if [ ! -d $smdbkpdir ]; then
	echo "Creating $smdbkpdir"
	mkdir -p $smdbkpdir
fi

for sysdb in $sys_mysql_dbs; do
	if ( ! mysqldump $sysdb | gzip > $smdbkpdir/$sysdb.gz ); then
		echo "ERROR: MySQL DB dump for db $sysdb" | mail -s 'VM1 mysqldump issue' $mail
	fi
done
