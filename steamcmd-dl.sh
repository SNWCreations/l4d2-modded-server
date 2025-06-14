#!/bin/bash
# This script installs SteamCMD for Linux

DIR="$(cd "$(dirname "$0")"; pwd)"
"$DIR/install-pwsh.sh"
"$DIR/install-linux-tools.sh"

STEAMCMD_SH="$DIR/steamcmd/steamcmd.sh"
if [ ! -x "$STEAMCMD_SH" ]; then
    echo "SteamCMD not found, installing for Linux..."
    mkdir -p "$DIR/steamcmd"
    cd "$DIR/steamcmd"
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
    cd "$DIR"
else
    echo "SteamCMD already exists at $STEAMCMD_SH"
fi
