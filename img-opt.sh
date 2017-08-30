#!/bin/bash

base_dir="/root/scripts"
shortname="opti-img"
host=$(hostname)
now=$(date "+%d-%h-%Y %H:%M %Z")
logdir="$base_dir/logs"
log="$logdir/$shortname.log"
user=username
marker='hostingidol.com'

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

display_usage() { 
	echo "PNG & JPEG images optimized for web" 
	echo -e "\nUsage: $0 folder or $0 imagefile \n" 
	exit
	} 

if [  $# -lt 1 ] ; then 
		display_usage
		exit 1
fi

if [  $# -gt 1 ] ; then
                display_usage
                exit 1
fi

if [[ ( $# == "--help") ||  $# == "-h" ]]; then 
	display_usage
	exit 0
fi 


SCANFOLDER=$1


function log_me {
	echo -e "$GREEN[$WHITE+$GREEN]$DBLUE INFO:$BLUE $@$RESET"
	echo -e "[$now] INFO: $@" >> $log
}

function fatal_error {
	echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
	echo -e "[$now] FATAL ERROR: $@" >> $log
#	tail -n 50 $log | mail -s "IMG convert script $shortname error on $host" sanek@slacklinux.net
#	echo -e "The error has been reported to: sanek@slacklinux.net\n"
	exit 1;
}

log_me "Checking for logging folder"
if [ ! -d $logdir ]; then
	mkdir -p $logdir
fi

if [ -d $SCANFOLDER ]; then
	log_me "Checking if scanfolder exist"
	if [ ! -d $SCANFOLDER ]; then
		fatal_error "$SCANFOLDER NOT EXIST OR ITS NOT A FOLDER!"
	else
		filelist=$(find $SCANFOLDER  | egrep -i 'jpg$|png$|jpeg$' | sed 's/\ /\\ /g')
	fi
fi
if [ -f $SCANFOLDER ]; then
	filelist=$1
fi




echo -e "$filelist" | \
while read -r img; do
	imgtype=$(echo "$img" | xargs file | awk -F ":" '{print $2}' | awk '{print $1}')
	tag=$(echo $img| xargs exiftool -t | grep Comment|awk '{print $2}')
	if [[ "$imgtype" == 'PNG' ]]; then
		type='PNG'
                if [[ $tag == $marker ]]; then
                        log_me "Richter marker found, skipting image - $img"
                        continue;
                else
                        log_me "Marker is missing, optimizing - $img - Marker: $tag"
                        log_me "Optimizing $img with optipng"
			OPTIPNG=$(echo $img|optipng -o7 -f4 -strip all -quiet -preserve)
                	log_me "Adding our marker for $img"
	                if ( ! echo $img | xargs exiftool -Comment="$marker" ); then
        	                fatal_error "Unable to set img tag $marker to $img"
                	fi
			if [ -f "$img"_original ]; then
	        	        echo "$img"_original | xargs rm -f
			fi
		fi
	elif [[ "$imgtype" == 'JPEG' ]]; then
		type='JPEG'
	        if [[ $tag == $marker ]]; then
			log_me "Richter marker found, skipting image - $img"
			continue;
		else
	                log_me "Marker is missing, optimizing - $img - $marker"
			log_me "Converting img quality to 80% with convert tool"
			
			echo -e "convert $img  -quality 80 -strip -interlace Plane $img" | sh

			log_me "Removing meta info with jpegoptim"
			JPEGOPTIM=$(echo $img | jpegoptim --strip-all)
			log_me "Adding our marker for $img"
	                if ( ! echo $img | xargs exiftool -Comment="$marker" ); then
				fatal_error "Unable to set img tag $marker to $img"
			fi
	                if [ -f "$img"_original ]; then
        	                echo "$img"_original | xargs rm -f
                	fi
		fi
	else
		 log_me "ERROR IMG TYPE NOT VALID for - $img"
	fi
	
#	echo  -e -n  "$img - $type - $tag\n"

done
