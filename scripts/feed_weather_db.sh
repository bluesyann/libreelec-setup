#!/bin/bash

# query example
# docker exec mariadb mariadb -u root -ppass WeatherData -e "SELECT * FROM weather;"

log="/storage/.config/feed_weather_db.log"
weather_station_ip="192.168.1.100"
weather_station_port="80"
db_container="mariadb"
db_user="root"
db_pass="pass"
db_name="WeatherData"
db_table="weather"

# Clean old logs
date > "$log"
echo "Running feed_weather_db.sh script" >> "$log"

# Function to log messages with timestamp
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$log"
}

# Function to check if the weather station is reachable
check_weather_station() {
    if ! ping -c 1 -W 2 "$weather_station_ip" &> /dev/null; then
        log_message "ERROR: Weather station at $weather_station_ip is unreachable."
        return 1
    fi
    return 0
}

# Function to check if the database container is reachable
check_db_container() {
    if ! docker exec "$db_container" mariadb -u "$db_user" -p"$db_pass" -e "SELECT 1" &> /dev/null; then
        log_message "ERROR: Cannot connect to MariaDB in container $db_container."
        return 1
    fi
    return 0
}

# Function to fetch and parse weather data
fetch_weather_data() {
    local response
    response=$(curl -s "http://$weather_station_ip:$weather_station_port/return_sensors")
    if [ -z "$response" ]; then
        log_message "ERROR: Empty response from weather station."
        return 1
    fi
    echo "$response"
    return 0
}

# Function to update RTC
update_rtc() {
    local timestamp
    timestamp=$(date +%Y-%m-%d-%w-%H-%M-%S)
    if ! curl -s "http://$weather_station_ip:$weather_station_port/settime?timestamp=$timestamp" &> /dev/null; then
        log_message "ERROR: Failed to update RTC on weather station."
        return 1
    fi
    return 0
}

# Main loop
while true; do
    log_message "Starting new data collection cycle..."

    # Check weather station
    if ! check_weather_station; then
        sleep 60
        continue
    fi

    # Fetch weather data
    weather_data=$(fetch_weather_data)
    if [ $? -ne 0 ]; then
        sleep 60
        continue
    fi

    # Parse data (format: Temperature;Humidity;Pressure)
    temperature=$(echo "$weather_data" | cut -d';' -f1)
    humidity=$(echo "$weather_data" | cut -d';' -f2)
    pressure=$(echo "$weather_data" | cut -d';' -f3)
    log_message "DEBUG: temperature=$temperature, humidity=$humidity, pressure=$pressure"
    if [ -z "$temperature" ] || [ -z "$humidity" ] || [ -z "$pressure" ]; then
        log_message "ERROR: Failed to parse weather data: $weather_data"
        sleep 60
        continue
    fi

    # Check database
    if ! check_db_container; then
        sleep 60
        continue
    fi

    # Insert data into database
    datetime=$(date +'%Y-%m-%d %H:%M:%S')
    if ! docker exec "$db_container" mariadb -u "$db_user" -p"$db_pass" "$db_name" -e \
        "INSERT INTO $db_table (DateTime, Temperature, Humidity, Pressure) VALUES ('$datetime', '$temperature', '$humidity', '$pressure');"; then
        log_message "ERROR: Failed to insert data into database."
        sleep 60
        continue
    fi

    # Update RTC
    if ! update_rtc; then
        sleep 60
        continue
    fi

    log_message "Successfully collected and stored data: Temperature=$temperature, Humidity=$humidity, Pressure=$pressure"
    sleep 60 # Wait 1 minutes before next cycle
done

