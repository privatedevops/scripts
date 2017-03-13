#!/bin/bash
#
# Created on 13 March 2017 by BGCODE LTD. a.k.a. HostingIDOL https://hostingidol.com
#


declare -x PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
declare -x SHELL="/bin/bash"

#AWS ACCESS AND SECURITY KEYS 
AWS_ACC_KEY=''
AWS_SECR_KEY=''

#aws region
AWS_REGION=''


#AWS volumes for snapshots ,add with space on one line if more than 1
snap_volumeids=''

#mysql root credentials
MYSQLSOCKET=''
MYSQLROOTPASS=''

for snap_volumeid in $snap_volumeids; do 
	old_snaps=`/usr/local/bin/aws ec2 describe-snapshots --filters  "Name=volume-id,Values=$snap_volumeid"  | grep SnapshotId | awk '{print $2}' | sed -e 's/\"//g' -e 's/\,//g'`

	if ( ! /usr/bin/ec2-consistent-snapshot --aws-access-key-id $AWS_ACC_KEY --aws-secret-access-key $AWS_SECR_KEY --region $AWS_REGION --freeze-filesystem / --mysql-host localhost --mysql-socket $MYSQLSOCKET --mysql-username root --mysql-password $MYSQLROOTPASS --description "Ssnapshot for $snap_volumeid: $(date +%c)"  $snap_volumeid ); then
		echo -e "Error $(date +%c): Snapshot problem"
		echo -e "Error $(date +%c): Snapshot problem" >> /var/log/snapshots.log
		exit 1
	else
		echo -e "OK $(date +%c): Snapshot started"
		echo -e "OK $(date +%c): Snapshot started" >> /var/log/snapshots.log
	fi
	for del_sn in $old_snaps;
	do
		if ( ! /usr/local/bin/aws ec2 delete-snapshot --snapshot-id=$del_sn ); then
			echo -e "Error $(date +%c): Unable to remove old snapshot - $del_sn"
			echo -e "Error $(date +%c): Unable to remove old snapshot - $del_sn" >> /var/log/snapshots.log
		else
			echo -e "OK: Deleting snapshot - $del_sn"
			echo -e "OK: Deleting snapshot - $del_sn" >> /var/log/snapshots.log
		fi
	done
done

exit 
