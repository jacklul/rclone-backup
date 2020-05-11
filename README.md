# Pi-hole backup to cloud

Simple script that uses [Rclone](https://rclone.org) to backup important files and lists to cloud service.

### Install

```bash
wget -q -O - https://raw.githubusercontent.com/jacklul/pihole-backup/master/install.sh | sudo bash
```

You must add Rclone remote called `remote` to `/etc/pihole-backup/rclone.conf` - `sudo rclone config --config /etc/pihole-backup/rclone.conf`.
