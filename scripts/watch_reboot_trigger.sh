
#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/logging.sh"

init_logger "watch_reboot_trigger"

TRIG="/storage/.config/reboot_trigger"

if [ ! -f "$TRIG" ]; then
	log_info "No reboot trigger file: $TRIG"
	exit 0
fi

trigger_value="$(tr -d ' \t\r\n' < "$TRIG" 2>/dev/null || true)"
if [ "$trigger_value" != "1" ]; then
	log_info "Ignoring reboot trigger value '$trigger_value'"
	exit 0
fi

log_warn "Reboot trigger detected, deleting $TRIG and rebooting"
rm -f "$TRIG"
sync

if command -v reboot >/dev/null 2>&1; then
	reboot
elif [ -x /sbin/reboot ]; then
	/sbin/reboot
elif [ -x /usr/sbin/reboot ]; then
	/usr/sbin/reboot
else
	log_error "Reboot command not found"
	exit 1
fi