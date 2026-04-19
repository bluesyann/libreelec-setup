#!/bin/sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/scripts/lib/logging.sh"

load_secrets
init_logger "autostart"

MUSIC_DIR="/var/media/Kodi_Storage/music"
STORAGE_ROOT="/var/media/Kodi_Storage"

wait_storage_ready() {
    while :; do
        if [ -d "$MUSIC_DIR" ] && ls "$MUSIC_DIR" >/dev/null 2>&1; then
            count="$(find "$MUSIC_DIR" -mindepth 1 -maxdepth 1 | wc -l)"
            if [ "$count" -gt 5 ]; then
                log_info "Storage ready with $count top-level music entries"
                return 0
            fi
        fi
        log_info "Waiting for storage to become readable"
        sleep 3
    done
}

power_cycle_hdd_if_missing() {
    if [ -e /dev/sda ]; then
        return 0
    fi

    log_warn "Disk /dev/sda missing, running gpio power cycle"
    pkill -9 -f gpioset >/dev/null 2>&1
    gpioset --daemonize -c gpiochip4 22=1
    sleep 5
    pkill -9 -f gpioset >/dev/null 2>&1
    gpioset --daemonize -c gpiochip4 22=0
    sleep 10
    log_info "GPIO power cycle completed"
}

launch_monitor() {
    _script="$1"
    _name="$2"

    if [ -x "$APP_ROOT/$_script" ]; then
        "$APP_ROOT/$_script" >> "$LOG_DIR/$_name.log" 2>&1 &
        log_info "Started $_script in background"
    else
        log_warn "Expected monitor script missing: $APP_ROOT/$_script"
    fi
}

log_info "Autostart sequence started"

chmod 666 /var/run/docker.sock 2>/dev/null || true

if ! timeout 300 power_cycle_hdd_if_missing; then
    log_warn "HDD power cycle timed out"
fi

if ! timeout 600 wait_storage_ready; then
    log_error "Storage readiness timeout, continuing anyway"
fi

hdparm -S 100 /dev/sda >/dev/null 2>&1 || log_warn "Failed to set disk standby timer on /dev/sda"

chown -R "${PUID:-1000}:${PGID:-1000}" "$STORAGE_ROOT" >/dev/null 2>&1 || log_warn "Failed to update ownership on $STORAGE_ROOT"
chmod -R 777 "$STORAGE_ROOT" >/dev/null 2>&1 || log_warn "Failed to update permissions on $STORAGE_ROOT"

sleep 60
if timeout 300 compose up -d 2>&1; then
    log_info "docker-compose stack started"
else
    log_error "docker-compose stack startup failed or timed out"
fi

sleep 20
launch_monitor "scripts/Restart_containers_on_error.sh" "restart_containers_on_error"
launch_monitor "scripts/Cups_management.sh" "cups_management"
launch_monitor "scripts/feed_weather_db.sh" "feed_weather_db"

log_info "Autostart sequence completed"
