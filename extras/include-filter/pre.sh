#!/usr/bin/env bash

TMP_DIR="$(mktemp --directory --tmpdir=/tmp "rclone-backup.XXXXXXX")"
[ ! -d "$TMP_DIR" ] && { echo "Failed to create a temporary directory in /tmp"; exit 1; }

# Replace every '#include "FILE"' with the FILE contents
if [ -n "$FILTER_LIST" ] && grep -q '^#include "*"' "$FILTER_LIST"; then
    echo "Building filter list with added includes..."

    FILTER_LIST_NEW="$TMP_DIR/filter.list"

    while IFS= read -r line; do
        if [[ $line =~ \#include\ \"([^\"]+\.list)\" ]]; then
            filename="${BASH_REMATCH[1]}"

            if [[ $filename != /* && -f "$TMP_DIR/$filename" ]]; then
                filename="$TMP_DIR/$filename"
            fi

            if [ -f "$filename" ]; then
                cat "$filename"
                [[ $(tail -c1 "$filename" | wc -l) -eq 0 ]] && echo
                continue
            fi

            echo "File $filename not found - ignoring" >&2
        fi

        echo "$line"
    done < "$FILTER_LIST" > "$FILTER_LIST_NEW"

    FILTER_LIST="$FILTER_LIST_NEW"
fi
