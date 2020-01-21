#!/bin/bash
# This script backups Pi-hole configuration 
# and all lists to cloud service supported by Rclone

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
	exec sudo -- "$0" "$@"
	exit
fi

LOCKFILE=/tmp/$(basename $0).lock
CONFIG_DIR=/etc/pihole-backup
CONFIG_FILE=${CONFIG_DIR}/pihole-backup.conf
RCLONE_CONFIG=${CONFIG_DIR}/rclone.conf
INCLUDE_LIST=${CONFIG_DIR}/backup.list
PIHOLE_CONFIG_DIR=/etc/pihole
GRAVITY_FILE=${PIHOLE_CONFIG_DIR}/gravity.db
GRAVITY_MIN_FILE=${PIHOLE_CONFIG_DIR}/gravity.min.db

if [ -f "${CONFIG_FILE}" ]; then
	. ${CONFIG_FILE}
fi

if [ ! -f "$LOCKFILE" ]; then
	touch $LOCKFILE
else
	echo "Already running. (LOCKFILE: ${LOCKFILE})"
	exit 6
fi

function onInterruptOrExit() {
	rm "$LOCKFILE" >/dev/null 2>&1
}
trap onInterruptOrExit EXIT

command -v rclone >/dev/null 2>&1 || { echo "Please install Rclone!"; exit 1; }

[ -f "$RCLONE_CONFIG" ] || { echo "Rclone configuration missing!"; exit 1; }
[ ! -f "$INCLUDE_LIST" ] && touch $INCLUDE_LIST_USER

if [ -f "${GRAVITY_FILE}" ]; then
	echo "Minimizing gravity.db into gravity.min.db..."
	cp -f ${GRAVITY_FILE} ${GRAVITY_MIN_FILE}
	sqlite3 ${GRAVITY_MIN_FILE} "DELETE FROM gravity; VACUUM;"
fi

echo "Backing up now..."

renice -n -20 $$ > /dev/null
rclone sync --verbose --copy-links \
	--config "$RCLONE_CONFIG" \
	--include-from="$INCLUDE_LIST" \
	/ remote: \
	&& echo "Finished successfully"
