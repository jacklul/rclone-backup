#!/usr/bin/env bash

[ "$UID" -eq 0 ] || { echo "Admin privileges required"; exit 1; }

set -e

SPATH=$(dirname "$0")
REQUIRED_FILES=( rclone-backup.sh rclone-backup.service rclone-backup.timer config.conf filter.list )
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

cp -v "$SPATH/rclone-backup.sh" /usr/local/bin/rclone-backup && chmod +x /usr/local/bin/rclone-backup

mkdir -vp /etc/rclone-backup

if [ ! -f "/etc/rclone-backup/filter.list" ]; then
	cp -v "$SPATH/filter.list" /etc/rclone-backup/filter.list
fi

if [ ! -f "/etc/rclone-backup/config.conf" ]; then
	cp -v "$SPATH/config.conf" /etc/rclone-backup/config.conf
fi

if [ ! -f "/etc/rclone-backup/rclone.conf" ]; then
	touch "/etc/rclone-backup/rclone.conf"
	chmod 640 "/etc/rclone-backup/rclone.conf"
fi

mkdir -vp /usr/local/lib/systemd/system

cp -v "$SPATH/rclone-backup.service" /usr/local/lib/systemd/system && chmod 644 /usr/local/lib/systemd/system/rclone-backup.service
cp -v "$SPATH/rclone-backup.timer" /usr/local/lib/systemd/system && chmod 644 /usr/local/lib/systemd/system/rclone-backup.timer

echo "Enable the timer with 'systemctl enable --now rclone-backup.timer'"
echo "Run 'sudo rclone config --config /etc/rclone-backup/rclone.conf' and set up a remote with name 'remote'!"
