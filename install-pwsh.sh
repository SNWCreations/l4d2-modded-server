#!/bin/bash
set -e

if command -v pwsh &> /dev/null; then
    echo "PowerShell (pwsh) is already installed."
    exit 0
fi

echo "PowerShell (pwsh) is not installed. Installing using Microsoft's official script..."
curl -sSL https://aka.ms/install-powershell.sh | bash
