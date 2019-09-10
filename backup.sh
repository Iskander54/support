#!/bin/bash
WORKING_DIR=/home/alexlo/NIST/SATEVI
REMOTE=gdrive
BACKUP_DIR_GDRIVE=backups
#------------------------------------
#Shell script to backup mysql database to a shared repository (here google drive)
#To be used win crontab to automate the backups
#-------------------------------

log() {
    if [ "$#" -eq 0 ]; then
        echo "Illegal number of parameters, expected 2 parameters, given $#"
        echo "Param 1: Level of log (info|warning|error). Default is INFO"
        echo "Param 2: Message to log"
        exit 1
    fi
    if [ "$#" -eq 1 ]; then
        LEVEL="INFO"
    else
        LEVEL=$(echo $1 | tr "[:lower:]" "[:upper:]")
        shift
    fi
    printf "\033[36m%-20s |\033[0m [%s] [%s]: %s\n" "$(basename $0)" "$(date +"%m-%d-%y %T")" "$LEVEL" "$*"
}

dump_sql() {
    log "Start Dumping all databases"
    DUMP_FILE=/tmp/$(date '+%Y-%m-%d__%H-%M-%S').sql
    if [ "$#" -eq 1 ]; then
        DUMP_FILE=$1
    fi
    PASSWORD=$(cat $WORKING_DIR/docker-compose.yml | grep 'MYSQL_ROOT_PASSWORD' | cut -d '=' -f2)
    docker exec mysql sh -c "exec mysqldump --databases sate6 -u root -p'$PASSWORD'" > $DUMP_FILE
    log "Dump created: $DUMP_FILE"
}

run() {
    log "Upload $DUMP_FILE in $BACKUP_DIR_GDRIVE"
    rclone copy $DUMP_FILE $REMOTE:$BACKUP_DIR_GDRIVE
    rm -f /tmp/$DUMP_FILE 
}


delete_old_backup() {
    LAST_MONTH=$(date '+%Y-%m-%d' -d 'last month')
    log "Check if an old backup exists: $BACKUP_DIR_GDRIVE/$LAST_MONTH"
    if rclone ls $REMOTE:$BACKUP_DIR_GDRIVE/$LAST_MONTH; then
        log "Delete old backup: $BACKUP_DIR_GDRIVE/$LAST_MONTH"
        rclone delete $REMOTE:$BACKUP_DIR_GDRIVE/$LAST_MONTH
        rclone rmdir $REMOTE:$BACKUP_DIR_GDRIVE/$LAST_MONTH
    else
        log "There is no old backup to delete"
    fi
}
set -e
dump_sql
run
exit 0