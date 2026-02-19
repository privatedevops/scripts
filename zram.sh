#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Script Name:    zRAM & OOM Guardian Tool (Private Devops Edition)
# Version:        1.16 - Stable Cross-Distro Production Fix
################################################################################

BANNER="
################################################################################
#                          PRIVATE DEVOPS LTD.                                 #
#                Full Cleanup & Memory Protection System                       #
################################################################################
"
echo "$BANNER"

# 1. Root check
[[ $EUID -ne 0 ]] && echo "Error: Root required!" && exit 1

# 2. Argument check
SIZE_ARG=${1:-}
[[ -z "$SIZE_ARG" ]] && echo "Usage: $0 3G" && exit 1

if ! BYTES=$(numfmt --from=iec "$SIZE_ARG" 2>/dev/null); then
    echo "Invalid size format (use 1G, 2048M, etc)"
    exit 1
fi

# 3. Detect OS
. /etc/os-release
OS_ID=$ID
OS_LIKE=${ID_LIKE:-}

echo "[INFO] OS: $OS_ID (like: $OS_LIKE), requested size: $SIZE_ARG"

# 4. DEEP CLEANUP
echo "[CLEANUP] Purging existing zram devices..."
swapoff -a 2>/dev/null || true

if command -v zramctl >/dev/null 2>&1; then
    for dev in /dev/zram*; do
        [[ -b $dev ]] && zramctl --reset "$dev" 2>/dev/null || true
    done
fi

rm -f /etc/udev/rules.d/99-zram.rules 2>/dev/null || true

# 5. Reload module safely
echo "[DEPS] Reloading kernel module..."
modprobe -r zram 2>/dev/null || true
modprobe zram num_devices=1 2>/dev/null || modprobe zram

sleep 0.2

if [[ ! -b /dev/zram0 ]]; then
    echo "[ERROR] Kernel failed to create /dev/zram0"
    exit 1
fi

################################################################################
# 6. Implementation
################################################################################

if [[ "$OS_ID" =~ (ubuntu|debian) ]] || [[ "$OS_LIKE" =~ (debian|ubuntu) ]]; then
    echo "[CONFIG] Setting up Debian/Ubuntu (zram-tools)..."

    apt-get update -y
    apt-get install -y zram-tools

    SIZE_MB=$((BYTES/1024/1024))

    cat > /etc/default/zramswap <<EOF
ALGO=lzo
SIZE=${SIZE_MB}
PRIORITY=100
EOF

    systemctl enable zramswap >/dev/null 2>&1 || true
    systemctl restart zramswap

elif [[ "$OS_ID" =~ (almalinux|rocky|rhel|centos|cloudlinux|fedora) ]] || \
     [[ "$OS_LIKE" =~ (rhel|centos|fedora) ]]; then

    echo "[CONFIG] Setting up RHEL-based system..."

    # Detect supported algorithm (do NOT force unsupported)
    ALGO=""
    if [[ -f /sys/block/zram0/comp_algorithm ]]; then
        if grep -q lz4 /sys/block/zram0/comp_algorithm; then
            ALGO="lz4"
        elif grep -q zstd /sys/block/zram0/comp_algorithm; then
            ALGO="zstd"
        elif grep -q lzo /sys/block/zram0/comp_algorithm; then
            ALGO="lzo"
        fi
    fi

    echo "[INFO] Using algorithm: ${ALGO:-default}"

    # Reset and configure
    zramctl --reset /dev/zram0

    if [[ -n "$ALGO" ]]; then
        zramctl --algorithm "$ALGO" --size "$BYTES" /dev/zram0
    else
        zramctl --size "$BYTES" /dev/zram0
    fi

    mkswap /dev/zram0 >/dev/null
    swapon -p 100 /dev/zram0

else
    echo "[ERROR] Unsupported OS"
    exit 1
fi

################################################################################
# 7. TUNING SYSCTL
################################################################################

echo "[TUNING] Applying Sysctl settings..."

cat > /etc/sysctl.d/99-private-devops-memory.conf <<EOF
vm.swappiness=10
vm.oom_kill_allocating_task=0
vm.overcommit_memory=1
vm.vfs_cache_pressure=100
EOF

sysctl --system >/dev/null 2>&1

################################################################################
# 8. Verify
################################################################################

echo "--- Final Check ---"
zramctl || true
swapon --show || true
free -m || true

echo "################################################################################"
echo "#          Infrastructure Optimized by Private Devops LTD.                     #"
echo "################################################################################"
