#!/bin/sh

# Lightweight file logger for BusyBox shell scripts.

LOGGER_NAME="script"
LOG_FILE=""

_ts() {
    date +"%Y-%m-%d %H:%M:%S"
}

init_logger() {
    LOGGER_NAME="$1"

    if [ -z "$LOG_DIR" ]; then
        LOG_DIR="/storage/.config/logs"
    fi

    ensure_dir "$LOG_DIR"
    LOG_FILE="$LOG_DIR/$LOGGER_NAME.log"

    # Simple rotation at 1 MiB.
    if [ -f "$LOG_FILE" ]; then
        _size="$(wc -c < "$LOG_FILE" 2>/dev/null)"
        if [ -n "$_size" ] && [ "$_size" -gt 1048576 ]; then
            mv "$LOG_FILE" "$LOG_FILE.1"
        fi
    fi
}

_log() {
    _level="$1"
    shift
    _msg="$*"

    _line="[$(_ts)] [$LOGGER_NAME] [$_level] $_msg"
    echo "$_line" >> "$LOG_FILE"
    echo "$_line"
}

log_info() {
    _log INFO "$@"
}

log_warn() {
    _log WARN "$@"
}

log_error() {
    _log ERROR "$@"
}
