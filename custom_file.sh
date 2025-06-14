#!/bin/bash
DIR="$(cd "$(dirname "$0")"; pwd)"
"$DIR/install-pwsh.sh"

pwsh -File "$DIR/custom_file.ps1" "$@"
