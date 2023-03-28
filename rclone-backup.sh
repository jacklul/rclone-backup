#!/bin/bash

[ "$UID" -eq 0 ] || { echo "This script must run as root!"; exit 1; }

command -v rclone >/dev/null 2>&1 || { echo "Please install Rclone - https://rclone.org!"; exit 1; }

CONFIG_DIR=/etc/rclone-backup
CONFIG_FILE=${CONFIG_DIR}/rclone-backup.conf
RCLONE_CONFIG_FILE=${CONFIG_DIR}/rclone.conf
FILTER_LIST_FILE=${CONFIG_DIR}/backup.list
EXECUTE_SCRIPT=${CONFIG_DIR}/script.sh
REMOTE=remote:
PARAMETERS=
LOCKFILE=/var/lock/$(basename $0)

if [ -f "${CONFIG_FILE}" ]; then
	#shellcheck disable=SC1090
	. "${CONFIG_FILE}"
fi

LOCKPID=$(cat "$LOCKFILE"} 2> /dev/null || echo '')
if [ -e "$LOCKFILE" ] && [ ! -z "$LOCKPID" ] && kill -0 "$LOCKPID" > /dev/null 2>&1; then
    echo "Script is already running!"
    exit 6
fi

echo $$ > "$LOCKFILE"

function onInterruptOrExit() {
	rm "$LOCKFILE" >/dev/null 2>&1
}
trap onInterruptOrExit EXIT

[ -f "$RCLONE_CONFIG_FILE" ] || { echo "Missing Rclone configuration: $RCLONE_CONFIG_FILE"; exit 1; }
[ -f "$FILTER_LIST_FILE" ] || { echo "Missing filter file: $FILTER_LIST_FILE"; exit 1; }

if [ "$EXECUTE_SCRIPT" != "" ] && [ -f "$EXECUTE_SCRIPT" ]; then
	echo "Executing script '$EXECUTE_SCRIPT'..."
	bash "$EXECUTE_SCRIPT"
fi

if [ ! -z "$LAUNCHED_BY_SYSTEMD" ]; then
	PARAMETERS=$(echo "$PARAMETERS " | sed 's/--progress //g' | sed -r 's/--stats [a-zA-Z0-9]+ //g')
fi

echo "Backing up now..."

#shellcheck disable=SC2086,SC2068
rclone sync --config "$RCLONE_CONFIG_FILE" \
	--filter-from="$FILTER_LIST_FILE" \
	/ "$REMOTE" \
	$PARAMETERS \
	$@ \
	&& echo "Finished successfully"
