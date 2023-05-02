Add this to the filter list:

```
# dpkg installed packages list
+ /var/lib/dpkg/installed.txt
```

and this `/etc/rclone-backup/script.sh`:

```bash
#!/bin/bash

PACKAGES_LIST_FILE="/var/lib/dpkg/installed.txt"
PACKAGES_LIST_TMP_FILE="/tmp/dpkg-l.txt"

command -v md5sum >/dev/null 2>&1 || { echo "Please install 'md5sum' package!"; exit 1; }

dpkg -l > "$PACKAGES_LIST_TMP_FILE"

if [ "$(md5sum "$PACKAGES_LIST_TMP_FILE" | awk '{ print $1 }')" != "$(md5sum "$PACKAGES_LIST_FILE" | awk '{ print $1 }')" ]; then
    echo "Putting list of installed packages to $PACKAGES_LIST_FILE"

    mv -f "$PACKAGES_LIST_TMP_FILE" "$PACKAGES_LIST_FILE"
else
    rm -f "$PACKAGES_LIST_TMP_FILE"
fi

```
