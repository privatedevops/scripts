#!/bin/bash
#
# https://hostingidol.com
#
# scure NFS share and MYSQL LB on DO local/private network with firewall
#
HOST=$(hostname)
TOKEN='API TOKEN HERE'
REPORTMAIL='REPORT EMAIL HERE'

IDS=$(curl -s -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/droplets/" | jq ".droplets[] | .id")


for DOID in $IDS ; do
	if [ $DOID -gt 100 ]; then
	        DOID=$DOID;
	else 
		echo "DigitalOcean API fwall private network cron failure on $HOST" | mail -s 'DigitalOcean API cron fwall issue' $REPORTMAIL
		continue
	fi
	
	ips=$(curl -s -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/droplets/$DOID" | jq -r '.droplet.networks.v4[] | select(.type=="public") | .ip_address' )

	for ip in $ips ; do 
		#check if we already have this rule added
		if ( ! /sbin/iptables -L -nx | grep -qE "$ip"); then
			echo "Adding $ip to iptables allow input_services rules"
			/sbin/iptables -I INPUT -s $ip -j ACCEPT
			/sbin/iptables -A INPUT -s $ip -d $ip -p udp -m multiport --sports 10053,111,2049,32769,875,892,3306 -m state --state ESTABLISHED -j ACCEPT
			/sbin/iptables -A INPUT -s $ip -d $ip -p tcp -m multiport --sports 10053,111,2049,32803,875,892,3306 -m state --state ESTABLISHED -j ACCEPT
			/sbin/iptables -A OUTPUT -s $ip -d $ip -p udp -m multiport --dports 10053,111,2049,32769,875,892,3306 -m state --state NEW,ESTABLISHED -j ACCEPT
			/sbin/iptables -A OUTPUT -s $ip -d $ip -p tcp -m multiport --dports 10053,111,2049,32803,875,892,3306 -m state --state NEW,ESTABLISHED -j ACCEPT

		else
			echo "IP $ip already added in our firewall"
		fi
	done
done
