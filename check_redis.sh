#!/bin/bash
#
#       Copyrights Private Devops LTD. - https://privatedevops.com
#

REDISCLI='/usr/bin/redis-cli'

REDISHOST='127.0.0.1'
RPASSWORD=''

SLACKHOOKURL=''
HOSTNAME=$(/bin/hostname)


if (! $REDISCLI -h $REDISHOST -a $RPASSWORD PING >> /dev/null ); then
	echo "[$HOSTNAME] Unable to connect to redis - $REDISHOST"
	curl -X POST --data-urlencode 'payload={"channel": "#urgent", "text": "Unable to connect to redis server - '"$REDISHOST"'"}' $SLACKHOOKURL
	
	if (! systemctl restart redis-server ); then
		echo "[$HOSTNAME] Redis restarted on $HOSTNAME"
		curl -X POST --data-urlencode 'payload={"channel": "#urgent", "text": "['"$HOSTNAME"'] Unable to start redis"}' $SLACKHOOKURL
		
	else
		echo "[$HOSTNAME] redis restarted"
		curl -X POST --data-urlencode 'payload={"channel": "#urgent", "text": "['"$HOSTNAME"'] redis restarted"}' $SLACKHOOKURL
	fi
fi
