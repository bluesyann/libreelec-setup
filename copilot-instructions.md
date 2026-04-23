# AI Agent Instructions for LibreELEC Media Center Setup

## Project Intent

This repository exists to rebuild a complete LibreELEC media-center configuration from files, without relying on full SD-card backup images.

Primary objective: keep setup reproducible, maintainable, and safe for secret handling.

## Runtime Context

### Platform

- Current hardware target: Radxa RockPi 4SE
- Current OS example: `Linux LibreELEC 6.6.71 ... aarch64 GNU/Linux`
- Shell environment is BusyBox `ash`

All shell scripts must remain compatible with BusyBox/POSIX shell features.

### Connected Hardware

- HDMI TV
- USB audio DAC (preferred audio path)
- USB mass storage HDD (external power)
- USB printer/scanner combo
- Ethernet network
- USB DVD reader

System administration is performed via Kodi UI, Kore app, container web UIs, and SSH.

## Data Model on HDD

- `Musique`: large music library, synced one-way from laptop (authoritative source is laptop)
- `music`: smaller Lidarr-managed library, synced two-way
- `movies`: Radarr-managed movie library (disposable)
- `downloads`: qBittorrent working directory

Design rule: keep OS and config on SD card so HDD can sleep when idle.

Full container backups are stored outside the repository in `/var/media/Kodi_Storage/containers-backup`.
Repository-managed content is intentionally limited to lightweight custom code and top-level orchestration files.

## Services Managed by Docker

- qBittorrent
- Joal
- Radarr
- Prowlarr
- Solvearr
- Lidarr
- Syncthing
- Navidrome
- MariaDB (weather data)
- Weather dashboard page
- Cloudflared tunnel
- CUPS
- SANE / scanservjs

## Script Responsibilities

- `autostart.sh`: startup sequencing, disk readiness checks, docker stack start, monitor launch
- `scripts/Cups_management.sh`: start/stop cups/sane based on printer presence
- `scripts/feed_weather_db.sh`: poll weather station and insert into MariaDB every minute
- `scripts/restart_containers_on_error.sh`: restart navidrome on detected I/O errors
- `scripts/update_containers.sh`: pull/redeploy stack for updates

## Logging Policy

- Background scripts must use shared logging helpers in `scripts/lib/logging.sh`
- Logs are written to `/storage/.config/logs/*.log`
- Installer scripts (`install_addons.sh`, `distribute_files.sh`, `kodi_settings.sh`) may use simple prints only

## Secret Handling Policy

Secrets must never be hardcoded in tracked files.

- Template: `secrets/libreelec.env.example`
- Source before install: `/var/media/Kodi_Storage/secrets/libreelec.env` (on data drive, not tracked)
- `docker-compose.yml` must use environment interpolation for secrets and credentials

`distribute_files.sh` reads `/var/media/Kodi_Storage/secrets/libreelec.env` directly and renders secrets into production files in `/storage/.config`.

If a token/password appears in repository content, move it to env-based configuration and treat it as exposed.

## Installer Flow

Expected first-run sequence on a new SD card:

1. Flash latest LibreELEC image
2. Boot once, configure network + enable SSH
3. Clone this repository on the device
4. Run `./install_addons.sh`
5. Run `./distribute_files.sh`
6. Run `./kodi_settings.sh`
7. Confirm Kodi add-on prompts manually in GUI when required

`distribute_files.sh` restores `/var/media/Kodi_Storage/containers-backup` into `/storage/.config`, copies repository-managed files (`weather`, `scripts`, `autostart.sh`, `docker-compose.yml`), and renders secrets directly into final runtime files.

Manual confirmation in Kodi is expected and accepted.

## Editing Guidance for Agents

- Keep changes generic enough for nearby ARM LibreELEC systems
- Avoid introducing Bash-only syntax in `.sh` files
- Prefer consistent naming and structure over one-off script behavior
- Keep docs (`README.md` and this file) synchronized with implementation changes