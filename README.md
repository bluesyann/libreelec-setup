# LibreELEC Media Center Setup

This repository rebuilds a full LibreELEC + Docker media center configuration from plain files.

Goal: make SD-card recovery reproducible without copying full disk images.

## Scope

Target platform is currently Radxa RockPi 4SE on LibreELEC, but scripts stay generic and BusyBox `ash` compatible when possible.

This setup orchestrates:

- Kodi add-ons and GUI settings
- Dockerized services (`radarr`, `lidarr`, `prowlarr`, `qbittorrent`, `syncthing`, `navidrome`, `mariadb`, `weatherpage`, `cloudflared`, `cups`, `sane`, `joal`)
- Runtime automation scripts for:
	- HDD wake/power cycle and startup sequencing
	- printer/scanner container control
	- weather station ingestion into MariaDB
	- navidrome recovery on I/O errors
	- stack updates

## Repository Layout

- `autostart.sh`: startup orchestrator run by LibreELEC
- `docker-compose.yml`: container stack definition
- `run_install.sh`: high-level install sequence
- `install_addons.sh`: Kodi add-on install + docker-compose binary download
- `distribute_files.sh`: deploys repo content to `/storage/.config` (except `autostart.sh`)
- `kodi_settings.sh`: applies settings from `user_config.json` into Kodi XML
- `scripts/lib/common.sh`: shared runtime helpers (compose path, secrets load)
- `scripts/lib/logging.sh`: shared logging helpers for all background shell scripts
- `scripts/*.sh`: long-running monitors/maintenance scripts
- `secrets/libreelec.env.example`: template of required secret values

## Secret Management

Secrets are not stored in tracked files.

1. Create `/var/media/Kodi_Storage/secrets/libreelec.env` with all required values (see `secrets/libreelec.env.example`).
2. Run `./run_install.sh` — it copies the file to `/storage/.config/secrets/libreelec.env` as first step.
3. All runtime scripts and docker-compose read from `/storage/.config/secrets/libreelec.env` so the system starts normally even if the HDD is offline.

Main variables used by scripts/compose:

- `CLOUDFLARE_TUNNEL_TOKEN`
- `MARIADB_ROOT_PASSWORD`
- `WEATHER_DB_PASSWORD`
- `JOAL_UI_SECRET_TOKEN`
- `CUPS_ADMIN`, `CUPS_PASSWORD`
- `KODI_WEBSERVER_USER`, `KODI_WEBSERVER_PASSWORD`

The runtime scripts source this file with exported variables before running `docker-compose`, so Compose interpolation can consume those values without hardcoding credentials in `docker-compose.yml`.

## Logging

All non-installer shell scripts write timestamped logs into:

- `/storage/.config/logs/autostart.log`
- `/storage/.config/logs/cups_management.log`
- `/storage/.config/logs/feed_weather_db.log`
- `/storage/.config/logs/restart_containers_on_error.log`
- `/storage/.config/logs/update_containers.log`

Simple log rotation is built-in at 1 MiB per file (`.1` rollover).

Installer scripts intentionally keep plain stdout/stderr output.

## Installation Flow

Prerequisites before running this repo:

1. Flash latest LibreELEC image to SD card.
2. Boot once and configure network + SSH.
3. Attach backup/secret USB drive if used.
4. Clone this repository on the device.

Then run:

```sh
./run_install.sh
```

It executes:

1. copy secrets from `/var/media/Kodi_Storage/secrets/libreelec.env` to `/storage/.config/secrets/libreelec.env`
2. `install_addons.sh`
3. `distribute_files.sh`
4. `kodi_settings.sh` (only if `jq` is already available)

`autostart.sh` is intentionally deployed only in second pass.

If `jq` is not available on first boot, reboot LibreELEC and run:

```sh
./run_install.sh post-reboot
```

Optional explicit phases:

```sh
./run_install.sh pre-reboot
./run_install.sh post-reboot
```

`post-reboot` deploys `/storage/.config/autostart.sh` and then runs `kodi_settings.sh`.

## Runtime Notes

- `autostart.sh` waits for `/var/media/Kodi_Storage/music` readiness before starting containers.
- Printer-related containers are controlled dynamically by USB printer presence.
- Weather data collector runs every minute and inserts into MariaDB.
- Navidrome monitor restarts container when recent logs include `input/output error`.

## Maintenance

- Update stack manually with:

```sh
/storage/.config/scripts/update_containers.sh
```

- Ensure scripts stay POSIX/Bash-lite for BusyBox compatibility.

## Security Notes

- Never commit `secrets/*.env` with real values.
- Rotate exposed tokens/passwords if they ever existed in repository history.
