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
- `scripts/Restart_containers_on_error.sh`: restart navidrome on detected I/O errors
- `scripts/update_containers.sh`: pull/redeploy stack for updates

## Logging Policy

- Background scripts must use shared logging helpers in `scripts/lib/logging.sh`
- Logs are written to `/storage/.config/logs/*.log`
- Installer scripts (`run_install.sh`, `install_addons.sh`, `distribute_files.sh`, `kodi_settings.sh`) may use simple prints only

## Secret Handling Policy

Secrets must never be hardcoded in tracked files.

- Template: `secrets/libreelec.env.example`
- Source before install: `/var/media/Kodi_Storage/secrets/libreelec.env` (on data drive, not tracked)
- Runtime file on target: `/storage/.config/secrets/libreelec.env` (copied by installer, lives on SD card)
- `docker-compose.yml` must use environment interpolation for secrets and credentials

`run_install.sh` copies HDD → SD as its first step so all runtime scripts (and compose) always read from `/storage/.config/secrets/libreelec.env` regardless of HDD state.

When sourcing this file in shell scripts, variables must be exported so `docker-compose` interpolation can read them.

If a token/password appears in repository content, move it to env-based configuration and treat it as exposed.

## Installer Flow

Expected first-run sequence on a new SD card:

1. Flash latest LibreELEC image
2. Boot once, configure network + enable SSH
3. Clone this repository on the device
4. Run `./run_install.sh`
5. Confirm Kodi add-on prompts manually in GUI when required

`run_install.sh` orchestrates:

1. copy secrets from `/var/media/Kodi_Storage/secrets/libreelec.env` to `/storage/.config/secrets/libreelec.env`
2. `install_addons.sh`
3. `distribute_files.sh`
4. `kodi_settings.sh` (same boot only if `jq` is already available)

If `jq` is not available yet, expected flow is:

1. Run `./run_install.sh` (or `./run_install.sh pre-reboot`)
2. Reboot LibreELEC
3. Run `./run_install.sh post-reboot` (deploys autostart + applies Kodi settings)

Manual confirmation in Kodi is expected and accepted.

## Editing Guidance for Agents

- Keep changes generic enough for nearby ARM LibreELEC systems
- Avoid introducing Bash-only syntax in `.sh` files
- Prefer consistent naming and structure over one-off script behavior
- Keep docs (`README.md` and this file) synchronized with implementation changes