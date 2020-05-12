#!/bin/bash
# This script backups Pi-hole configuration 
# and all lists to cloud service supported by Rclone

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
	exec sudo -- "$0" "$@"
	exit
fi

LOCKFILE=/var/lock/$(basename $0)
CONFIG_DIR=/etc/pihole-backup
CONFIG_FILE=${CONFIG_DIR}/pihole-backup.conf
RCLONE_CONFIG_FILE=${CONFIG_DIR}/rclone.conf
BACKUP_LIST_FILE=${CONFIG_DIR}/backup.list
PIHOLE_CONFIG_DIR=/etc/pihole
GRAVITYDB_FILE=${PIHOLE_CONFIG_DIR}/gravity.db
GRAVITYDB_MIN_FILE=${PIHOLE_CONFIG_DIR}/gravity.min.db

if [ -f "${CONFIG_FILE}" ]; then
	. ${CONFIG_FILE}
fi

command -v rclone >/dev/null 2>&1 || { echo "Please install Rclone!"; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo "Please install md5sum!"; exit 1; }

PID=$(cat ${LOCKFILE} 2> /dev/null || echo '')
if [ -e ${LOCKFILE} ] && [ ! -z "$PID" ] && kill -0 $PID; then
    echo "Script is already running!"
    exit 6
fi

echo $$ > ${LOCKFILE}

function onInterruptOrExit() {
	rm "$LOCKFILE" >/dev/null 2>&1
}
trap onInterruptOrExit EXIT

[ -f "$RCLONE_CONFIG_FILE" ] || { echo "Missing Rclone configuration: $RCLONE_CONFIG_FILE"; exit 1; }
[ -f "$BACKUP_LIST_FILE" ] || { echo "Missing backup list file: $BACKUP_LIST_FILE"; exit 1; }

if [ -f "${GRAVITYDB_FILE}" ]; then
	PREVIOUS_CHECKSUM=
	if [ -f "${GRAVITYDB_MIN_FILE}.cache" ]; then
		PREVIOUS_CHECKSUM=`cat "${GRAVITYDB_MIN_FILE}.cache"`
	fi

	CURRENT_CHECKSUM=`md5sum ${GRAVITYDB_FILE} | awk '{ print $1 }'`

	if [ "${CURRENT_CHECKSUM}" != "${PREVIOUS_CHECKSUM}" ]; then
		echo "Minimizing gravity database file size..."
		
		cp -f ${GRAVITYDB_FILE} ${GRAVITYDB_MIN_FILE}
		sqlite3 ${GRAVITYDB_MIN_FILE} "DELETE FROM gravity; VACUUM;"
		
		echo ${CURRENT_CHECKSUM} > "${GRAVITYDB_MIN_FILE}.cache"
	fi
fi

echo "Backing up now..."

renice -n -20 $$ > /dev/null
rclone sync --verbose --copy-links \
	--config "$RCLONE_CONFIG_FILE" \
	--include-from="$BACKUP_LIST_FILE" \
	/ remote: \
	&& echo "Finished successfully"
