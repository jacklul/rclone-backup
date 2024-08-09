#!/usr/bin/env bash

TMP_DIR="$(mktemp --directory --tmpdir=/tmp "rclone-backup.XXXXXXX")"
[ ! -d "$TMP_DIR" ] && { echo "Failed to create a temporary directory in /tmp"; exit 1; }

# Generate localized XDG filter list per user when '#include "xdg.list"' is in the filter file
#shellcheck disable=SC1091
if [ -n "$FILTER_LIST" ] && grep -q '^#include "xdg.list"' "$FILTER_LIST"; then
    echo "Generating list of XDG user directories..."

    # Hardcoded defaults
    DESKTOP=Desktop
    DOWNLOAD=Downloads
    TEMPLATES=Templates
    PUBLICSHARE=Public
    DOCUMENTS=Documents
    MUSIC=Music
    PICTURES=Pictures
    VIDEOS=Videos

    # Fetch defaults (xdg-user-dirs package)
    [ -f /etc/xdg/user-dirs.defaults ] && source /etc/xdg/user-dirs.defaults

    # Create empty file for the list
    :> "$TMP_DIR/xdg.list"

    # Itarate over /home directories and generate list of XDG dirs to include
    for dir in /home/*/; do
        [[ -L "${dir%/}" || ! -d "${dir%/}" ]] && continue
        user=$(basename "$dir")

        echo "Processing for $user..."

        XDG_DESKTOP_DIR="$DESKTOP"
        XDG_DOCUMENTS_DIR="$DOCUMENTS"
        XDG_DOWNLOAD_DIR="$DOWNLOAD"
        XDG_MUSIC_DIR="$MUSIC"
        XDG_PICTURES_DIR="$PICTURES"
        XDG_PUBLICSHARE_DIR="$PUBLICSHARE"
        XDG_TEMPLATES_DIR="$TEMPLATES"
        XDG_VIDEOS_DIR="$VIDEOS"

        [ -f "$dir/.config/user-dirs.dirs"  ] && source "$dir/.config/user-dirs.dirs"

        XDG_DESKTOP_DIR="${XDG_DESKTOP_DIR/#$HOME\//}"
        XDG_DOCUMENTS_DIR="${XDG_DOCUMENTS_DIR/#$HOME\//}"
        XDG_DOWNLOAD_DIR="${XDG_DOWNLOAD_DIR/#$HOME\//}"
        XDG_MUSIC_DIR="${XDG_MUSIC_DIR/#$HOME\//}"
        XDG_PICTURES_DIR="${XDG_PICTURES_DIR/#$HOME\//}"
        XDG_PUBLICSHARE_DIR="${XDG_PUBLICSHARE_DIR/#$HOME\//}"
        XDG_TEMPLATES_DIR="${XDG_TEMPLATES_DIR/#$HOME\//}"
        XDG_VIDEOS_DIR="${XDG_VIDEOS_DIR/#$HOME\//}"

        # Note that Downloads and Public folders are ignored by default
        # Modify here to override this
        cat >> "$TMP_DIR/xdg.list" <<EOF
+ /home/$user/$XDG_DESKTOP_DIR/**
+ /home/$user/$XDG_DOCUMENTS_DIR/**
- /home/$user/$XDG_DOWNLOAD_DIR/
#+ /home/$user/$XDG_DOWNLOAD_DIR/**
+ /home/$user/$XDG_MUSIC_DIR/**
+ /home/$user/$XDG_PICTURES_DIR/**
- /home/$user/$XDG_PUBLICSHARE_DIR/
#+ /home/$user/$XDG_PUBLICSHARE_DIR/**
+ /home/$user/$XDG_TEMPLATES_DIR/**
+ /home/$user/$XDG_VIDEOS_DIR/**
EOF
    done
fi

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
