#!/bin/bash


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


#logging functions
function log_me {
        echo -e "$GREEN[$WHITE+$GREEN]$DBLUE INFO:$BLUE $@$RESET"
}

function fatal_error {
        echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
        exit 1;
}

BINPHP=$(/usr/bin/whereis php | awk '{print $2}')
BINPHP70=$(/usr/bin/whereis php71 | awk '{print $2}')
BINPHP71=$(/usr/bin/whereis php71 | awk '{print $2}')
BINPHP72=$(/usr/bin/whereis php72 | awk '{print $2}')
BINPHP73=$(/usr/bin/whereis php73 | awk '{print $2}')
BINPHP74=$(/usr/bin/whereis php74 | awk '{print $2}')

if [ ! -f ./app/etc/env.php ]; then
	fatal_error "This script needs to be executed from Magento v2 root folder!"
fi




# USAGE
if [ $# -gt 1 ];  then
        log_me "\n-a or --auto	Auto php detect mode for Magento 2\n\nTo force php version:\n$0 php70\n$0 php71\n$0 php72\n$0 php73" ; exit
fi


if [ $1 ]; then
	if  [[ $1 != ^php7[0-4]$ ]]; then
		if [[ $1 =~ ^-a$ ]] || [[ $1 =~ ^--auto$ ]]; then
			log_me "Auto detect php mode started."
		fi
	else
		log_me "\n-a or --auto	Auto php detect mode for Magento 2\n\nTo force php version:\n$0 php70\n$0 php71\n$0 php72\n$0 php73" ; exit
	fi
fi

if [[ $1 =~ ^-h$ ]] || [[ $1 =~ ^--help$ ]]; then 
        log_me "\n-a or --auto	Auto php detect mode for Magento 2\n\nTo force php version:\n$0 php70\n$0 php71\n$0 php72\n$0 php73"; exit
fi

if [ $# -lt 1 ];  then
	log_me "Auto detect php mode started."
fi





# if magento 2
if [ -f ./composer.json  ]; then
	echo -e "It is Magento 2 installation"
	if (grep -q 'magento/product-community-edition' ./composer.json); then
		echo -e "magento/product-community-edition version detected !"
		MGVERSION=$(grep 'magento/product-community-edition' ./composer.json | awk -F '"' '{print $4}' )
	else
		MGVERSION=$(grep '\"version\"' ./composer.json  | awk -F '"' '{print $4}')
	fi
	# detect the proper php for execution
	if [[ $MGVERSION =~ ^2.4 ]]; then
		PHPRUN=$BINPHP74
	fi
	if [[ $MGVERSION =~ ^2.3 ]]; then
		PHPRUN=$BINPHP73	
	fi
	if [[ $MGVERSION =~ ^2.2 ]]; then
		PHPRUN=$BINPHP72
	fi
	if [[ $MGVERSION =~ ^2.1 ]]; then
		PHPRUN=$BINPHP71
	fi
	if [[ $MGVERSION =~ ^2.0 ]]; then
		PHPRUN=$BINPHP70
	fi
else
	echo -e "Can't find composer.json file, are you sure its magento 2 installation ?"
fi

# UNCOMMENT IF WANT TO HARDCODE PHP VERSION
# PHPRUN=$BINPHP71


CUSTOMPHP=$1

if [[ $CUSTOMPHP =~ ^php7[0-4]$ ]]; then
	PHPRUN=$(/usr/bin/whereis $CUSTOMPHP | awk '{print $2}')
	if ! [[ -f $PHPRUN ]]; then
		fatal_error "PHP Binary file $CUSTOMPHP not found or not installed!"
	fi
	log_me "CUSTOM PHP SET TO $PHPRUN\n"
fi


log_me "MG2 version $MGVERSION"
log_me "Using $PHPRUN"

$PHPRUN -d memory-limit=-1 bin/magento maintenance:enable
$PHPRUN -d memory-limit=-1 bin/magento cache:clean
$PHPRUN -d memory-limit=-1 bin/magento cache:flush
rm -rf ./var/cache/* ./var/page_cache/* ./generated/* ./pub/static/*

$PHPRUN -d memory-limit=-1 bin/magento setup:upgrade
$PHPRUN -d memory-limit=-1 bin/magento setup:di:compile
if ( ! $PHPRUN -d memory_limit=-1 bin/magento setup:static-content:deploy -f ); then
	log_me "Deploying static content without -f option"
	$PHPRUN -d memory_limit=-1 bin/magento setup:static-content:deploy 
fi
$PHPRUN -d memory-limit=-1 bin/magento indexer:reindex
$PHPRUN -d memory-limit=-1 bin/magento cache:clean
$PHPRUN -d memory-limit=-1 bin/magento cache:flush
$PHPRUN -d memory-limit=-1 bin/magento maintenance:disable

chmod 777  ./var/cache ./var/page_cache/ ./generated/ ./pub/static ./pub/media/ -R

log_me "Deployment completed."
