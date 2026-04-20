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
- `install_addons.sh`: Kodi add-on install + docker-compose binary download
- `distribute_files.sh`: deploys repo content to `/storage/.config`, restores container backups, and renders final runtime files
- `kodi_settings.sh`: applies settings from `user_config.json` into Kodi XML
- `scripts/lib/common.sh`: shared runtime helpers (compose path)
- `scripts/lib/logging.sh`: shared logging helpers for all background shell scripts
- `scripts/*.sh`: long-running monitors/maintenance scripts
- `secrets/libreelec.env.example`: template of required secret values

Full container backups are stored outside the repository in `/var/media/Kodi_Storage/containers-backup` and restored by `distribute_files.sh`.
Only lightweight custom code remains in git: `weather`, `flactomp3`, `scripts`, plus top-level orchestration files.

## Secret Management

Secrets are not stored in tracked files.

1. Create `/var/media/Kodi_Storage/secrets/libreelec.env` with all required values (see `secrets/libreelec.env.example`).
2. Run `./distribute_files.sh`.
3. `distribute_files.sh` restores backups from `/var/media/Kodi_Storage/containers-backup`, then renders secrets directly into production files (`/storage/.config/docker-compose.yml` and `/storage/.config/scripts/feed_weather_db.sh`).
4. Run `./kodi_settings.sh` to apply Kodi web server credentials and GUI settings.

Runtime does not depend on a `.env` file.

Main variables used by scripts/compose:

- `CLOUDFLARE_TUNNEL_TOKEN`
- `MARIADB_ROOT_PASSWORD`
- `WEATHER_DB_PASSWORD`
- `JOAL_UI_SECRET_TOKEN`
- `CUPS_ADMIN`, `CUPS_PASSWORD`
- `KODI_WEBSERVER_USER`, `KODI_WEBSERVER_PASSWORD`

The secrets file is used only by installer scripts.

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

Then run, in order:

```sh
./install_addons.sh
./distribute_files.sh
./kodi_settings.sh
```

Use `install_addons.sh` first so the docker-compose binary, Kodi add-ons, and prerequisite tools are installed before you distribute files.

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

- Validate rendered compose file manually:

```sh
/storage/compose/docker-compose -f /storage/.config/docker-compose.yml config
```

- Ensure scripts stay POSIX/Bash-lite for BusyBox compatibility.

## Security Notes

- Never commit `secrets/*.env` with real values.
- Rotate exposed tokens/passwords if they ever existed in repository history.
