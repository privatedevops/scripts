#!/bin/bash
#
#       Copyrights Private Devops LTD. - https://privatedevops.com
#


#The source directory:
DESTINATION="/root/mongodumps/"


if [[ $1 != '' ]]; then
    SRC=$1
fi

CURDATE=`date  +"%d-%m-%Y-%Hh%Mm"`

MONGOUSER='************'
MONGOPASS='************'


if [ ! -d $DESTINATION ]; then
    mkdir -p $DESTINATION/$CURDATE
fi

echo -e "Starting Mongo backups from server: $server"
mongodump --username $MONGOUSER --password $MONGOPASS  --port 27017 --gzip -o $DESTINATION/$CURDATE

#keep only last 24 hours backups
find $DESTINATION -type f -mtime +1 -exec rm -fr {} \;
