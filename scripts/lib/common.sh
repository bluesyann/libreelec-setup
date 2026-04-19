#!/bin/sh

# Common runtime helpers for LibreELEC background scripts.

# Keep docker-compose binaries from Kodi add-ons reachable.
PATH="/storage/bin:/usr/bin:/usr/sbin:/storage/.kodi/addons/docker.linuxserver.updater/bin:/storage/.kodi/addons/service.system.docker/bin:$PATH"
export PATH

APP_ROOT="${APP_ROOT:-/storage/.config}"
COMPOSE_FILE="${COMPOSE_FILE:-$APP_ROOT/docker-compose.yml}"
SECRETS_FILE="${SECRETS_FILE:-$APP_ROOT/secrets/libreelec.env}"
LOG_DIR="${LOG_DIR:-$APP_ROOT/logs}"

ensure_dir() {
    [ -d "$1" ] || mkdir -p "$1"
}

load_secrets() {
    if [ -f "$SECRETS_FILE" ]; then
        # shellcheck disable=SC1090
        . "$SECRETS_FILE"
    fi
}

compose_bin() {
    if [ -x "/storage/bin/docker-compose" ]; then
        echo "/storage/bin/docker-compose"
        return 0
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        command -v docker-compose
        return 0
    fi

    return 1
}

compose() {
    _bin="$(compose_bin)" || {
        echo "docker-compose not found in PATH" >&2
        return 127
    }

    "$_bin" -f "$COMPOSE_FILE" "$@"
}
