#!/bin/sh

set -eu

MODE="${1:-all}"
DEPLOY_COMPOSE_FILE="/storage/.config/docker-compose.yml"
DEPLOY_SECRETS_FILE="/storage/.config/secrets/libreelec.env"

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

warm_up_containers() {
	_compose="$(compose_bin)" || {
		echo "docker-compose not found, skipping container warm-up"
		return 0
	}

	if [ ! -f "$DEPLOY_COMPOSE_FILE" ]; then
		echo "Compose file not found at $DEPLOY_COMPOSE_FILE, skipping warm-up"
		return 0
	fi

	if [ -f "$DEPLOY_SECRETS_FILE" ]; then
		# shellcheck disable=SC1090
		. "$DEPLOY_SECRETS_FILE"
	fi

	echo "Pulling container images before reboot"
	"$_compose" -f "$DEPLOY_COMPOSE_FILE" pull || echo "Warning: image pull had errors"

	echo "Starting containers once before reboot"
	"$_compose" -f "$DEPLOY_COMPOSE_FILE" up -d || echo "Warning: some containers failed to start"
}

run_phase1() {
	./install_addons.sh
	./distribute_files.sh --no-autostart
	warm_up_containers
}

run_phase2() {
	./distribute_files.sh --with-autostart
	./kodi_settings.sh
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