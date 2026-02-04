#!/bin/bash
#
#       Copyrights Private Devops LTD. - https://privatedevops.com
#

#!/bin/bash
set -euo pipefail

#
# Copyrights Private Devops LTD. - https://privatedevops.com
#

DESTINATION="/root/sql"
CURDATE=$(date +"%Y-%m-%d_%H-%M")
RETENTION_DAYS=1

EXCLUDE_REGEX='^(information_schema|performance_schema|mysql|sys)$'

SLACKHOOKURL='https://hooks.slack.com/services/........'
HOSTNAME=$(/bin/hostname)

LOCKFILE="/var/run/mysql-backup.lock"

# acquire non-blocking lock
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    echo "[$HOSTNAME] MySQL backup already running, exiting."
    exit 0
fi

mkdir -p "$DESTINATION"

# function for slack alert
slack_alert() {
    local message="$1"
    curl -s -X POST --data-urlencode \
        'payload={"channel":"#alerts","text":"['"$HOSTNAME"'] '"$message"'"}' \
        "$SLACKHOOKURL"
}

mysql -N -e "SHOW DATABASES;" | grep -Ev "$EXCLUDE_REGEX" | while read -r db; do
    echo "[$(date)] Dumping MySQL DB: $db"

    if ! mysqldump --single-transaction --quick "$db" \
        | gzip > "$DESTINATION/${db}.${CURDATE}.sql.gz"; then

        echo "[$HOSTNAME] ERROR: Backup failed for database $db"

        slack_alert "MySQL backup FAILED for database: $db"

        exit 1
    fi
done

# cleanup old backups
find "$DESTINATION" -type f -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

exit 0
