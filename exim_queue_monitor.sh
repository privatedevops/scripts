#!/bin/bash

mail_users="notifications@domain.com"


limit=300 # Set the limit here

clear;
result="/tmp/eximqueue.txt"
queue="`exim -bpc`"

if [ "$queue" -ge "$limit" ]; then
	echo -e "Current queue is: $queue\n " > $result
	echo "Summary of Mail queue" >> $result
	echo "`exim -bp | exiqsumm`" >> $result
	for mailuser in $mail_users ; do 
		mail -s "Number of mails on `hostname` : $queue" $mailuser < $result
		echo -e "Issue reported to: $mailuser"
	done
	echo -e "\n"
	cat $result
	curl -X POST --data-urlencode 'payload={"channel": "#alerts", "text": "$(hostname) queue has more than '$limit' mails in queue"}' 'https://hooks.slack.com/services/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'
else
	echo "Queue OK: $queue"
fi

rm -f $result

