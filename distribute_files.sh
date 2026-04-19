#!/bin/sh

set -eu

DESTINATION="/storage/.config"
DB_BACKUP="/var/media/Kodi_Storage/db-backup"
AUTOSTART_MODE="${1:---no-autostart}"

FOLDERS="
prowlarr
radarr
scripts
weather
flactomp3
joal
lidarr
qbittorrent
"

copy_required_file() {
    _src="$1"
    _dst="$2"

    if [ -f "$_src" ]; then
        cp "$_src" "$_dst"
        echo "Copied $_src -> $_dst"
    else
        echo "Warning: missing file $_src"
    fi
}

if [ ! -d "$DESTINATION" ]; then
    echo "Error: destination folder missing: $DESTINATION"
    exit 1
fi

echo "Copying repository folders to $DESTINATION"
for folder in $FOLDERS; do
    [ -z "$folder" ] && continue
    if [ -d "$folder" ]; then
        rm -rf "$DESTINATION/$folder"
        cp -r "$folder" "$DESTINATION/"
        echo "Copied folder: $folder"
    else
        echo "Warning: missing folder $folder"
    fi
done

echo "Copying top-level scripts"
case "$AUTOSTART_MODE" in
    --with-autostart)
        copy_required_file "autostart.sh" "$DESTINATION/autostart.sh"
        ;;
    --no-autostart)
        echo "Skipping autostart deployment for this pass"
        ;;
    *)
        echo "Usage: ./distribute_files.sh [--no-autostart|--with-autostart]"
        exit 1
        ;;
esac
copy_required_file "docker-compose.yml" "$DESTINATION/docker-compose.yml"
copy_required_file "README.md" "$DESTINATION/README.md"

if [ -d "$DB_BACKUP" ]; then
    echo "Copying database backups from $DB_BACKUP"
    cp -r "$DB_BACKUP"/* "$DESTINATION/"
else
    echo "Warning: database backup folder missing: $DB_BACKUP"
fi

if [ -f "$DESTINATION/autostart.sh" ]; then
    chmod +x "$DESTINATION/autostart.sh" || true
fi
find "$DESTINATION/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo "Distribution completed"