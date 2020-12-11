#!/bin/bash


cfipranges='https://www.cloudflare.com/ips-v4'

for range in `curl -s $cfipranges` ; do 

	#check if we already have this rule added
	if ( ! /sbin/iptables -L -nx | grep -qE "$range"); then
		echo "Adding $range to iptables allow input_services rules"
		/sbin/iptables -I INPUT -s $range -p tcp -m multiport --dport 80,443 -j ACCEPT
#	else
#		echo "IP range $range already added in our firewall"
	fi
done
