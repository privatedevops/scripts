#!/bin/bash

SWAPNAME='.swap1'

dd if=/dev/zero of=/var/$SWAPNAME bs=1024 count=4194304
chown root:root /var/$SWAPNAME
chmod 0600 /var/$SWAPNAME
mkswap /var/$SWAPNAME
swapon /var/$SWAPNAME
echo "/$SWAPNAME none swap sw 0 0" >> /etc/fstab
