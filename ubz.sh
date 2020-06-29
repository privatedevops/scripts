#!/bin/bash
# ubuntu
userdel -r site24x7-agent; userdel -r pinguzo ; rm -rf /root/Site24x7_Linux_64bit.install  /home/forge/Site24x7_Linux_64bit.install 
grep bash /etc/passwd
apt update 
apt upgrade -y
apt install -y zabbix-agent
systemctl enable zabbix-agent
sed -e 's/^Server=.*/Server=zb.hostingidol.com/g' -e 's/^ServerActive.*/ServerActive=zb.hostingidol.com:10051/g' /etc/zabbix/zabbix_agentd.conf -e "s/^Hostname=.*/Hostname=$(hostname)/g" -i
service zabbix-agent restart
tail  /var/log/zabbix-agent/zabbix_agentd.log  
ufw allow 10050/tcp
ufw status

