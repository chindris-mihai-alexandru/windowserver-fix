#!/bin/bash

# WindowServer Fix - Uninstall Script
# Safely removes all components of WindowServer Fix

INSTALL_DIR="$HOME/windowserver-fix"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.windowserver-fix.daemon.plist"

echo "============================================"
echo "WindowServer Fix - Uninstaller"
echo "============================================"
echo

# Confirm uninstallation
echo "This will remove:"
echo "  • WindowServer Fix daemon and scripts"
echo "  • LaunchAgent (auto-start configuration)"
echo "  • All files in: $INSTALL_DIR"
echo
echo "⚠️  Warning: Logs and configuration will be deleted!"
echo

read -p "Are you sure you want to uninstall? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled"
    exit 0
fi

echo

# Step 1: Stop running daemon
echo "Step 1/4: Stopping daemon..."
if [ -f "$INSTALL_DIR/.daemon.pid" ]; then
    pid=$(cat "$INSTALL_DIR/.daemon.pid")
    if ps -p "$pid" > /dev/null 2>&1; then
        if [ -f "$INSTALL_DIR/daemon.sh" ]; then
            cd "$INSTALL_DIR" && ./daemon.sh stop
            echo "✓ Daemon stopped (was PID: $pid)"
        else
            kill "$pid" 2>/dev/null && echo "✓ Killed daemon process (PID: $pid)"
        fi
    else
        echo "✓ Daemon not running"
    fi
else
    echo "✓ No daemon PID file found"
fi

# Step 2: Unload and remove LaunchAgent
echo
echo "Step 2/4: Removing LaunchAgent..."
if [ -f "$LAUNCH_AGENT_PLIST" ]; then
    launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null
    rm "$LAUNCH_AGENT_PLIST"
    echo "✓ LaunchAgent removed and unloaded"
else
    echo "✓ No LaunchAgent found"
fi

# Step 3: Offer to backup logs
echo
echo "Step 3/4: Handling logs..."
if [ -d "$INSTALL_DIR/logs" ] && [ "$(ls -A "$INSTALL_DIR/logs" 2>/dev/null)" ]; then
    read -p "Do you want to backup logs before deletion? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        backup_path="$HOME/windowserver-fix-backup-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_path"
        cp -r "$INSTALL_DIR/logs" "$backup_path/"
        echo "✓ Logs backed up to: $backup_path"
    else
        echo "✓ Logs will be deleted"
    fi
else
    echo "✓ No logs found"
fi

# Step 4: Remove installation directory
echo
echo "Step 4/4: Removing installation directory..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "✓ Removed: $INSTALL_DIR"
else
    echo "✓ Installation directory not found"
fi

echo
echo "============================================"
echo "Uninstallation complete!"
echo "============================================"
echo
echo "WindowServer Fix has been completely removed from your system."
echo
echo "If you experienced issues, please report them at:"
echo "  https://github.com/chindri-mihai-alexandru/windowserver-fix/issues"
echo
echo "To reinstall in the future:"
echo "  git clone https://github.com/chindri-mihai-alexandru/windowserver-fix.git ~/windowserver-fix"
echo "  cd ~/windowserver-fix && ./install.sh"
echo
echo "Thank you for trying WindowServer Fix!"
