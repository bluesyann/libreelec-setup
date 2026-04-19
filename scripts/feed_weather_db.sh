#!/bin/sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/logging.sh"

init_logger "feed_weather_db"

WEATHER_STATION_IP="${WEATHER_STATION_IP:-192.168.1.100}"
WEATHER_STATION_PORT="${WEATHER_STATION_PORT:-80}"
DB_CONTAINER="mariadb"
DB_USER="${WEATHER_DB_USER:-root}"
DB_PASS="${WEATHER_DB_PASSWORD:-${MARIADB_ROOT_PASSWORD:-}}"
DB_NAME="${MARIADB_DATABASE:-WeatherData}"
DB_TABLE="weather"

check_weather_station() {
    ping -c 1 -W 2 "$WEATHER_STATION_IP" >/dev/null 2>&1
}

check_db_container() {
    docker exec "$DB_CONTAINER" mariadb -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" >/dev/null 2>&1
}

fetch_weather_data() {
    curl -fsS "http://$WEATHER_STATION_IP:$WEATHER_STATION_PORT/return_sensors"
}

update_rtc() {
    _timestamp="$(date +%Y-%m-%d-%w-%H-%M-%S)"
    curl -fsS "http://$WEATHER_STATION_IP:$WEATHER_STATION_PORT/settime?timestamp=$_timestamp" >/dev/null 2>&1
}

insert_data() {
    _datetime="$1"
    _temperature="$2"
    _humidity="$3"
    _pressure="$4"

    docker exec "$DB_CONTAINER" mariadb -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e \
        "INSERT INTO $DB_TABLE (DateTime, Temperature, Humidity, Pressure) VALUES ('$_datetime', '$_temperature', '$_humidity', '$_pressure');" >/dev/null 2>&1
}

log_info "Weather feeder started"

while :; do
    if ! check_weather_station; then
        log_error "Weather station unreachable at $WEATHER_STATION_IP"
        sleep 60
        continue
    fi

    weather_data="$(fetch_weather_data 2>/dev/null)"
    if [ -z "$weather_data" ]; then
        log_error "Weather station returned empty payload"
        sleep 60
        continue
    fi

    temperature="$(echo "$weather_data" | cut -d ';' -f 1)"
    humidity="$(echo "$weather_data" | cut -d ';' -f 2)"
    pressure="$(echo "$weather_data" | cut -d ';' -f 3)"

    if [ -z "$temperature" ] || [ -z "$humidity" ] || [ -z "$pressure" ]; then
        log_error "Invalid sensor payload: $weather_data"
        sleep 60
        continue
    fi

    if ! check_db_container; then
        log_error "MariaDB container unavailable"
        sleep 60
        continue
    fi

    datetime="$(date +'%Y-%m-%d %H:%M:%S')"
    if ! insert_data "$datetime" "$temperature" "$humidity" "$pressure"; then
        log_error "Failed to insert weather data"
        sleep 60
        continue
    fi

    if ! update_rtc; then
        log_warn "Failed to update weather station RTC"
    fi

    log_info "Stored weather data: T=$temperature H=$humidity P=$pressure"
    sleep 60
done

