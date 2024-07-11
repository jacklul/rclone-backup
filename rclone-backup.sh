#!/usr/bin/env bash
# Made by Jack'lul <jacklul.github.io>

command -v rclone >/dev/null 2>&1 || { echo "Please install Rclone first!" >&2; exit 1; }

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--config-dir)
            CONFIG_DIR="$2"
            echo "Using configuration directory: $CONFIG_DIR"
            shift
            shift
            ;;
        -c|--config)
            NEW_CONFIG_FILE="$2"
            echo "Using configuration file: $NEW_CONFIG_FILE"
            shift
            shift
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

CONFIG_DIR="${CONFIG_DIR:-/etc/rclone-backup}"
CONFIG_FILE="${CONFIG_FILE:-$CONFIG_DIR/config.conf}"
RCLONE_CONFIG="$CONFIG_DIR/rclone.conf"
FILTER_LIST="$CONFIG_DIR/filter.list"
BASE_PATH="/"
REMOTE="remote:"
PARAMETERS=""
SCRIPT_PRE="$CONFIG_DIR/pre.sh"
SCRIPT_POST="$CONFIG_DIR/post.sh"

if [ -n "$NEW_CONFIG_FILE" ] && [ -f "$NEW_CONFIG_FILE" ]; then
    #shellcheck disable=SC1090
    . "$NEW_CONFIG_FILE"
elif [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    #shellcheck disable=SC1090
    . "$CONFIG_FILE"
fi

[ -f "$RCLONE_CONFIG" ] || { echo "Missing Rclone configuration: ${RCLONE_CONFIG:-(not set?)}" >&2; exit 1; }

OPTS=("--config=$RCLONE_CONFIG")

if [ -n "$FILTER_LIST" ] && [ -f "$FILTER_LIST" ]; then
    OPTS+=("--filter-from=$FILTER_LIST")
fi

# Running via systemd, disable progress and stats if present in the parameters
if [ -n "$INVOCATION_ID" ] || [ -n "$JOURNAL_STREAM" ]; then
    PARAMETERS=$(echo "$PARAMETERS " | sed 's/--progress //g' | sed -r 's/--stats [a-zA-Z0-9]+ //g')
fi

#shellcheck disable=SC2206
OPTS+=($PARAMETERS)

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
    LOCKFILE=/var/lock/$(basename "$0")
    LOCKPID=$(cat "$LOCKFILE" 2> /dev/null || echo '')

    if [ -e "$LOCKFILE" ] && [ -n "$LOCKPID" ] && kill -0 "$LOCKPID" > /dev/null 2>&1; then
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
    bash "$SCRIPT_PRE"
fi

echo "Backing up now..."

#shellcheck disable=SC2068
rclone sync "$BASE_PATH" "$REMOTE" "${OPTS[@]}" $@
EXITCODE=$?

if [ -n "$SCRIPT_POST" ] && [ -x "$SCRIPT_POST" ]; then
    echo "Executing script '$SCRIPT_POST'..."
    bash "$SCRIPT_POST" "$EXITCODE"
fi

if [ "$EXITCODE" -eq 0 ]; then
    echo "Finished successfully"
else
    echo "Finished with error code $EXITCODE"
fi
