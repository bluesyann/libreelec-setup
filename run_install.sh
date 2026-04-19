#!/bin/sh

set -eu

MODE="${1:-all}"
HDD_SECRETS_FILE="/var/media/Kodi_Storage/secrets/libreelec.env"
DEPLOY_SECRETS_FILE="/storage/.config/secrets/libreelec.env"
DEPLOY_COMPOSE_FILE="/storage/.config/docker-compose.yml"
DEPLOY_WEATHER_SCRIPT="/storage/.config/scripts/feed_weather_db.sh"


copy_secrets() {
	if [ ! -f "$HDD_SECRETS_FILE" ]; then
		echo "Error: secrets file not found on data drive: $HDD_SECRETS_FILE"
		echo "Create /var/media/Kodi_Storage/secrets/libreelec.env before running install."
		exit 1
	fi
	mkdir -p "$(dirname "$DEPLOY_SECRETS_FILE")"
	cp "$HDD_SECRETS_FILE" "$DEPLOY_SECRETS_FILE"
	echo "Copied secrets to $DEPLOY_SECRETS_FILE"
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

escape_sed_replacement() {
	printf '%s' "$1" | sed 's/[&@]/\\&/g'
}

render_compose_file() {
	_compose="$(compose_bin)" || {
		echo "Error: docker-compose binary not found"
		exit 1
	}

	if [ ! -f "$DEPLOY_COMPOSE_FILE" ]; then
		echo "Error: compose file missing at $DEPLOY_COMPOSE_FILE"
		exit 1
	fi

	"$_compose" --env-file "$DEPLOY_SECRETS_FILE" -f "$DEPLOY_COMPOSE_FILE" config > "$DEPLOY_COMPOSE_FILE.rendered"
	mv "$DEPLOY_COMPOSE_FILE.rendered" "$DEPLOY_COMPOSE_FILE"
	echo "Rendered secrets into $DEPLOY_COMPOSE_FILE"
}

render_weather_script() {
	if [ ! -f "$DEPLOY_WEATHER_SCRIPT" ]; then
		echo "Warning: weather feeder script missing at $DEPLOY_WEATHER_SCRIPT"
		return 0
	fi

	# shellcheck disable=SC1090
	. "$DEPLOY_SECRETS_FILE"

	_ws_ip="$(escape_sed_replacement "${WEATHER_STATION_IP:-192.168.1.100}")"
	_ws_port="$(escape_sed_replacement "${WEATHER_STATION_PORT:-80}")"
	_db_user="$(escape_sed_replacement "${WEATHER_DB_USER:-root}")"
	_db_pass="$(escape_sed_replacement "${WEATHER_DB_PASSWORD:-${MARIADB_ROOT_PASSWORD:-}}")"
	_db_name="$(escape_sed_replacement "${MARIADB_DATABASE:-WeatherData}")"

	sed \
		-e 's@^load_secrets$@: # secrets rendered during install@' \
		-e "s@^WEATHER_STATION_IP=.*$@WEATHER_STATION_IP=\"$_ws_ip\"@" \
		-e "s@^WEATHER_STATION_PORT=.*$@WEATHER_STATION_PORT=\"$_ws_port\"@" \
		-e "s@^DB_USER=.*$@DB_USER=\"$_db_user\"@" \
		-e "s@^DB_PASS=.*$@DB_PASS=\"$_db_pass\"@" \
		-e "s@^DB_NAME=.*$@DB_NAME=\"$_db_name\"@" \
		"$DEPLOY_WEATHER_SCRIPT" > "$DEPLOY_WEATHER_SCRIPT.rendered"
	mv "$DEPLOY_WEATHER_SCRIPT.rendered" "$DEPLOY_WEATHER_SCRIPT"
	chmod +x "$DEPLOY_WEATHER_SCRIPT" || true
	echo "Rendered secrets into $DEPLOY_WEATHER_SCRIPT"
}

render_runtime_configs() {
	render_compose_file
	render_weather_script
}

cleanup_install_secrets() {
	rm -f "$DEPLOY_SECRETS_FILE"
	echo "Removed install-time secrets file: $DEPLOY_SECRETS_FILE"
}

deploy_autostart() {
	if [ ! -f "autostart.sh" ]; then
		echo "Error: autostart.sh not found in repository root"
		exit 1
	fi
	cp "autostart.sh" "/storage/.config/autostart.sh"
	chmod +x "/storage/.config/autostart.sh" || true
	echo "Copied autostart.sh -> /storage/.config/autostart.sh"
}

run_phase1() {
	copy_secrets
	./install_addons.sh
	./distribute_files.sh
	render_runtime_configs
}

run_phase2() {
	copy_secrets
	deploy_autostart
	./kodi_settings.sh
	render_runtime_configs
	cleanup_install_secrets
}

case "$MODE" in
	all)
		run_phase1
		if command -v jq >/dev/null 2>&1; then
			run_phase2
		else
			echo "jq not available yet. Reboot LibreELEC, then run: ./run_install.sh post-reboot"
		fi
		;;
	pre-reboot)
		run_phase1
		;;
	post-reboot)
		run_phase2
		;;
	*)
		echo "Usage: ./run_install.sh [all|pre-reboot|post-reboot]"
		exit 1
		;;
esac