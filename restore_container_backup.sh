#!/bin/sh

set -eu

DESTINATION="/storage/.config"
CONTAINERS_BACKUP="/var/media/Kodi_Storage/containers-backup"

if [ ! -d "$DESTINATION" ]; then
    echo "Error: destination folder missing: $DESTINATION"
    exit 1
fi

if [ ! -d "$CONTAINERS_BACKUP" ]; then
    echo "Error: container backup folder missing: $CONTAINERS_BACKUP"
    exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
    echo "Error: rsync binary not found in PATH: $PATH"
    exit 1
fi

echo "Restoring container backup from $CONTAINERS_BACKUP to $DESTINATION"
rsync -av "$CONTAINERS_BACKUP"/ "$DESTINATION"/
echo "Container backup restore completed"