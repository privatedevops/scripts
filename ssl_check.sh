#!/bin/bash
#clear
domain=$1
sslport=$2


display_usage() { 
	echo "SSL validation cehcker" 
	echo -e "\nUsage: $0 domain.com sslport \n" 
	exit
	} 

if [  $# -lt 2 ] ; then 
		display_usage
		exit 1
fi

if [  $# -gt 2 ] ; then
                display_usage
                exit 1
fi

if [[ ( $# == "--help") ||  $# == "-h" ]]; then 
	display_usage
	exit 0
fi 

ssldomain=`echo | openssl s_client -connect $domain:$sslport 2>/dev/null | openssl x509 -noout -subject | awk -F '/CN=' '{print $2}'`

if [[ $ssldomain == "" ]]; then
	echo "SSL not found on domain $domain on port $sslport"
	exit
fi

if [[ $ssldomain != $domain ]]; then
	echo "Invalid SSL for domain $domain. The SSL is validated for $ssldomain" 
	exit 2
elif [[ $ssldomain == $domain ]]; then
	echo "SSL and domain name match for $domain - SSL is Valid"
	exit 0
else
	echo "UNKNOWN- $output"
	exit 3
fi
