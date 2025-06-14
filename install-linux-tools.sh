#!/bin/bash
set -e

missing=0

if ! command -v curl &> /dev/null; then
    echo "curl is not installed."
    missing=1
fi

if ! command -v rsync &> /dev/null; then
    echo "rsync is not installed."
    missing=1
fi

if [ "$missing" -eq 0 ]; then
    echo "curl and rsync are already installed."
    exit 0
fi

echo "Attempting to install curl and rsync..."

if [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y curl rsync
elif [ -f /etc/redhat-release ]; then
    sudo yum install -y curl rsync
elif [ -f /etc/arch-release ]; then
    sudo pacman -Sy --noconfirm curl rsync
else
    echo "Unsupported Linux distribution. Please install curl and rsync manually."
    exit 1
fi
