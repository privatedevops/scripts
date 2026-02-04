#!/bin/bash
#
# Copyrights Private Devops LTD. - https://privatedevops.com
#

### CONFIG ###
URL="https://127.0.0.1:9200"
SERVICE="opensearch.service"   # или elasticsearch.service

# Auth (leave empty if not needed)
AUTH_USER=""
AUTH_PASS=""

# SSL options
USE_SSL=true
INSECURE_SSL=true

SLACKHOOKURL='https://hooks.slack.com/services/.........'

LOCKFILE="/var/run/search-restart.lock"
HOSTNAME=$(/bin/hostname)
### END CONFIG ###


# acquire non-blocking lock
exec 200>"$LOCKFILE"
if ! flock -n 200; then
    echo "[$HOSTNAME] Restart already in progress, exiting."
    exit 0
fi

# build curl options
CURL_OPTS=(-s -o /dev/null -w "%{http_code}")

[[ "$USE_SSL" == "true" && "$INSECURE_SSL" == "true" ]] && CURL_OPTS+=(-k)
[[ -n "$AUTH_USER" && -n "$AUTH_PASS" ]] && CURL_OPTS+=(-u "${AUTH_USER}:${AUTH_PASS}")

HTTP_STATUS=$(curl "${CURL_OPTS[@]}" "$URL")

if [[ "$HTTP_STATUS" != "200" ]]; then
    echo "[$HOSTNAME] $URL returned $HTTP_STATUS, restarting $SERVICE"

    if ! systemctl restart "$SERVICE"; then
        echo "[$HOSTNAME] $SERVICE restart FAILED"

        curl -s -X POST --data-urlencode \
            'payload={"channel":"#alerts","text":"['"$HOSTNAME"'] '"$SERVICE"' restart FAILED (HTTP '"$HTTP_STATUS"')"}' \
            "$SLACKHOOKURL"

        exit 1
    fi
fi

exit 0
