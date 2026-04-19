#!/bin/bash

#cd .kodi/addons/
#wget https://github.com/castagnait/repository.castagnait/raw/kodi/repository.castagnait-2.0.1.zip
#unzip repository.castagnait-2.0.1.zip

# trouver comment faire ça
#kodi-send --action="InstallAddon(repository.castagnait)"

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
addons="plugin.video.netflix plugin.video.arteplussept virtual.rpi-tools virtual.system-tools service.subtitles.opensubtitles service.system.docker resource.language.fr_fr"

# Run the install
for addon in $addons; do
    echo "Installing $addon..."
    kodi-send --action="InstallAddon($addon)"
    wait_for_subfolder "$pluginloc" "$addon"
    echo "$addon installed!"
done


# Install the last version of docker-compose for local architecture
arch=$(uname -m)
if [ $arch=="armv7l" ]; then
    arch="armv7"
fi

composedir="/storage/compose"
compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$arch"
echo "Getting $compose_url"
curl -SL $compose_url -o $composedir/docker-compose
chmod +x $composedir/docker-compose