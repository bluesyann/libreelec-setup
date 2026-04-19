#!/bin/sh

set -eu

MODE="${1:-all}"

run_phase1() {
	./install_addons.sh
	./distribute_files.sh
}

run_phase2() {
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