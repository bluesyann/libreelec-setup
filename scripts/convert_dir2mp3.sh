#!/bin/sh

# Convert files from one audio extension to mp3.

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [dir2mp3] $*"
}

if [ "$#" -ne 2 ]; then
    log "Usage: <directory> <extension_without_dot>"
    exit 1
fi

log "Starting conversion run"

folder="$1"
extension="$2"
total=0

# Maunual run on Navidrome librairy (/media/Kodi_Storage/music/)
# ./convert_dir2mp3.sh /music flac
# Cron entry (every hour):
# 0 * * * * convert_dir2mp3.sh /media/Kodi_Storage/music/ flac

log "Directory: $folder"
log "Extension: .$extension"

if [ -d "$folder" ]; then
    total="$(find "$folder" -name "*.$extension" | wc -l)"
    find "$folder" -name "*.$extension" | while IFS= read -r fichier; do
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
    log "Invalid directory: $folder"
    exit 1
fi

log "$total files processed"