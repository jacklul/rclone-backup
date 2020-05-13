#!/bin/bash

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
	exec sudo -- "$0" "$@"
	exit
fi

set -e
[ -d "/etc/pihole" ] && [ -d "/opt/pihole" ] || { echo "Pi-hole doesn't seem to be installed"; exit 1; }
command -v rclone >/dev/null 2>&1 || { echo "This script requires Rclone to run, install it with 'wget -O - https://rclone.org/install.sh | sudo bash'."; }
command -v sqlite3 >/dev/null 2>&1 || { echo "This script requires sqlite3 to run, install it with 'sudo apt install sqlite3'."; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo "This script requires md5sum to run, install it with 'sudo apt install md5sum'."; exit 1; }

SPATH=$(dirname $0)
REMOTE_URL=https://raw.githubusercontent.com/jacklul/pihole-backup/master

if [ -f "$SPATH/pihole-backup.sh" ] && [ -f "$SPATH/backup.list" ] && [ -f "$SPATH/pihole-backup.service" ] && [ -f "$SPATH/pihole-backup.timer" ]; then
	cp -v $SPATH/pihole-backup.sh /usr/local/sbin/pihole-backup && \
	chmod +x /usr/local/sbin/pihole-backup
	mkdir -vp /etc/pihole-backup
	
	if [ ! -f "/etc/pihole-backup/backup.list" ]; then
		cp -v $SPATH/backup.list /etc/pihole-backup/backup.list
	fi
	
	cp -v $SPATH/pihole-backup.service /etc/systemd/system
	cp -v $SPATH/pihole-backup.timer /etc/systemd/system
elif [ "$REMOTE_URL" != "" ]; then
	wget -nv -O /usr/local/sbin/pihole-backup "$REMOTE_URL/pihole-backup.sh" && \
	chmod +x /usr/local/sbin/pihole-backup
	mkdir -vp /etc/pihole-backup
	
	if [ ! -f "/etc/pihole-backup/backup.list" ]; then
		wget -nv -O /etc/pihole-backup/backup.list "$REMOTE_URL/backup.list"
	fi
	
	wget -nv -O /etc/systemd/system/pihole-backup.service "$REMOTE_URL/pihole-backup.service"
	wget -nv -O /etc/systemd/system/pihole-backup.timer "$REMOTE_URL/pihole-backup.timer"
else
	exit 1
fi

echo "Enabling and starting pihole-backup.timer..."
systemctl enable pihole-backup.timer && systemctl start pihole-backup.timer

[ -f "/etc/pihole-backup/rclone.conf" ] || { echo "Please run 'sudo rclone config --config /etc/pihole-backup/rclone.conf' and set up a remote with name 'remote'!"; }
