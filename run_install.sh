#!/bin/sh

set -eu

./install_addons.sh
./distribute_files.sh
./kodi_settings.sh