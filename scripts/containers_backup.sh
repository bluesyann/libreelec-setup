#!/bin/sh

# use rsync to bakcup containers data on the external hdd

CONTAINERS_BACKUP="/var/media/Kodi_Storage/containers-backup/"
CONTAINERS_SOURCE="/storage/.config"

containers="cups lidarr navidrome qbittorrent syncthing joal mariadb prowlarr radarr"

/storage/compose/docker-compose -f /storage/.config/docker-compose.yml down

if [ -d "$CONTAINERS_BACKUP" ]; then
    for container in $containers; do
        sourcedir="$CONTAINERS_SOURCE/$container"
        echo "Backing up $container directory $sourcedir"
        if [ -d "$sourcedir" ]; then
            rsync -av $sourcedir "$CONTAINERS_BACKUP"
        else
            echo "Warning: $sourcedir missing"
        fi  
    done
else
    echo "Warning: containers backup folder missing: $CONTAINERS_BACKUP"
fi

/storage/compose/docker-compose -f /storage/.config/docker-compose.yml up -d