#!/bin/bash

# WindowServer Fix - Quick Setup

echo "==================================="
echo "WindowServer Fix - Quick Setup"
echo "==================================="
echo

INSTALL_DIR="$HOME/windowserver-fix"

# Check if already installed
if [ -d "$INSTALL_DIR" ]; then
    echo "WindowServer Fix is already installed at: $INSTALL_DIR"
    echo
    read -p "Do you want to update? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
fi

# Create directories
mkdir -p "$INSTALL_DIR"/{logs,backups}

echo "✓ Created directories"

# Check if scripts are executable
for script in monitor.sh fix.sh daemon.sh; do
    if [ -f "$INSTALL_DIR/$script" ]; then
        chmod +x "$INSTALL_DIR/$script"
        echo "✓ Made $script executable"
    fi
done

echo
echo "Installation complete!"
echo
echo "Quick Start:"
echo "  cd ~/windowserver-fix"
echo "  ./fix.sh              # Apply all fixes"
echo "  ./monitor.sh check    # Check current status"
echo "  ./daemon.sh start     # Start background monitoring"
echo
echo "For more information, see README.md"
echo

# Offer to run initial check
read -p "Do you want to check WindowServer status now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$INSTALL_DIR" && ./monitor.sh check
fi
