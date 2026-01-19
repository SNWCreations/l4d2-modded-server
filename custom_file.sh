#!/bin/bash
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed directly, not sourced."
    echo "Run: ./custom_file.sh"
    return 1
fi
DIR="$(cd "$(dirname "$0")"; pwd)"
"$DIR/install-pwsh.sh"

pwsh -File "$DIR/custom_file.ps1" "$@"
