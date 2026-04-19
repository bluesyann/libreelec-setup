#!/bin/bash
#Convertit les fichiers d'une extension donnée en argument

if [ "$#" -ne 2 ]; then
    echo "Arguments : Dossier à traiter, extension à convertir (sans point)"
    exit 1
fi

echo
date
echo "Lancement du script de conversion"

dossier="$1"
extension="$2"
n=0

# Build the container: (watch the point at the end !)
# LibreELEC:~/.config/flactomp3 # docker build -t flac2mp3 .

# Maunual run on Navidrome librairy (/media/Kodi_Storage/music/)
# docker run --rm -v /media/Kodi_Storage/music:/music flac2mp3 /music flac
# Cron entry (every hour):
# 0 * * * * /storage/.kodi/addons/service.system.docker/bin/docker run --rm -v /media/Kodi_Storage/music:/music flac2mp3 /music flac >> /storage/.config/flac-convert.log 2>&1

echo "Repertoire : $dossier"
echo "Extension : .$extension"
IFS=$'\n'

if [ -d "$dossier" ]; then
    for fichier in $(find "$dossier" -name "*.$extension"); do
        out="${fichier%.$extension}.mp3"
        echo "Conversion de $fichier vers $out"
        
        # Convert with overwrite (-y) and check success
        if ffmpeg -y -i "$fichier" -map 0:a -c:a libmp3lame -b:a 320k -af "aresample=resampler=soxr:osr=44100" -id3v2_version 3 "$out"; then
            echo "Suppression de $fichier"
            rm "$fichier" && echo "✓ $fichier supprimé"
        else
            echo "✗ Erreur conversion, original conservé: $fichier"
        fi
        
        sleep 1
        n=$((n+1))
    done
else
    echo "Dossier invalide: $dossier"
    exit 1
fi

echo "$n fichiers traités !"

