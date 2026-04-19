#!/bin/bash

#cd .kodi/addons/
#wget https://github.com/castagnait/repository.castagnait/raw/kodi/repository.castagnait-2.0.1.zip
#unzip repository.castagnait-2.0.1.zip

# trouver comment faire ça
#kodi-send --action="InstallAddon(repository.castagnait)"

# Install the json parser from System Tools addon
wait_for_path() {
    local substring="$1"
    while [[ ":$PATH:" != *"$substring"* ]]; do
        sleep 1
        echo "Waiting for '$substring' to appear in PATH"
    done
}

wait_for_subfolder() {
    local parent_folder="$1"
    local subfolder="$2"
    local full_path="${parent_folder%/}/${subfolder}"

    while [ ! -d "$full_path" ]; do
        sleep 1
        echo "Waiting for '$subfolder' to appear in '$parent_folder'"
    done
}

pluginloc="/storage/.kodi/addons/"

# List of addons to install
addons=(
    "plugin.video.netflix"
    "plugin.video.arteplussept"
    "virtual.rpi-tools"
    "virtual.system-tools"
    "service.subtitles.opensubtitles"
    "service.system.docker"
)

for addon in "${addons[@]}"; do
    echo "Installing $addon..."
    kodi-send --action="InstallAddon($addon)"
    wait_for_subfolder "$pluginloc" "$addon"
    echo "$addon installed!"
done