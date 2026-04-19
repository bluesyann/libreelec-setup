#!/bin/bash

folders="prowlarr radarr scripts weather flactomp3 joal lidarr qbittorrent"

destination="/storage/.config/"
dbbackup="/media/sda1-usb-OTi2168_Flash_Di/db-backup"

# Check if destination exists and is a directory
if [ ! -d "$destination" ]; then
    echo "Error: Destination directory does not exist: $destination"
    exit 1
fi

# Iterate over each folder (those on git)
echo "Copying config text files to $destination"
for folder in $folders; do
    if [ -d $folder ]; then
        echo "Copying $folder to $destination"
        cp -r $folder $destination
    else
        echo "Warning: Folder does not exist: $folder"
    fi
done

# Get database files from the mass storage device
echo "Copying database files from the backup drive to $destination"
if [ -d $dbbackup ]; then
    cp -r $dbbackup/* $destination
    echo "Done."
else
    echo "Warning: Folder does not exist: $dbbackup"
fi

# Finally, copy autostart.sh and docker-compose.yml to their respective locations
if [ -f "files/autostart.sh" ]; then
    echo "Copying autostart.sh to $destination"
    cp "files/autostart.sh" $destination
    echo "Done."
else
    echo "Warning: autostart.sh not found"
fi

if [ -f "files/docker-compose.yml" ]; then
    echo "Copying docker-compose.yml to $destination"
    cp "files/docker-compose.yml" $destination
    echo "Done."
else
    echo "Warning: docker-compose.yml not found"
fi