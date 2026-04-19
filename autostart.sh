#!/bin/sh

export PATH=/storage/bin:/usr/bin:/usr/sbin:/storage/.kodi/addons/docker.linuxserver.updater/bin:/storage/.kodi/addons/service.system.docker/bin:$PATH
chmod 666 /var/run/docker.sock
#link to the docker yaml file
yaml="/storage/.config/docker-compose.yml"

# Wait for the system to be fully up
sleep 60

logifle="/storage/.config/autostart.log"

echo "Running autostart.sh" > /storage/.config/output.log
current_datetime=$(date +"%Y-%m-%d %H:%M:%S")
echo "Current date and time: $current_datetime" >> /storage/.config/output.log

# Power cycle the harddrive if not visible
if [ ! -e /dev/sda ]; then
    echo "Power cycling the harddrive" >> /storage/.config/output.log
    pkill -9 -f gpioset
    gpioset --daemonize -c gpiochip4 22=1
    echo "down..." >> /storage/.config/output.log
    sleep 5
    pkill -9 -f gpioset
    gpioset --daemonize -c gpiochip4 22=0
    echo "up!" >> /storage/.config/output.log
    sleep 10
fi


# Wait for Kodi_Storage + music dir + readable contents
while true; do
    if [ -d "/var/media/Kodi_Storage/music" ] && 
       ls /var/media/Kodi_Storage/music >/dev/null 2>&1 &&
       [ "$(find /var/media/Kodi_Storage/music -mindepth 1 -maxdepth 1 | wc -l)" -gt 5 ]; then
        echo "Kodi_Storage fully ready - $(find /var/media/Kodi_Storage/music -mindepth 1 -maxdepth 1 | wc -l) items found at $(date)" >> /storage/.config/output.log
        break
    fi
    echo "Waiting... $(ls /var/media/Kodi_Storage/music 2>/dev/null || echo 'unreadable')" >> /storage/.config/output.log
    sleep 3
done


hdparm -S 100 /dev/sda >> /storage/.config/output.log

# Mount is ready - set permissions
chown -R 1000:1000 /var/media/Kodi_Storage
chmod -R 777 /var/media/Kodi_Storage
echo "Kodi_Storage mounted and permissions set at $(date)" >> /storage/.config/output.log

# Start the containers with delay
sleep 60
echo "Starting docker-compose at $(date)!" >> /storage/.config/output.log
/storage/bin/docker-compose -f $yaml up -d >> /storage/.config/output.log 2>&1
echo "Docker-compose startup completed at $(date)" >> /storage/.config/output.log


# Wait for the containers to be up
sleep 20

#Mount the samba share with the music from the laptop [obsolete]
#echo "Mounting the remote SMB share" >> /storage/.config/output.log
#/storage/.config/mount_music_dir.sh >> /storage/.config/output.log &

#Run the printer monitoring script
echo "Running the navidrome monitoring script" >> /storage/.config/output.log
/storage/.config/Restart_containers_on_error.sh >> /storage/.config/output.log 2>&1 &

#Run the printer monitoring script
echo "Running the printer monitoring script" >> /storage/.config/output.log
/storage/.config/Cups_management.sh >> /storage/.config/output.log 2>&1 &

#Run the weather monitor
echo "Running the weather script" >> /storage/.config/output.log
/storage/.config/feed_weather_db.sh &
