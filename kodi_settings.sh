#!/bin/sh

set -eu

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

SECRETS_FILE="/var/media/Kodi_Storage/secrets/libreelec.env"

if [ -f "$SECRETS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$SECRETS_FILE"
else
    echo "Error: secrets file not found: $SECRETS_FILE"
    exit 1
fi

change_xmlval() {
    id="$1"
    value="$2"
    file="$3"
    xmlstarlet ed -L \
        -u "//setting[@id='$id']" -v "$value" \
        -d "//setting[@id='$id']/@default" \
        "$file"
    echo "$id changed to $value in $file"
}

userconfig="user_config.json"
kodifile="/storage/.kodi/userdata/guisettings.xml"

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed. Please install it first."
    exit 1
fi

# Check if the JSON file exists
if [ ! -f "$userconfig" ]; then
    echo "JSON file not found: $userconfig"
    exit 1
fi

tmp_userconfig="/tmp/user_config.runtime.json"
cp "$userconfig" "$tmp_userconfig"

if [ -n "${KODI_WEBSERVER_USER:-}" ]; then
    jq --arg v "$KODI_WEBSERVER_USER" '."services.webserverusername"=$v' "$tmp_userconfig" > "$tmp_userconfig.new"
    mv "$tmp_userconfig.new" "$tmp_userconfig"
fi

if [ -n "${KODI_WEBSERVER_PASSWORD:-}" ]; then
    jq --arg v "$KODI_WEBSERVER_PASSWORD" '."services.webserverpassword"=$v' "$tmp_userconfig" > "$tmp_userconfig.new"
    mv "$tmp_userconfig.new" "$tmp_userconfig"
fi

systemctl stop kodi

# Parse JSON and update XML for each key/value
jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$tmp_userconfig" | while IFS="$(printf '\t')" read -r id value; do
    change_xmlval "$id" "$value" "$kodifile"
done

# Replace skin settings
copy_required_file "settings.xml" "/storage/.kodi/userdata/addon_data/skin.estuary/settings.xml"

# Repalce media sources
copy_required_file "sources.xml" "/storage/.kodi/userdata/sources.xml"

# Replace CEC adapter settings (HDMI management)
copy_required_file "sources.xml" "/storage/.kodi/userdata/cec_CEC_Adapter.xml"

systemctl start kodi

rm -f "$tmp_userconfig" "$tmp_userconfig.new" 2>/dev/null || true
