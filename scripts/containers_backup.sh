#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/logging.sh"

init_logger "containers_backup"

# use rsync to backup containers data on the external hdd

CONTAINERS_BACKUP="/var/media/Kodi_Storage/containers-backup/"
CONTAINERS_SOURCE="$APP_ROOT"

containers="cups lidarr navidrome qbittorrent syncthing joal mariadb prowlarr radarr"

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "docker-compose file not found at $COMPOSE_FILE"
    exit 1
fi

if ! compose_bin >/dev/null 2>&1; then
    log_error "docker-compose binary not found"
    exit 1
fi

log_info "Stopping compose stack"
if ! compose down; then
    log_error "Failed to stop compose stack"
    exit 1
fi

if [ -d "$CONTAINERS_BACKUP" ]; then
    for container in $containers; do
        sourcedir="$CONTAINERS_SOURCE/$container"
        log_info "Backing up $container directory $sourcedir"
        if [ -d "$sourcedir" ]; then
            rsync -av --delete "$sourcedir" "$CONTAINERS_BACKUP"
        else
            log_warn "$sourcedir missing"
        fi
    done
else
    log_warn "containers backup folder missing: $CONTAINERS_BACKUP"
fi

log_info "Starting compose stack"
if ! compose up -d; then
    log_error "Failed to start compose stack"
    exit 1
fi

log_info "Container backup completed"