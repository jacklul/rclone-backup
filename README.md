# rclone-backup

Simple script that uses [Rclone](https://rclone.org) to backup your important files to cloud service.

## Install

```bash
wget -O - https://raw.githubusercontent.com/jacklul/rclone-backup/master/install.sh | sudo bash
```

You must add Rclone remote called `remote` to `/etc/rclone-backup/rclone.conf` (`sudo rclone config --config /etc/rclone-backup/rclone.conf`) or set it with `REMOTE` variable in `/etc/rclone-backup/rclone-backup.conf`.

Filtering rules are in `/etc/rclone-backup/filter.list` - see [here](https://rclone.org/filtering/) for more information.

If there is something you need to do before every backup you can create `/etc/rclone-backup/pre.sh` script, it will be executed each time the task starts.  
Similarly you can use `/etc/rclone-backup/post.sh` script to do something after backup.

Any arguments passed to `rclone-backup` are passed to `rclone` command line or you can use `PARAMETERS` variable in `/etc/rclone-backup/rclone-backup.conf`!
