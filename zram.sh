#!/bin/bash

################################################################################
# Script Name:    zRAM & OOM Guardian Tool (Private Devops Edition)
# Version:        1.9
# Author:         Private Devops LTD
# Description:    Reliable zRAM resize & Persistent Custom Sysctl.
################################################################################

BANNER="
################################################################################
#                          PRIVATE DEVOPS LTD.                                 #
#                Full Cleanup & Memory Protection System                       #
################################################################################
"
echo "$BANNER"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 1. Root check
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root!"
   exit 1
fi

# 2. Argument check
SIZE_ARG=$1
if [[ -z "$SIZE_ARG" ]]; then
    echo "Usage: $0 <size_in_GB> (e.g., $0 4G)"
    exit 1
fi
SIZE_RAW=$(echo $SIZE_ARG | sed 's/[Gg]//g')

# 3. Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_LIKE=$ID_LIKE
else
    echo "[CRITICAL] OS detection failed."
    exit 1
fi

# 4. DEEP CLEANUP (The "Fresh Start" Logic)
echo "[CLEANUP] Purging old zRAM configuration and rules..."
# Stop and reset zram devices
swapoff /dev/zram0 2>/dev/null
if [ -b /dev/zram0 ]; then
    zramctl --reset /dev/zram0 2>/dev/null
fi

# Remove OLD rules and configs
rm -f /etc/udev/rules.d/99-zram.rules
rm -f /etc/systemd/zram-generator.conf
rm -f /usr/lib/systemd/zram-generator.conf
rm -rf /run/systemd/generator/zram*
rm -rf /run/systemd/generator/dev-zram0*

# Remove traditional disk swap
DISK_SWAPS=$(swapon --show --noheadings | grep -v "zram" | awk '{print $1}')
if [ ! -z "$DISK_SWAPS" ]; then
    for SWAP_PATH in $DISK_SWAPS; do
        echo "[ACTION] Disabling disk swap: $SWAP_PATH"
        swapoff "$SWAP_PATH" 2>/dev/null
        if grep -q "^$SWAP_PATH" /etc/fstab; then
            sed -i.bak "s|^$SWAP_PATH|# Private Devops Disabled: $SWAP_PATH|" /etc/fstab
        fi
        [ -f "$SWAP_PATH" ] && rm -f "$SWAP_PATH"
    done
fi

# 5. Kernel Module Fix (Ubuntu/Debian)
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    CURRENT_KERNEL=$(uname -r)
    if [ ! -d "/lib/modules/$CURRENT_KERNEL" ]; then
        echo "[ACTION] Kernel modules missing. Fixing..."
        apt-get update && apt-get install -y --reinstall linux-modules-$(uname -r)
    fi
fi

# 6. Install Dependencies
install_pkg() {
    PACKAGE=$1
    if [[ "$OS_ID" =~ (ubuntu|debian) || "$OS_LIKE" =~ (debian) ]]; then
        apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "$PACKAGE"
    elif [[ "$OS_ID" =~ (almalinux|rocky|rhel|centos|cloudlinux) ]]; then
        command -v dnf &>/dev/null && dnf install -y "$PACKAGE" || yum install -y "$PACKAGE"
    fi
}
install_pkg "util-linux"
install_pkg "zstd"
install_pkg "lz4"

# 7. Reset Module
modprobe -r zram 2>/dev/null

# 8. Implementation
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    echo "[CONFIG] Setting up zram-tools..."
    install_pkg "zram-tools"
    echo -e "ALGO=lz4\nSIZE=${SIZE_RAW}000\nPRIORITY=100" > /etc/default/zramswap
    systemctl restart zramswap || (apt-get install -y linux-modules-extra-$(uname -r) && systemctl restart zramswap)
elif [[ "$OS_ID" =~ (almalinux|rocky|rhel|centos|cloudlinux) ]]; then
    echo "[CONFIG] Setting up RHEL/Alma zRAM ($SIZE_RAW GB)..."
    modprobe zram 2>/dev/null
    ALGO="lzo"
    sleep 1
    if [ -f /sys/block/zram0/comp_algorithm ]; then
        if grep -q "zstd" /sys/block/zram0/comp_algorithm; then ALGO="zstd";
        elif grep -q "lz4" /sys/block/zram0/comp_algorithm; then ALGO="lz4"; fi
    fi
    
    # Persistent udev rule
    echo "ACTION==\"add\", KERNEL==\"zram0\", ATTR{comp_algorithm}=\"$ALGO\", ATTR{disksize}=\"${SIZE_RAW}G\", RUN+=\"/usr/sbin/mkswap /dev/zram0\", RUN+=\"/usr/sbin/swapon -p 100 /dev/zram0\"" > /etc/udev/rules.d/99-zram.rules
    
    # Apply immediately (Force Reset & Re-init)
    zramctl --reset /dev/zram0 2>/dev/null || modprobe -r zram 2>/dev/null
    modprobe zram num_devices=1 2>/dev/null
    
    echo "$ALGO" > /sys/block/zram0/comp_algorithm 2>/dev/null
    echo "${SIZE_RAW}G" > /sys/block/zram0/disksize 2>/dev/null
    
    /usr/sbin/mkswap /dev/zram0 &>/dev/null
    /usr/sbin/swapon -p 100 /dev/zram0 &>/dev/null
fi

# 9. TUNING SYSCTL (User Custom Values)
echo "[TUNING] Applying Custom Guardian sysctl settings..."
sed -i '/vm.swappiness/d' /etc/sysctl.conf
sed -i '/vm.oom_kill_allocating_task/d' /etc/sysctl.conf
sed -i '/vm.overcommit_memory/d' /etc/sysctl.conf
sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf

cat <<EOF >> /etc/sysctl.conf
vm.swappiness=10
vm.oom_kill_allocating_task=0
vm.overcommit_memory=1
vm.vfs_cache_pressure=100
EOF

sysctl -p /etc/sysctl.conf >/dev/null 2>&1

# 10. Verification
echo "--- Final Health Check ---"
zramctl
swapon --show
free -m
echo "################################################################################"
echo "#          Infrastructure Optimized by Private Devops LTD.                     #"
################################################################################

