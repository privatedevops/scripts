#!/bin/bash

mail_users="notifications@domain.com"

#checking per domain for more than 100 sending  mails in queue
result=`exim -bp|grep "<"|awk  {'print $4'}|cut -d"<" -f2|cut -d">" -f1|sort -n| awk -F '@' '{print $2}' | sort | uniq -c | sort -n | awk '{ if($1 > 100 ) {print $2}}' |sed -e '/^$/D'`

if  [[ $result ]]; then
	echo $result
	for mailuser in $mail_users ; do 
		mailstats=`exim -bp | exiqsumm`
		echo -e $mailstats | mail -s "Email queue on `hostname` is warning, please check for outgoing spam" $mailuser
		echo -e "Issue reported to: $mailuser" 
	done
else
	echo "Qeue OK"
fi
