#!/bin/sh

set -eu

MODE="${1:-all}"
HDD_SECRETS_FILE="/var/media/Kodi_Storage/secrets/libreelec.env"
DEPLOY_SECRETS_FILE="/storage/.config/secrets/libreelec.env"


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
}

run_phase2() {
	copy_secrets
	deploy_autostart
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