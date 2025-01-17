#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Exclude system databases
EXCLUDE="^(information_schema|performance_schema|mysql|sys)$"
DESTINATION=/root/sql/
CURDATE=$(date +"%d-%m-%Y-%Hh%Mm")

# Ensure the destination directory exists
if [ ! -d "$DESTINATION" ]; then
    echo -e "${YELLOW}Creating destination directory: $DESTINATION${NC}"
    mkdir -p "$DESTINATION"
fi

# Get the list of databases excluding system databases
DATABASES=$(mysql -e 'show databases' -s --skip-column-names | grep -Ev "$EXCLUDE")

# Loop through databases
for db in $DATABASES; do
    echo -e "${CYAN}Dumping MySQL DB: $db${NC}"

    if [[ "$db" == "zabbix" ]]; then
        echo -e "${YELLOW}Special handling for Zabbix database${NC}"

        # Dump all non-history tables
        echo -e "${CYAN}Dumping Zabbix tables excluding history...${NC}"
        if mysqldump --single-transaction --quick --events \
            --ignore-table=$db.history \
            --ignore-table=$db.history_uint \
            --ignore-table=$db.history_text \
            --ignore-table=$db.history_log \
            --ignore-table=$db.history_str \
            $db | gzip > "$DESTINATION/$db.$CURDATE.no_history.sql.gz"; then
            echo -e "${GREEN}Non-history tables dumped successfully${NC}"
        else
            echo -e "${RED}Failed to dump non-history tables${NC}"
        fi

        # Dump history tables with last week's data only
        for table in history history_uint history_text history_log history_str; do
            echo -e "${CYAN}Dumping last week's data for table: $table${NC}"
            if mysqldump --single-transaction --quick --events \
                $db $table --where="clock > UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 WEEK))" | gzip > "$DESTINATION/$db.$table.$CURDATE.last_week.sql.gz"; then
                echo -e "${GREEN}Table $table dumped successfully${NC}"
            else
                echo -e "${RED}Failed to dump table $table${NC}"
            fi
        done
    else
        # Dump other databases normally
        echo -e "${CYAN}Dumping normal database: $db${NC}"
        if mysqldump --single-transaction --quick --events $db | gzip > "$DESTINATION/$db.$CURDATE.sql.gz"; then
            echo -e "${GREEN}Database $db dumped successfully${NC}"
        else
            echo -e "${RED}Failed to dump database $db${NC}"
        fi
    fi
done

# Keep only the last 24 hours of backups
echo -e "${CYAN}Cleaning up old backups...${NC}"
find "$DESTINATION" -type f -mtime +1 -exec rm -f {} \;
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Old backups cleaned successfully${NC}"
else
    echo -e "${RED}Failed to clean old backups${NC}"
fi
