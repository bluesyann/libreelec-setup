#!/bin/sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/logging.sh"

init_logger "update_containers"

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "docker-compose file not found at $COMPOSE_FILE"
    exit 1
fi

if ! compose_bin >/dev/null 2>&1; then
    log_error "docker-compose binary not found"
    exit 1
fi

log_info "Pulling latest container images"
if ! compose pull; then
    log_error "Image pull failed"
    exit 1
fi

log_info "Stopping current stack"
if ! compose down; then
    log_error "Stack shutdown failed"
    exit 1
fi

log_info "Starting updated stack"
if ! compose up -d; then
    log_error "Stack startup failed"
    exit 1
fi

log_info "Pruning dangling docker images"
docker image prune -f >/dev/null 2>&1 || log_warn "docker image prune returned an error"

log_info "Container update completed"
