#!/bin/sh

set -eu

DESTINATION="/storage/.config"
CONTAINERS_BACKUP="/var/media/Kodi_Storage/containers-backup"
HDD_SECRETS_FILE="/var/media/Kodi_Storage/secrets/libreelec.env"
DEPLOY_COMPOSE_FILE="$DESTINATION/docker-compose.yml"
DEPLOY_WEATHER_SCRIPT="$DESTINATION/scripts/feed_weather_db.sh"
DEPLOY_APP_PY="$DESTINATION/weather/app.py"

FOLDERS="weather scripts"

copy_required_file() {
    _src="$1"
    _dst="$2"

    if [ -f "$_src" ]; then
        cp "$_src" "$_dst"
        echo "Copied $_src -> $_dst"
    else
        echo "Warning: missing file $_src"
    fi
}

escape_dq() {
    printf '%s' "$1" | sed 's/[\\$"`]/\\&/g'
}

compose_bin() {
    if [ -x "/storage/compose/docker-compose" ]; then
        echo "/storage/compose/docker-compose"
        return 0
    fi

    if command -v docker-compose >/dev/null 2>&1; then
        command -v docker-compose
        return 0
    fi

    return 1
}

load_install_secrets() {
    if [ ! -f "$HDD_SECRETS_FILE" ]; then
        echo "Error: secrets file not found: $HDD_SECRETS_FILE"
        echo "Create /var/media/Kodi_Storage/secrets/libreelec.env before running distribute_files.sh"
        exit 1
    fi

    # shellcheck disable=SC1090
    . "$HDD_SECRETS_FILE"
}

render_compose_file() {
    _compose="$(compose_bin)" || {
        echo "Error: docker-compose binary not found"
        echo "Run ./install_addons.sh before ./distribute_files.sh"
        exit 1
    }

    if [ ! -f "$DEPLOY_COMPOSE_FILE" ]; then
        echo "Error: compose file missing at $DEPLOY_COMPOSE_FILE"
        exit 1
    fi

    "$_compose" --env-file "$HDD_SECRETS_FILE" -f "$DEPLOY_COMPOSE_FILE" config > "$DEPLOY_COMPOSE_FILE.rendered"

    mv "$DEPLOY_COMPOSE_FILE.rendered" "$DEPLOY_COMPOSE_FILE"
    echo "Rendered secrets into $DEPLOY_COMPOSE_FILE"
}

render_weather_script() {
    if [ ! -f "$DEPLOY_WEATHER_SCRIPT" ]; then
        echo "Warning: weather feeder script missing at $DEPLOY_WEATHER_SCRIPT"
        return 0
    fi

    _ws_ip="$(escape_dq "${WEATHER_STATION_IP:-192.168.1.100}")"
    _ws_port="$(escape_dq "${WEATHER_STATION_PORT:-80}")"
    _db_user="$(escape_dq "${WEATHER_DB_USER:-root}")"
    _db_pass="$(escape_dq "${WEATHER_DB_PASSWORD:-${MARIADB_ROOT_PASSWORD:-}}")"
    _db_name="$(escape_dq "${MARIADB_DATABASE:-WeatherData}")"

    awk \
        -v ws_ip="$_ws_ip" \
        -v ws_port="$_ws_port" \
        -v db_user="$_db_user" \
        -v db_pass="$_db_pass" \
        -v db_name="$_db_name" \
        'BEGIN { OFS="" }
        /^WEATHER_STATION_IP=/ { print "WEATHER_STATION_IP=\"", ws_ip, "\""; next }
        /^WEATHER_STATION_PORT=/ { print "WEATHER_STATION_PORT=\"", ws_port, "\""; next }
        /^DB_USER=/ { print "DB_USER=\"", db_user, "\""; next }
        /^DB_PASS=/ { print "DB_PASS=\"", db_pass, "\""; next }
        /^DB_NAME=/ { print "DB_NAME=\"", db_name, "\""; next }
        { print }' "$DEPLOY_WEATHER_SCRIPT" > "$DEPLOY_WEATHER_SCRIPT.rendered"

    mv "$DEPLOY_WEATHER_SCRIPT.rendered" "$DEPLOY_WEATHER_SCRIPT"
    chmod +x "$DEPLOY_WEATHER_SCRIPT" || true
    echo "Rendered secrets into $DEPLOY_WEATHER_SCRIPT"
}

render_app_py() {
    if [ ! -f "$DEPLOY_APP_PY" ]; then
        echo "Warning: weather app.py missing at $DEPLOY_APP_PY"
        return 0
    fi

    _db_host="$(escape_dq "${WEATHER_DB_HOST:-mariadb}")"
    _db_name="$(escape_dq "${MARIADB_DATABASE:-WeatherData}")"
    _db_user="$(escape_dq "${WEATHER_DB_USER:-root}")"
    _db_pass="$(escape_dq "${WEATHER_DB_PASSWORD:-${MARIADB_ROOT_PASSWORD:-}}")"
    _db_port="${WEATHER_DB_PORT:-3306}"

    sed \
        -e "s|@@WEATHER_DB_HOST@@|$_db_host|g" \
        -e "s|@@WEATHER_DB_NAME@@|$_db_name|g" \
        -e "s|@@WEATHER_DB_USER@@|$_db_user|g" \
        -e "s|@@WEATHER_DB_PASSWORD@@|$_db_pass|g" \
        -e "s|@@WEATHER_DB_PORT@@|$_db_port|g" \
        "$DEPLOY_APP_PY" > "$DEPLOY_APP_PY.rendered"

    mv "$DEPLOY_APP_PY.rendered" "$DEPLOY_APP_PY"
    echo "Rendered secrets into $DEPLOY_APP_PY"
}

if [ ! -d "$DESTINATION" ]; then
    echo "Error: destination folder missing: $DESTINATION"
    exit 1
fi

if [ -d "$CONTAINERS_BACKUP" ]; then
    echo "Copying containers backups from $CONTAINERS_BACKUP"
    rsync -av "$CONTAINERS_BACKUP"/ "$DESTINATION/"
else
    echo "Warning: containers backup folder missing: $CONTAINERS_BACKUP"
fi

echo "Copying repository folders to $DESTINATION"
for folder in $FOLDERS; do
    [ -z "$folder" ] && continue
    if [ -d "$folder" ]; then
        rm -rf "$DESTINATION/$folder"
        cp -r "$folder" "$DESTINATION/"
        echo "Copied folder: $folder"
    else
        echo "Warning: missing folder $folder"
    fi
done

echo "Copying top-level files"
copy_required_file "autostart.sh" "$DESTINATION/autostart.sh"
copy_required_file "docker-compose.yml" "$DESTINATION/docker-compose.yml"
copy_required_file "README.md" "$DESTINATION/README.md"

load_install_secrets
render_compose_file
render_weather_script
render_app_py

chmod +x "$DESTINATION/autostart.sh" 2>/dev/null || true
find "$DESTINATION/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo "Building custom Docker images"
_compose="$(compose_bin)" || {
    echo "Error: docker-compose binary not found, skipping image builds"
    _compose=""
}

if [ -n "$_compose" ]; then
    echo "Building weatherpage image..."
    "$_compose" -f "$DEPLOY_COMPOSE_FILE" build weatherpage
fi

echo "Updating crontabs..."
crontab crontab.reference

echo "Distribution completed"