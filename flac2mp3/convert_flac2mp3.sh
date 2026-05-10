#!/bin/sh

# Build the container: (watch the point at the end !)
# LibreELEC:~/.config/flactomp3 # docker build -t flac2mp3 .

# Manual run :
# docker run --rm -v /var/media/Kodi_Storage/music:/dir flac2mp3 convert /dir
# docker run --rm -v /var/media/Kodi_Storage/downloard:/dir flac2mp3 convert /dir
# Cron entry (every hour):
# 0 * * * * /storage/.kodi/addons/service.system.docker/bin/docker run --rm -v /media/Kodi_Storage/music:/dir flac2mp3 convert /dir >> /storage/.config/logs/flac-convert.log 2>&1
# 0 * * * * /storage/.kodi/addons/service.system.docker/bin/docker run --rm -v /media/Kodi_Storage/downloads:/dir flac2mp3 split /dir >> /storage/.config/logs/flac-convert.log 2>&1

DRY_RUN="${DRY_RUN:-1}"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [flac2mp3] $*"
}

is_dry_run() {
    [ "$DRY_RUN" = "0" ]
}

# Torrent clients can create sparse/preallocated files where the apparent
# size is final but disk allocation is still incomplete.
is_fully_allocated_file() {
    file="$1"

    [ -f "$file" ] || return 1

    # GNU stat first (Linux), then BSD/macOS fallback.
    apparent_size="$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null)"
    allocated_bytes="$(stat -c '%b %B' "$file" 2>/dev/null | awk '{print $1 * $2}' || stat -f '%b %k' "$file" 2>/dev/null | awk '{print $1 * $2}')"

    if [ -z "$apparent_size" ] || [ -z "$allocated_bytes" ]; then
        log "Unable to read allocation info"
        return 1
    fi

    if [ "$allocated_bytes" -lt "$apparent_size" ]; then
        log "File partially allocated (size=${apparent_size}, on-disk=${allocated_bytes})"
        return 1
    fi

    return 0
}

# Function to convert all flac in a folder into mp3 320
convert_flac_to_mp3(){
    dir="$1"
    extension="flac"
    find "$dir" -name "*.$extension" | while IFS= read -r file; do
        out="${file%.$extension}.mp3"
        log "Converting $file -> $out"

        if ! is_fully_allocated_file "$file"; then
            log "Audio file is not fully downloaded yet"
            continue
        fi

        if is_dry_run; then
            log "DRY_RUN enabled: would convert $file -> $out"
            continue
        fi

        # Convert with overwrite (-y) and check success
        # Use -nostdin to prevent ffmpeg from entering interactive mode with special chars in paths
        if ffmpeg -nostdin -y -i "$file" -map 0:a -c:a libmp3lame -b:a 320k -af "aresample=resampler=soxr:osr=44100" -id3v2_version 3 "$out"; then
            log "Removing source file $file"
            rm "$file" && log "Removed $file"
        else
            log "Conversion failed, keeping source: $file"
        fi
    done
}

# Split fonction called by split_on_cue_and_convert
split_tracks() {
    local AUDIO=$1
    local CUE=$2
    local dir=$(dirname "$AUDIO")

    # 1. Create output folder
    mkdir -p "$dir/tracks"

    # 2. SPLIT FLAC (perfect timings from your CUE)
    shnsplit -d "$dir/tracks" -f "$CUE" -o "flac flac -V --best -o %f -" "$AUDIO" -t "%n - %p - %t"

    # 3. Apply perfect tags from CUE
    cuetag "$CUE" "$dir/tracks"/*.flac

    # 4. convert to mp3
    convert_flac_to_mp3 "$dir/tracks"
}


# Function to split single-file albums based on cue file and convert tracks in mp3
split_on_cue_and_convert(){
    dir="$1"
    cue_list="$(mktemp)"

    cleanup() {
        rm -f "$cue_list"
    }
    trap cleanup EXIT INT TERM

    # Scan the folder and subfolders to locate .cue files (case insensitive)
    find "$dir" -type f -iname "*.cue" > "$cue_list"

    while IFS= read -r cue; do
        log "Found $cue"
        audio="${cue%.cue}.flac"
        flag="${cue%.cue}.processed"
        
        if [ -f "$flag" ]; then
            log "This .cue has already been processed"
            continue
        elif [ -f "$audio" ]; then
            if ! is_fully_allocated_file "$audio"; then
                log "Audio file is not fully downloaded yet, will retry on next run: $audio"
                continue
            fi
            log "Found corresponding audio file: $audio"
            
            if is_dry_run; then
                log "DRY_RUN enabled: would split $audio using $cue"
                continue
            fi
            # Create the flag to not process files twice
            echo "Found corresponding audio file: $audio" > "$flag"

            # Convert input audio file to a standard CD wav (44100 Hz - 16 bit)
            ffmpeg -nostdin -i "$audio" -ar 44100 -ac 2 -sample_fmt s16 "$audio".wav

            # Split tracks according to the .cue data
            split_tracks "$audio".wav "$cue"

            # Remove the intermediate .wav file
            rm "$audio".wav
        else
            log "No corresponding audio file found for $cue"
            if is_dry_run; then
                log "DRY_RUN enabled: flag not created"
                continue
            fi
            # Create the flag to not process files twice
            echo "No corresponding audio file found" > "$flag"
        fi
    done < "$cue_list"
}

if [ "$#" -ne 2 ]; then
    log "Usage: <task (convert or split)> <directory>"
    exit 1
fi

task="$1"
dir="$2"

# Check if the directory exists
if [ ! -d "$dir" ]; then
    log "Directory not found: $dir"
    exit 1
fi

# Check if the task is valid and run it
if [ "$task" = "convert" ]; then
    log "Checking for flac files to convert in $dir"
    convert_flac_to_mp3 "$dir"
elif [ "$task" = "split" ]; then
    log "Checking for single-file albums to split in $dir"
    split_on_cue_and_convert "$dir"
else
    log "Unknown task: $task. Use 'convert' or 'split'."
    exit 1
fi
exit 0