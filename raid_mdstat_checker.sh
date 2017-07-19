#!/bin/bash

# Author: stanislav@bgcode.com
# https://hostingidol.com

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

shortname="raid_checker"


export PATH=/sbin/:$PATH

script_path=$(pwd -P)

raids=('/dev/md126' '/dev/md127')

MAILTO='mail@domain.com'
SLACKHOOKURL='https://hooks.slack.com/services/......'
HOSTNAME=$(hostname)

arrayoutput=$(mdadm -D /dev/md*)

function fatal_error {
	echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
	echo -e "$arrayoutput" | mail -s "$HOSTNAME array issues" $MAILTO
	echo -e "The problem has been reported to: $MAILTO\n"
	curl -s -X POST --data-urlencode 'payload={"channel": "#alerts", "text": "RAID Array issue '"$HOSTNAME"':  '"\n$arrayoutput"' "}' $SLACKHOOKURL >> /dev/null
	exit 1;
}

case "$1" in
  install)
    echo 'Installing...'
    crontab -l | { cat; echo "10 10,15,19,22 * * * /bin/bash $script_path/$0"; } | crontab -
    service cron restart
    ;;
  *)
    echo 'Scanning' ${raids[*]} '...'

    for raid in ${raids[*]}

    do

      faulty=$(mdadm -D $raid | grep faulty)

      if [[ $faulty ]]
        then
          echo 'Faulty found in' $raid 'disk' $disk
	  fatal_error
        else
          echo 'Array' $raid 'is OK'
     fi

    done

    echo 'RAID is OK'
esac