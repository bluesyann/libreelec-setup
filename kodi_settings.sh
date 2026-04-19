#!/bin/bash

change_xmlval() {
    local id="$1"
    local value="$2"
    local file="$3"
    xmlstarlet ed -L \
        -u "//setting[@id='$id']" -v "$value" \
        -d "//setting[@id='$id']/@default" \
        "$file"
    echo "$id changed to $value in $file"
}

userconfig="user_config.json"
kodifile="/home/yann/test/guisettings.xml"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install it first."
    exit 1
fi

# Check if the JSON file exists
if [ ! -f "$userconfig" ]; then
    echo "JSON file not found: $userconfig"
    exit 1
fi

systemctl stop kodi

# Parse JSON and update XML for each key/value
jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$userconfig" | while IFS=$'\t' read -r id value; do
    change_xmlval "$id" "$value" "$kodifile"
done

systemctl start kodi
