#!/bin/bash

#This script check if the printer is on
#when on, it starts the CUPS service
#when off, it stops it

export PATH=/storage/bin:/usr/bin:/usr/sbin:/storage/.kodi/addons/docker.linuxserver.updater/bin:/storage/.kodi/addons/service.system.docker/bin:$PATH
chmod 666 /var/run/docker.sock
#link to the docker yaml file
yaml="/storage/.config/docker-compose.yml"

#Wait for the Docker Compose startup to be completed
#while [ $(/storage/bin/docker-compose -f $yaml ps --services --filter "status=running" | wc -l) -lt $(/storage/bin/docker-compose -f $yaml config --services | wc -l) ]; do
 #   echo "Waiting for all services to be up..."
  #  sleep 5
#done
#echo "All services are up and running!"

# Main loop
while true; do
	current_datetime=$(date +"%Y-%m-%d %H:%M:%S")
	echo "Current date and time: $current_datetime"

	#Check printer
	printer=$(lsusb | grep Canon)
	if [[ "$printer" == *"PIXMA MG2500"* ]]; then
		echo "Printer connected";
		printer=true;
	else
		echo "Printer disconnected";
		printer=false;
	fi
	
	#Check CUPS container
	#docker-compose -f "/storage/.config/docker-compose.yml" ps | grep cups
	cups="$(docker inspect -f '{{.State.Running}}' cups 2>/dev/null)";
	if [[ "$cups" == "true" ]]; then
		echo "CUPS container up";
	else
		echo "CUPS container down";
	fi
	
	#Check sane container
	sane="$(docker inspect -f '{{.State.Running}}' sane 2>/dev/null)";
	if [[ "$sane" == "true" ]]; then
		echo "SANE container up";
	else
		echo "SANE container down";
	fi
	
	#printer up : we start CUPS and Sane if down
	if [ $printer == true ]; then
		if [ $cups == false ]; then
			echo "Printer up, CUPS down : Starting CUPS"
			/storage/bin/docker-compose -f $yaml start cups
		fi
		if [ $sane == false ]; then
			echo "Printer up, SANE down : Starting SANE"
			#docker-compose -f /storage/.config/docker-compose.yml start sane
			/storage/bin/docker-compose -f $yaml up -d sane
		fi
	fi
	
	#printer down : we stop CUPS and Sane if up
	if [ $printer == false ]; then
		if [ $cups == true ]; then
			echo "Printer down, CUPS up : stopping CUPS"
			/storage/bin/docker-compose -f $yaml stop cups
		fi
		if [ $sane == true ]; then
			echo "Printer down, SANE up : stopping SANE"
			/storage/bin/docker-compose -f $yaml stop sane
		fi
	fi
	
    sleep 10  # Wait for 10 seconds before checking again
done
