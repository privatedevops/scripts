#!/bin/bash

DB_NAME="** DB NAME HERE**"

function clean_up() {
    set -eux
    for snapshot in $(aws rds describe-db-snapshots --snapshot-type manual --query="sort_by(DBSnapshots, &SnapshotCreateTime)" | jq '.[].DBSnapshotIdentifier' | grep "${DB_NAME}-snapshot-" | head -n -30 | tr '"\r\n"' ' ') ; do
        echo $snapshot
        aws rds delete-db-snapshot --db-snapshot-identifier $snapshot
    done
}

function create_snapshot() {
    aws rds create-db-snapshot --db-instance-identifier ${DB_NAME} --db-snapshot-identifier ${DB_NAME}-snapshot-`date +'%Y%m%d%H%M%S'`
}

case $1 in
create)
    clean_up
    create_snapshot
;;
esac

