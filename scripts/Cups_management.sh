#!/bin/sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/logging.sh"

load_secrets
init_logger "cups_management"

printer_connected() {
    lsusb 2>/dev/null | grep -qi "PIXMA MG2500"
}

container_running() {
    _name="$1"
    _running="$(docker inspect -f '{{.State.Running}}' "$_name" 2>/dev/null)"
    [ "$_running" = "true" ]
}

log_info "Printer monitor started"

while :; do
    if printer_connected; then
        log_info "Printer detected"

        if ! container_running cups; then
            log_info "Starting cups container"
            compose up -d cups >/dev/null 2>&1 || log_error "Failed to start cups"
        fi

        if ! container_running sane; then
            log_info "Starting sane container"
            compose up -d sane >/dev/null 2>&1 || log_error "Failed to start sane"
        fi
    else
        log_info "Printer not detected"

        if container_running cups; then
            log_info "Stopping cups container"
            compose stop cups >/dev/null 2>&1 || log_error "Failed to stop cups"
        fi

        if container_running sane; then
            log_info "Stopping sane container"
            compose stop sane >/dev/null 2>&1 || log_error "Failed to stop sane"
        fi
    fi

    sleep 10
done
