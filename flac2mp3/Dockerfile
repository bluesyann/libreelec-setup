FROM debian:stable-slim

RUN apt-get update && \
    apt-get install -y ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /flac2mp3
COPY convert_flac2mp3.sh /flac2mp3/convert_flac2mp3.sh
RUN chmod +x /flac2mp3/convert_flac2mp3.sh

# Default command: run script, parameters given at docker run time
ENTRYPOINT ["/flac2mp3/convert_flac2mp3.sh"]