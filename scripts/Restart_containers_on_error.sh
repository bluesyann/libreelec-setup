#!/bin/bash

#This script check if the printer is on
#when on, it starts the CUPS service
#when off, it stops it

export PATH=/storage/bin:/usr/bin:/usr/sbin:/storage/.kodi/addons/docker.linuxserver.updater/bin:/storage/.kodi/addons/service.system.docker/bin:$PATH
chmod 666 /var/run/docker.sock
#link to the docker yaml file
yaml="/storage/.config/docker-compose.yml"

# Main loop
while true; do
	current_datetime=$(date +"%Y-%m-%d %H:%M:%S")

	#Check for Navidrome errors from the log
	NDerrors=$(docker logs --tail=10 navidrome 2>&1 | grep -i "input/output error")
	if [[ "$NDerrors" != "" ]]; then
	    echo "I/O error on Navidrome detected, restarting the container";
	    /storage/bin/docker-compose -f $yaml restart navidrome
	fi
	echo "No i/o error detected: $current_datetime"
    sleep 60  # Wait for 1 minute before checking again
done
