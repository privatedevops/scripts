################################################################################
#          Infrastructure Optimized by Private Devops LTD.                     #
root@srv01:~# vi zram.sh
root@srv01:~# cat zram.sh
#!/bin/bash

################################################################################
# Script Name:    zRAM Optimization Tool (Enterprise Edition)
# Version:        1.4
# Author:         Private Devops LTD - https://privatedevops.com
# Description:    Non-interactive swap cleanup & automated zRAM configuration.
################################################################################

BANNER="
################################################################################
#                          PRIVATE DEVOPS LTD.                                 #
#                Non-interactive Performance Optimization                      #
################################################################################
"
echo "$BANNER"

# Disable interactive prompts for apt and needrestart
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 1. Root check
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (sudo)!"
   exit 1
fi

# 2. Argument check
SIZE_ARG=$1
if [[ -z "$SIZE_ARG" ]]; then
    echo "Usage: $0 <size_in_GB> (e.g., $0 2G)"
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

# 4. Check for missing kernel modules (The "Kernel Mismatch" fix)
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    CURRENT_KERNEL=$(uname -r)
    if [ ! -d "/lib/modules/$CURRENT_KERNEL" ]; then
        echo "[CRITICAL] Kernel mismatch detected! Running: $CURRENT_KERNEL, but modules are missing."
        echo "[ACTION] Installing current kernel modules to avoid reboot..."
        apt-get update && apt-get install -y --reinstall linux-modules-$(uname -r)
    fi
fi

# 5. FULL DISK SWAP REMOVAL
echo "[CLEANUP] Removing traditional disk-based swap..."
DISK_SWAPS=$(swapon --show --noheadings | grep -v "zram" | awk '{print $1}')

if [ ! -z "$DISK_SWAPS" ]; then
    for SWAP_PATH in $DISK_SWAPS; do
        echo "[ACTION] Disabling and removing swap: $SWAP_PATH"
        swapoff "$SWAP_PATH" 2>/dev/null
        sed -i.bak "s|^$SWAP_PATH|# Private Devops Disabled: $SWAP_PATH|" /etc/fstab
        [ -f "$SWAP_PATH" ] && rm -f "$SWAP_PATH"
    done
fi

# 6. Dependency check & Install (Non-interactive)
install_pkg() {
    PACKAGE=$1
    if [[ "$OS_ID" =~ (ubuntu|debian) || "$OS_LIKE" =~ (debian) ]]; then
        if ! dpkg -l | grep -q "^ii  $PACKAGE "; then
            echo "[INSTALL] $PACKAGE..."
            apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" "$PACKAGE"
        fi
    elif [[ "$OS_ID" =~ (almalinux|rocky|rhel|centos|cloudlinux) ]]; then
        if ! rpm -q "$PACKAGE" &>/dev/null; then
            echo "[INSTALL] $PACKAGE..."
            dnf install -y "$PACKAGE" || yum install -y "$PACKAGE"
        fi
    fi
}

install_pkg "util-linux"
install_pkg "zstd"
install_pkg "lz4"

# 7. Implementation
if [[ "$OS_ID" =~ (ubuntu|debian) ]]; then
    echo "[CONFIG] Applying Debian family optimization..."
    install_pkg "zram-tools"
    cat <<EOF > /etc/default/zramswap
# Managed by Private Devops LTD
ALGO=lz4
SIZE=${SIZE_RAW}000
PRIORITY=100
EOF
    systemctl restart zramswap || (echo "[FORCE] Module missing. Reinstalling kernel modules..." && apt-get install -y linux-modules-extra-$(uname -r) && systemctl restart zramswap)

elif [[ "$OS_ID" =~ (almalinux|rocky|rhel|centos|cloudlinux) ]]; then
    echo "[CONFIG] Applying RHEL family optimization..."
    modprobe zram 2>/dev/null
    ALGO="lzo"
    [ -f /sys/block/zram0/comp_algorithm ] && (grep -q "zstd" /sys/block/zram0/comp_algorithm && ALGO="zstd" || (grep -q "lz4" /sys/block/zram0/comp_algorithm && ALGO="lz4"))

    cat <<EOF > /etc/udev/rules.d/99-zram.rules
# Managed by Private Devops LTD
ACTION=="add", KERNEL=="zram0", ATTR{comp_algorithm}="$ALGO", ATTR{disksize}="${SIZE_RAW}G", RUN+="/usr/sbin/mkswap /dev/zram0", RUN+="/usr/sbin/swapon -p 100 /dev/zram0"
EOF
    modprobe -r zram 2>/dev/null && modprobe zram num_devices=1
    sleep 1
    if ! swapon --show | grep -q "/dev/zram0"; then
        /usr/sbin/mkswap /dev/zram0 &>/dev/null
        /usr/sbin/swapon -p 100 /dev/zram0 &>/dev/null
    fi
fi

# 8. Swappiness Optimization
echo "[CONFIG] Tuning swappiness for Private Devops standards..."
sysctl vm.swappiness=100 >/dev/null
echo "vm.swappiness=100" > /etc/sysctl.d/99-private-devops-zram.conf

# 9. Verification
echo "--- Final Status ---"
zramctl
swapon --show
free -m
echo "################################################################################"
echo "#          Infrastructure Optimized by Private Devops LTD.                     #"
echo "################################################################################"
