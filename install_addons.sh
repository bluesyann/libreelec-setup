#!/bin/sh

set -eu

wget https://github.com/castagnait/repository.castagnait/raw/kodi/repository.castagnait-2.0.1.zip
echo "Please install repository.castagnait .zip file from the GUI"
read -p "Press enter to continue once done"
#unzip repository.castagnait-2.0.1.zip -d /storage/.kodi/addons

wait_for_subfolder() {
    parent_folder="$1"
    subfolder="$2"
    full_path="${parent_folder%/}/${subfolder}"

    while [ ! -d "$full_path" ]; do
        sleep 1
        echo "Waiting for '$subfolder' to appear in '$parent_folder'"
    done
}

pluginloc="/storage/.kodi/addons/"
composedir="/storage/compose"
compose_target="$composedir/docker-compose"

resolve_compose_arch() {
    _arch="$1"
    case "$_arch" in
        armv7l|armv7)
            echo "armv7"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        x86_64|amd64)
            echo "x86_64"
            ;;
        *)
            echo "$_arch"
            ;;
    esac
}

install_compose_binary() {
    arch_raw="$(uname -m)"
    arch="$(resolve_compose_arch "$arch_raw")"

    mkdir -p "$composedir"

    compose_version="$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

    if [ -z "$compose_version" ]; then
        echo "Warning: unable to detect latest docker-compose release"
        return 1
    fi

    compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-linux-${arch}"
    echo "Getting $compose_url"

    if ! curl -fSL "$compose_url" -o "$compose_target"; then
        echo "Warning: docker-compose download failed for arch '$arch'"
        return 1
    fi

    chmod +x "$compose_target"
    return 0
}

# List of addons to install
# when pc sorted, add plugin.video.netflix 
addons="plugin.video.netflix tools.ffmpeg-tools virtual.network-tools plugin.video.arteplussept virtual.rpi-tools virtual.system-tools service.subtitles.opensubtitles resource.language.fr_fr service.system.docker"

# Run the install
for addon in $addons; do
    echo "Installing $addon..."
    kodi-send --action="InstallAddon($addon)"
    wait_for_subfolder "$pluginloc" "$addon"
    echo "$addon installed!"
    sleep 1
done

install_compose_binary