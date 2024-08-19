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

opts=("--config=$RCLONE_CONFIG")

if [ -n "$FILTER_LIST" ] && [ -f "$FILTER_LIST" ]; then
    opts+=("--filter-from=$FILTER_LIST")
fi

# Running via systemd, disable progress and stats if present in the parameters
if [ -n "$INVOCATION_ID" ] || [ -n "$JOURNAL_STREAM" ]; then
    PARAMETERS=$(echo "$PARAMETERS " | sed 's/--progress //g' | sed -r 's/--stats [a-zA-Z0-9]+ //g')
fi

#shellcheck disable=SC2206
opts+=($PARAMETERS)

if [ -n "$RCLONE_CONFIG_FILE" ]; then
    echo "RCLONE_CONFIG_FILE is deprecated, use RCLONE_CONFIG instead" >&2
    RCLONE_CONFIG="$RCLONE_CONFIG_FILE"
fi

if [ -n "$FILTER_LIST_FILE" ]; then
    echo "FILTER_LIST_FILE is deprecated, use FILTER_LIST instead" >&2
    FILTER_LIST="$FILTER_LIST_FILE"
fi

if [ -n "$EXECUTE_SCRIPT" ]; then
    echo "EXECUTE_SCRIPT is deprecated, use SCRIPT_PRE instead" >&2
    SCRIPT_PRE="$EXECUTE_SCRIPT"
fi

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

echo "Backing up now..."

#shellcheck disable=SC2068
rclone sync "$BASE_PATH" "$REMOTE" "${opts[@]}" $@
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
