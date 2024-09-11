#!/bin/bash

target_ip=""

# Check if --nodeip= argument is provided
for arg in "$@"; do
  case $arg in
    --nodeip=*)
    target_ip="${arg#*=}"
    shift
    ;;
  esac
done

if [ -z "$target_ip" ]; then
    # List running EC2 instances in us-west-1 with names like WEB-node-* and their IP addresses
    webnodes=$(aws ec2 describe-instances \
        --region us-west-1 \
        --query "Reservations[].Instances[?State.Name == 'running'].[PrivateIpAddress, Tags[?Key=='Name'].Value | [0]]" \
        --output text | grep 'WEB-node' | awk '{print $1}')
else
    # Validate the provided IP address format
    if [[ $target_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        webnodes=$target_ip
    else
        echo "Invalid IP address format."
        exit 1
    fi
fi

# Check if webnodes is empty
if [ -z "$webnodes" ]; then
    echo "No WEB-node instances were detected."
    exit 1
fi

for node in $webnodes; do
    echo "Updating LB node instance: $node"
    rsync -e 'ssh -p 22 -o StrictHostKeyChecking=no' -aHvP /home/forge/api.storiaverse.com/ forge@${node}:/home/forge/api.storiaverse.com/
    echo -e "Executing on $node: composer install ; php artisan cache:clear ; php artisan config:cache ; php artisan route:cache ; php artisan event:cache ; php artisan horizon:publish ; npm ci ; npm run build"
    ssh -p 22 -o StrictHostKeyChecking=no forge@${node} "cd /home/forge/api.storiaverse.com/current/ ; composer install ; php artisan cache:clear ; php artisan config:cache ; php artisan route:cache ; php artisan event:cache ; php artisan horizon:publish ; npm ci ; npm run build"
done
