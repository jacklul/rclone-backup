#!/bin/bash

[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

set -e
command -v rclone >/dev/null 2>&1 || { echo "This script requires Rclone to run, install it with 'wget -O - https://rclone.org/install.sh | sudo bash'."; }

SPATH=$(dirname $0)
REMOTE_URL=https://raw.githubusercontent.com/jacklul/rclone-backup/master

if [ -f "$SPATH/rclone-backup.sh" ] && [ -f "$SPATH/backup.list" ] && [ -f "$SPATH/rclone-backup.service" ] && [ -f "$SPATH/rclone-backup.timer" ]; then
	cp -v $SPATH/rclone-backup.sh /usr/local/sbin/rclone-backup && chmod +x /usr/local/sbin/rclone-backup
	
	mkdir -vp /etc/rclone-backup
	
	if [ ! -f "/etc/rclone-backup/backup.list" ]; then
		cp -v $SPATH/backup.list /etc/rclone-backup/backup.list
	fi
	
	cp -v $SPATH/rclone-backup.service /etc/systemd/system && chmod 644 /etc/systemd/system/rclone-backup.service
	cp -v $SPATH/rclone-backup.timer /etc/systemd/system && chmod 644 /etc/systemd/system/rclone-backup.timer
elif [ "$REMOTE_URL" != "" ]; then
	wget -nv -O /usr/local/sbin/rclone-backup "$REMOTE_URL/rclone-backup.sh" && chmod +x /usr/local/sbin/rclone-backup
	
	mkdir -vp /etc/rclone-backup
	
	if [ ! -f "/etc/rclone-backup/backup.list" ]; then
		wget -nv -O /etc/rclone-backup/backup.list "$REMOTE_URL/backup.list"
	fi
	
	wget -nv -O /etc/systemd/system/rclone-backup.service "$REMOTE_URL/rclone-backup.service" && chmod 644 /etc/systemd/system/rclone-backup.service
	wget -nv -O /etc/systemd/system/rclone-backup.timer "$REMOTE_URL/rclone-backup.timer" && chmod 644 /etc/systemd/system/rclone-backup.timer
else
	echo "Missing required files for installation!"
	exit 1
fi

echo "Enabling and starting rclone-backup.timer..."
systemctl enable rclone-backup.timer && systemctl start rclone-backup.timer

[ -f "/etc/rclone-backup/rclone.conf" ] || { echo "Please run 'sudo rclone config --config /etc/rclone-backup/rclone.conf' and set up a remote with name 'remote'!"; }
