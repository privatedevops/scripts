#!/bin/bash
set -euo pipefail

#
# Copyrights Private Devops LTD. - https://privatedevops.com
#

SWAPFILE="/var/.swap1"
SWAPSIZE_MB=4096   # 4GB

FSTAB="/etc/fstab"
HOSTNAME=$(/bin/hostname)

echo "[$HOSTNAME] Swap setup starting"

# check if swap already active
if swapon --show | grep -q "$SWAPFILE"; then
    echo "[$HOSTNAME] Swap already active: $SWAPFILE"
    swapon --show
    exit 0
fi

# create swap file only if it doesn't exist
if [[ ! -f "$SWAPFILE" ]]; then
    echo "[$HOSTNAME] Creating swap file ($SWAPSIZE_MB MB)"

    fallocate -l "${SWAPSIZE_MB}M" "$SWAPFILE" 2>/dev/null || \
    dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SWAPSIZE_MB"

    chown root:root "$SWAPFILE"
    chmod 0600 "$SWAPFILE"

    mkswap "$SWAPFILE"
else
    echo "[$HOSTNAME] Swap file already exists, skipping creation"
fi

# enable swap
echo "[$HOSTNAME] Enabling swap"
swapon "$SWAPFILE"

# ensure fstab entry exists only once
if ! grep -q "^$SWAPFILE\s" "$FSTAB"; then
    echo "[$HOSTNAME] Adding swap entry to /etc/fstab"
    echo "$SWAPFILE none swap sw 0 0" >> "$FSTAB"
else
    echo "[$HOSTNAME] fstab entry already exists"
fi

# show active swap
swapon --show
echo "[$HOSTNAME] Swap setup completed"
