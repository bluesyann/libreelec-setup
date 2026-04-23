#!/bin/sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/logging.sh"

init_logger "restart_containers_on_error"

if docker logs --tail=20 navidrome 2>&1 | grep -qi "input/output error"; then
    log_warn "Detected navidrome I/O error, restarting container"
    compose restart navidrome >/dev/null 2>&1 || log_error "Failed to restart navidrome"
else
    log_info "No navidrome I/O error detected"
fi
