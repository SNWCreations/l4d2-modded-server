#!/bin/bash
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed directly, not sourced."
    echo "Run: ./start.sh"
    return 1
fi
set -e

ROOT_DIR="$(cd "$(dirname "$0")"; pwd)"

if [ ! -f server.ini ]; then
    touch server.ini
fi

# Load variables from server.ini
set -a
source server.ini
set +a

echo "If you want to quit, close the Left 4 Dead 2 window and type Y followed by Enter."

# Ensure PowerShell is installed (terminate if install fails)
"$ROOT_DIR/install-pwsh.sh"

# Ensure required Linux tools are installed
"$ROOT_DIR/install-linux-tools.sh"

# Ensure steamcmd exists using Linux installer if not present
if [ ! -x "$ROOT_DIR/steamcmd/steamcmd.sh" ]; then
    echo "SteamCMD not found, installing for Linux..."
    mkdir -p "$ROOT_DIR/steamcmd"
    cd "$ROOT_DIR/steamcmd"
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
    cd "$ROOT_DIR"
else
    echo "SteamCMD already exists at $ROOT_DIR/steamcmd/steamcmd.sh"
fi

# Use SteamCMD to download L4D2
echo "Using SteamCMD to check for updates."
"$ROOT_DIR/steamcmd/steamcmd.sh" +force_install_dir ../server +login "$STEAM_USER" +app_update 222860 +quit

# Deleting addons folder so no old plugins are left to cause issues
echo "Deleting addons folder."
rm -rf "$ROOT_DIR/server/left4dead2/addons/"

# Deleting cfg/sourcemod folder
echo "Deleting cfg/sourcemod folder."
rm -rf "$ROOT_DIR/server/left4dead2/cfg/sourcemod/"

# Patch server with mod files
echo "Copying mod files."
rsync -a "$ROOT_DIR/left4dead2/" "$ROOT_DIR/server/left4dead2/"

# Rename MetaMod-supplied metamod_x64.linux.vdf to metamod_x64.vdf if present
if [ -f "$ROOT_DIR/server/left4dead2/addons/metamod_x64.linux.vdf" ]; then
    cp -f "$ROOT_DIR/server/left4dead2/addons/metamod_x64.linux.vdf" "$ROOT_DIR/server/left4dead2/addons/metamod_x64.vdf"
fi

# Fail if metamod_x64.vdf does not exist
if [ ! -f "$ROOT_DIR/server/left4dead2/addons/metamod_x64.vdf" ]; then
    echo "ERROR: metamod_x64.vdf not found in server/left4dead2/addons. Startup aborted."
    exit 1
fi

# Merge your custom files in
echo "Copying custom files."
rsync -a "$ROOT_DIR/custom_files/" "$ROOT_DIR/server/left4dead2/"

# Merge your custom files secrets in (if they exist)
if [ -d "$ROOT_DIR/custom_files_secret/" ]; then
    echo "Copying custom files secret from custom_files_secret."
    rsync -a "$ROOT_DIR/custom_files_secret/" "$ROOT_DIR/server/left4dead2/"
fi

echo "Left 4 Dead 2 started."

# Start server as separate process
"$ROOT_DIR/server/srcds_run" -console -game left4dead2 -port "$PORT" -tickrate "$TICKRATE" +log on +sv_setmax 31 +sv_maxplayers "$MAXPLAYERS" +sv_visiblemaxplayers "$MAXPLAYERS" +sv_lan "$LAN" +map "$MAP" +exec "$EXEC"

echo "WARNING: L4D2 closed or crashed."
read -p "Press Enter to exit..."
