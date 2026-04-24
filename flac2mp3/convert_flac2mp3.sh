#!/bin/sh

# Convert files from one audio extension to mp3.

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [flac2mp3] $*"
}

if [ "$#" -ne 2 ]; then
    log "Usage: <directory> <extension_without_dot>"
    exit 1
fi

log "Starting conversion run"

dossier="$1"
extension="$2"
total=0

# Build the container: (watch the point at the end !)
# LibreELEC:~/.config/flactomp3 # docker build -t flac2mp3 .

# Maunual run on Navidrome librairy (/media/Kodi_Storage/music/)
# docker run --rm -v /media/Kodi_Storage/music:/music flac2mp3 /music flac
# Cron entry (every hour):
# 0 * * * * /storage/.kodi/addons/service.system.docker/bin/docker run --rm -v /media/Kodi_Storage/music:/music flac2mp3 /music flac >> /storage/.config/logs/flac-convert.log 2>&1

log "Directory: $dossier"
log "Extension: .$extension"

if [ -d "$dossier" ]; then
    total="$(find "$dossier" -name "*.$extension" | wc -l)"
    find "$dossier" -name "*.$extension" | while IFS= read -r fichier; do
        out="${fichier%.$extension}.mp3"
        log "Converting $fichier -> $out"
        
        # Convert with overwrite (-y) and check success
        if ffmpeg -y -i "$fichier" -map 0:a -c:a libmp3lame -b:a 320k -af "aresample=resampler=soxr:osr=44100" -id3v2_version 3 "$out"; then
            log "Removing source file $fichier"
            rm "$fichier" && log "Removed $fichier"
        else
            log "Conversion failed, keeping source: $fichier"
        fi
        
        sleep 1
    done
else
    log "Invalid directory: $dossier"
    exit 1
fi

log "$total files processed"
