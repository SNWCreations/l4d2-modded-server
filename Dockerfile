FROM debian:bookworm-slim

# Install dependencies for SteamCMD and L4D2 server
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        lib32gcc-s1 \
        lib32stdc++6 \
        curl \
        rsync \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /server

# Copy repo files (game files will be downloaded at runtime)
COPY left4dead2/ ./left4dead2/
COPY start.sh server.ini ./

RUN chmod +x start.sh

# Default server port
EXPOSE 27015/udp
EXPOSE 27015/tcp

ENTRYPOINT ["./start.sh"]
