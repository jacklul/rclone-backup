# rclone-backup

Simple script that uses [Rclone](https://rclone.org) to backup your important files to cloud service.

Extra: [Setup for Pi-hole](/Pi-hole.md)

### Install for Linux

```bash
wget -O - https://raw.githubusercontent.com/jacklul/rclone-backup/master/install.sh | sudo bash
```

You must add Rclone remote called `remote` to `/etc/rclone-backup/rclone.conf` - `sudo rclone config --config /etc/rclone-backup/rclone.conf`.

Filtering rules are in `/etc/rclone-backup/backup.list` - see [here](https://rclone.org/filtering/) for more information.

If there is something you need to do before every backup you can create `/etc/rclone-backup/script.sh` script, it will be executed each time the task starts.

Any arguments passed to `rclone-backup` are passed to `rclone` command line or you can use `EXTRA_PARAMETERS` config variable!

### Install for Windows

See [here](/windows).
