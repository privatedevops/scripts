#!/bin/bash

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

myip='188.165.193.183'

base_dir='/root/scripts/'
shortname="runvm"
host=`hostname`
now=`date "+%d-%h-%Y %H:%M %Z"`
logdir="$base_dir/logs"
log="$logdir/$shortname.log"

#report vm info when all done
mailreport='sanek@slacklinux.net'

function log_me {
        echo -e "$GREEN[$WHITE+$GREEN]$DBLUE INFO:$BLUE $@$RESET"
        echo -e "[$now] INFO: $@" >> $log
}

function fatal_error {
        echo -e "$RED[$WHITE!$RED]$WIHTE FATAL ERROR:$RED $@$RESET$BEEP"
        echo -e "[$now] FATAL ERROR: $@" >> $log
        tail -n 50 $log | mail -s "XML update for $shortname error on $host" $mailreport
        echo -e "The error has been reported to: sanek@slacklinux.net\n"
        exit 1;
}


EXPECTED_ARGS=1
E_BADARGS=65

if [ $# -ne $EXPECTED_ARGS ]
then
  echo -e "\n\nCurrent running VMs list:\n"
  echo  -e "`virsh list --all`\n\nNow run:\n\n$0 vmname\n\n"
  exit $E_BADARGS
fi


log_me "Checking for logging folder"
if [ ! -d $logdir ]; then
        mkdir -p $logdir
fi



#vm name
name=$1

#template xml
xml="/root/scripts/template.xml"

#vm UUID
uuid=`cat /proc/sys/kernel/random/uuid`
#VNC pass
vncpass=`dd bs=1 count=4 if=/dev/random 2>/dev/null |hexdump -v -e '/1 "%02X"'`

#VNC port
#next listen port#vncport=$((`netstat -lpnA inet | grep qemu | awk -F ":" '{print $2}' | awk '{print $1}' | sort`  +1 ))`


#new vm id
id=$((`virsh list --all | awk '{print $1}' | egrep '[0-9]' | tail -n1`  +1 )) 

#new mac
maccmd=`firsthalf='00:25:90' ; echo -n $firsthalf; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 ":%02X"'`
mac=$maccmd

#new images
template_img='/home/kvm/imgs/master.qcow2'
new_img="/home/kvm/imgs/$name.qcow2"

#master state
master_state=`virsh dominfo master | grep State | awk '{print $2}'`

log_me "Check if we already have run vm with this name"
if ( virsh list --all | grep -q $name ); then
    fatal_error "VM with name $name is already running"
fi

log_me "Preparing to copy the image from master"
if [[ $master_state  =~ "running" ]]; then
    log_me "Master is running"
    if ( ! virsh suspend master); then
        fatal_error "Unable to suspend master"
    fi
fi

log_me "Copy master image to $name"
if ( ! cp -a $template_img $new_img ); then
    fatal_error "Unable to copy sparse image for new virtual machine $name"
fi

sed -e "s/__ID__/$id/g" -e "s/__NAME__/$name/g" -e "s/__UUID__/$uuid/g" -e "s/__IMG__/$name.qcow2/g" -e "s/__MAC__/$mac/g" -e "s/__VNCPASS__/$vncpass/g" $xml >   /etc/libvirt/qemu/$name.xml

log_me "Simple check that new xml is done"
if ( ! grep -q $vncpass /etc/libvirt/qemu/"$name".xml ); then
    fatal_error "/etc/libvirt/qemu/"$name".xml  is not OK, please check it."
fi

log_me "Defining new virtual machine - $name"
if ( ! virsh define /etc/libvirt/qemu/"$name".xml ); then
    fatal_error "Unable to define new virtual machine - $name"
fi

log_me "Running new virtual machine - $name"
if ( ! virsh start $name); then
    fatal_error "Unable to run virtual machine $name"
fi
log_me "Setting autostart for new virtual machine"
if ( ! virsh autostart $name ); then
    fatal_error "Unable to set autostart on new virtual machine $name"
fi

log_me "Resuming master"
master_state=`virsh dominfo master | grep State | awk '{print $2}'`
if [[ $master_state  =~ "paused" ]]; then
    log_me "Master is suspended, resuming it."
    if ( ! virsh resume master); then
        fatal_error "Unable to resume master"
    fi
fi

vncport=$((`virsh domdisplay $name | awk -F ":" '{print $3}'` +5900))

log_me "Sending VNC info to the report mail: $mailreport"
if ( ! echo -e "\nNew server started\nName: $name\nVNC Host: $myip\nVNC Port: $vncport\nVNC Pass: $vncpass\n" | mail -s "VM $name created" $mailreport ); then
    log_me "Unable to send VNC credentials to $mailreport"
fi

log_me "\nNew server started\nName: $name\nVNC Host: $myip\nVNC Port: $vncport\nVNC Pass: $vncpass\n"

exit
