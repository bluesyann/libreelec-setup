#!/bin/sh

set -eu

DESTINATION="/storage/.config"
SECRETS_DEST_DIR="$DESTINATION/secrets"
DB_BACKUP="/media/sda1-usb-OTi2168_Flash_Di/db-backup"

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
copy_required_file "autostart.sh" "$DESTINATION/autostart.sh"
copy_required_file "docker-compose.yml" "$DESTINATION/docker-compose.yml"
copy_required_file "README.md" "$DESTINATION/README.md"

echo "Copying secrets template"
mkdir -p "$SECRETS_DEST_DIR"
copy_required_file "secrets/libreelec.env.example" "$SECRETS_DEST_DIR/libreelec.env.example"

if [ ! -f "$SECRETS_DEST_DIR/libreelec.env" ]; then
    cp "$SECRETS_DEST_DIR/libreelec.env.example" "$SECRETS_DEST_DIR/libreelec.env"
    echo "Created $SECRETS_DEST_DIR/libreelec.env from template"
fi

if [ -d "$DB_BACKUP" ]; then
    echo "Copying database backups from $DB_BACKUP"
    cp -r "$DB_BACKUP"/* "$DESTINATION/"
else
    echo "Warning: database backup folder missing: $DB_BACKUP"
fi

chmod +x "$DESTINATION/autostart.sh" || true
find "$DESTINATION/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo "Distribution completed"