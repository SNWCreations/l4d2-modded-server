#!/bin/bash
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed directly, not sourced."
    echo "Run: ./install-pwsh.sh"
    return 1
fi
set -e

if command -v pwsh &> /dev/null; then
    echo "PowerShell (pwsh) is already installed."
    exit 0
fi

echo "PowerShell (pwsh) is not installed. Installing using Microsoft's official script..."
curl -sSL https://aka.ms/install-powershell.sh | bash
