#!/usr/bin/env bash
# Made by Jack'lul <jacklul.github.io>

command -v rclone >/dev/null 2>&1 || { echo "Please install Rclone first!" >&2; exit 1; }

positional_args=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--config-dir)
            CONFIG_DIR="$2"
            echo "Using configuration directory: $CONFIG_DIR"
            shift
            shift
            ;;
        -c|--config)
            new_config_file="$2"
            echo "Using configuration file: $new_config_file"
            shift
            shift
            ;;
        *)
            positional_args+=("$1")
            shift
            ;;
    esac
done

set -- "${positional_args[@]}"

CONFIG_DIR="${CONFIG_DIR:-/etc/rclone-backup}"
CONFIG_FILE="${CONFIG_FILE:-$CONFIG_DIR/config.conf}"
RCLONE_CONFIG="$CONFIG_DIR/rclone.conf"
FILTER_LIST="$CONFIG_DIR/filter.list"
BASE_PATH="/"
REMOTE="remote:"
PARAMETERS=""
SCRIPT_PRE="$CONFIG_DIR/pre.sh"
SCRIPT_POST="$CONFIG_DIR/post.sh"
LOCKFILE="/var/lock/$(basename "$0")"

if [ -n "$new_config_file" ] && [ -f "$new_config_file" ]; then
    #shellcheck disable=SC1090
    . "$new_config_file"
elif [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    #shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

[ -f "$RCLONE_CONFIG" ] || { echo "Missing Rclone configuration: ${RCLONE_CONFIG:-(not set?)}" >&2; exit 1; }
[ -f "$FILTER_LIST" ] || { echo "Missing filter list: ${FILTER_LIST:-(not set?)}" >&2; exit 1; }

if [ "$UID" -eq 0 ]; then
    lockpid=$(cat "$LOCKFILE" 2> /dev/null || echo '')

    if [ -e "$LOCKFILE" ] && [ -n "$lockpid" ] && kill -0 "$lockpid" > /dev/null 2>&1; then
        echo "Script is already running!" >&2
        exit 6
    fi

    echo $$ > "$LOCKFILE"

    function onInterruptOrExit() {
        rm "$LOCKFILE" >/dev/null 2>&1
    }
    trap onInterruptOrExit EXIT
fi

if [ -n "$SCRIPT_PRE" ] && [ -x "$SCRIPT_PRE" ]; then
    echo "Executing script '$SCRIPT_PRE'..."

    #shellcheck disable=SC1090
    . "$SCRIPT_PRE"
fi

# Running via systemd, disable progress and stats if present in the parameters
if [ -n "$INVOCATION_ID" ] || [ -n "$JOURNAL_STREAM" ]; then
    PARAMETERS=$(echo "$PARAMETERS " | sed 's/--progress //g' | sed -r 's/--stats [a-zA-Z0-9]+ //g')
fi

echo "Backing up now..."

#shellcheck disable=SC2086
rclone sync "$BASE_PATH" "$REMOTE" --config="$RCLONE_CONFIG" --filter-from="$FILTER_LIST" $PARAMETERS "$@"
exitcode=$?

if [ -n "$SCRIPT_POST" ] && [ -x "$SCRIPT_POST" ]; then
    echo "Executing script '$SCRIPT_POST'..."

    #shellcheck disable=SC1090
    . "$SCRIPT_POST" "$exitcode"
fi

if [ "$exitcode" -eq 0 ]; then
    echo "Finished successfully"
else
    echo "Finished with error code $exitcode"
fi
