#!/bin/bash

[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

set -e
command -v rclone >/dev/null 2>&1 || { echo "This script requires Rclone to run, install it with 'wget -O - https://rclone.org/install.sh | sudo bash'."; }

SPATH=$(dirname "$0")
REQUIRED_FILES=( rclone-backup.sh rclone-backup.service rclone-backup.timer rclone-backup.conf backup.list )
DOWNLOAD_PATH=/tmp/rclone-backup
DOWNLOAD_URL=https://raw.githubusercontent.com/jacklul/rclone-backup/master

set -e

MISSING_FILES=0
for FILE in "${REQUIRED_FILES[@]}"; do
	if [ ! -f "$SPATH/$FILE" ]; then
		MISSING_FILES=$((MISSING_FILES+1))
	fi
done

if [ "$MISSING_FILES" -gt 0 ]; then
    if [ "$MISSING_FILES" = "${#REQUIRED_FILES[@]}" ]; then
        mkdir -pv "$DOWNLOAD_PATH"
        SPATH="$DOWNLOAD_PATH"
    fi

	for FILE in "${REQUIRED_FILES[@]}"; do
		if [ ! -f "$SPATH/$FILE" ]; then
			wget -nv -O "$SPATH/$FILE" "$DOWNLOAD_URL/$FILE"
		fi
	done
fi

for FILE in "${REQUIRED_FILES[@]}"; do
	if [ ! -f "$SPATH/$FILE" ]; then
		echo "Missing required file for installation: $FILE"
		exit 1
	fi
done

cp -v "$SPATH/rclone-backup.sh" /usr/local/sbin/rclone-backup && chmod +x /usr/local/sbin/rclone-backup

mkdir -vp /etc/rclone-backup

if [ ! -f "/etc/rclone-backup/backup.list" ]; then
	cp -v "$SPATH/backup.list" /etc/rclone-backup/backup.list
fi

cp -v "$SPATH/rclone-backup.service" /etc/systemd/system && chmod 644 /etc/systemd/system/rclone-backup.service
cp -v "$SPATH/rclone-backup.timer" /etc/systemd/system && chmod 644 /etc/systemd/system/rclone-backup.timer

echo "Enabling and starting rclone-backup.timer..."
systemctl enable rclone-backup.timer && systemctl start rclone-backup.timer

[ -f "/etc/rclone-backup/rclone.conf" ] || { echo "Please run 'sudo rclone config --config /etc/rclone-backup/rclone.conf' and set up a remote with name 'remote'!"; }
