#!/bin/bash
set -euo pipefail

#
# Copyrights Private Devops LTD. - https://privatedevops.com
#

HOSTNAME=$(/bin/hostname)

# ===== CONFIG =====
RETENTION_DAYS=6
BKPDIR="/backups/files"
SKIPFILES="/root/scripts/bkp_excludes.list"
SSHPORT="5698"

# Slack
SLACKHOOKURL="__SET_VIA_ENV_OR_SECRETS__"

# Parallel backup
PARALLEL=false          # true / false
MAX_PARALLEL=2          # used only if PARALLEL=true

# Servers (space separated via array)
SERVERS=(
  IP
  HOST
  IP2
  HOST2
)

# Override servers via CLI
if [[ $# -gt 0 ]]; then
    SERVERS=("$@")
fi
# ==================

DAY0=$(date -I)
DAY1=$(date -I -d "1 day ago")
DELFROM=$(date -I -d "$RETENTION_DAYS days ago")

LOCKFILE="/var/run/files-backup.lock"

# ---- LOCK ----
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    echo "[$HOSTNAME] Backup already running, exiting."
    exit 0
fi

# ---- Slack helper ----
slack_alert() {
    local server="$1"
    local message="$2"
    curl -s -X POST --data-urlencode \
        'payload={"channel":"#alerts","text":"['"$HOSTNAME"'] ['"$server"'] '"$message"'"}' \
        "$SLACKHOOKURL"
}

backup_server() {
    local server="$1"

    local BASEDIR="$BKPDIR/$server"
    local TARGET="$BASEDIR/$DAY0"
    local LINKDEST="$BASEDIR/$DAY1"
    local DELETE_DIR="$BASEDIR/$DELFROM"

    mkdir -p "$TARGET"

    local RSYNC_OPTS=(
        -avh
        --sparse
        --delete
        --numeric-ids
        --exclude-from="$SKIPFILES"
    )

    if [[ -d "$LINKDEST" ]]; then
        RSYNC_OPTS+=(--link-dest="$LINKDEST")
    fi

    echo "[$(date)] Starting backup for $server"

    if ! ionice -c2 -n7 rsync \
        "${RSYNC_OPTS[@]}" \
        -e "ssh -p $SSHPORT" \
        "$server:/" \
        "$TARGET"; then

        echo "[$HOSTNAME] ERROR: Backup failed for $server"
        slack_alert "$server" "File backup FAILED"
        return 1
    fi

    # cleanup ONLY after success
    if [[ -d "$DELETE_DIR" ]]; then
        rm -rf "$DELETE_DIR"
    fi

    echo "[$(date)] Backup completed for $server"
}

# ---- EXECUTION ----
if [[ "$PARALLEL" == "true" ]]; then
    echo "[$HOSTNAME] Running backups in PARALLEL mode (max $MAX_PARALLEL)"

    for server in "${SERVERS[@]}"; do
        backup_server "$server" &

        # limit parallel jobs
        while [[ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]]; do
            sleep 1
        done
    done

    wait
else
    echo "[$HOSTNAME] Running backups in SERIAL mode"

    for server in "${SERVERS[@]}"; do
        backup_server "$server"
    done
fi

exit 0
