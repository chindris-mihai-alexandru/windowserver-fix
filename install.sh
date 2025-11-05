#!/bin/bash
set -e

# WindowServer Fix - Installation Script
# Supports: macOS Sequoia 15.0+
# Usage: ./install.sh (run from cloned repository)

VERSION="2.1.0"
RELEASE_DATE="November 2025"
INSTALL_DIR="$HOME/windowserver-fix"
REPO_URL="https://github.com/chindri-mihai-alexandru/windowserver-fix"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.windowserver-fix.daemon.plist"

echo "============================================"
echo "WindowServer Fix Installer v$VERSION"
echo "============================================"
echo

# Check macOS version
check_macos_version() {
    sw_vers_output=$(sw_vers -productVersion)
    major=$(echo "$sw_vers_output" | cut -d. -f1)
    minor=$(echo "$sw_vers_output" | cut -d. -f2 2>/dev/null || echo "0")
    
    echo "Detected macOS version: $sw_vers_output"
    
    if [ "$major" -lt 15 ]; then
        echo "⚠️  Warning: This tool is designed for macOS Sequoia (15.0+)"
        echo "   Your version: $sw_vers_output"
        echo "   The WindowServer memory leak primarily affects Sequoia."
        echo
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 0
        fi
    else
        echo "✓ macOS Sequoia detected - this tool will help fix memory leaks"
    fi
    echo
}

# Check if already installed
check_existing_installation() {
    if [ -d "$INSTALL_DIR" ]; then
        echo "WindowServer Fix is already installed at: $INSTALL_DIR"
        echo
        
        # Check if daemon is running
        if [ -f "$INSTALL_DIR/.daemon.pid" ]; then
            pid=$(cat "$INSTALL_DIR/.daemon.pid")
            if ps -p "$pid" > /dev/null 2>&1; then
                echo "⚠️  Daemon is currently running (PID: $pid)"
                echo "   Stopping daemon before update..."
                cd "$INSTALL_DIR" && ./daemon.sh stop
            fi
        fi
        
        read -p "Do you want to update/reinstall? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 0
        fi
        
        # Backup existing logs
        if [ -d "$INSTALL_DIR/logs" ]; then
            backup_dir="$INSTALL_DIR/backups/logs_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r "$INSTALL_DIR/logs/"* "$backup_dir/" 2>/dev/null || true
            echo "✓ Backed up existing logs to: $backup_dir"
        fi
    fi
}

# Install files
install_files() {
    echo "Installing WindowServer Fix..."
    
    # Create directory structure
    mkdir -p "$INSTALL_DIR"/{logs,backups}
    echo "✓ Created directories"
    
    # Copy files (if running from cloned repo) or download (if curl install)
    if [ -f "$(dirname "$0")/monitor.sh" ]; then
        # Local installation from cloned repo
        cp "$(dirname "$0")"/*.sh "$INSTALL_DIR/"
        [ -f "$(dirname "$0")/README.md" ] && cp "$(dirname "$0")/README.md" "$INSTALL_DIR/"
        [ -f "$(dirname "$0")/LICENSE" ] && cp "$(dirname "$0")/LICENSE" "$INSTALL_DIR/"
        echo "✓ Copied files from local repository"
    else
        # Remote installation via curl
        echo "⚠️  Remote installation not yet implemented"
        echo "   Please clone the repository manually:"
        echo "   git clone $REPO_URL ~/windowserver-fix"
        exit 1
    fi
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR"/*.sh
    echo "✓ Made scripts executable"
}

# Setup LaunchAgent for auto-start
setup_launch_agent() {
    echo
    read -p "Do you want to start the daemon automatically at login? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping LaunchAgent setup"
        return
    fi
    
    mkdir -p "$HOME/Library/LaunchAgents"
    
    cat > "$LAUNCH_AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.windowserver-fix.daemon</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/daemon.sh</string>
        <string>start</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/logs/launchagent.out</string>
    
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/logs/launchagent.err</string>
    
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
</dict>
</plist>
EOF
    
    echo "✓ Created LaunchAgent: $LAUNCH_AGENT_PLIST"
    
    # Load the LaunchAgent
    launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    launchctl load "$LAUNCH_AGENT_PLIST"
    
    echo "✓ LaunchAgent loaded - daemon will start automatically at login"
}

# Main installation flow
main() {
    check_macos_version
    check_existing_installation
    install_files
    setup_launch_agent
    
    echo
    echo "============================================"
    echo "Installation complete!"
    echo "============================================"
    echo
    echo "Quick Start:"
    echo "  cd ~/windowserver-fix"
    echo "  ./fix.sh              # Apply all fixes manually"
    echo "  ./monitor.sh check    # Check current WindowServer status"
    echo "  ./daemon.sh start     # Start background monitoring daemon"
    echo "  ./daemon.sh stop      # Stop daemon"
    echo "  ./dashboard.sh        # View interactive dashboard"
    echo
    echo "Documentation:"
    echo "  README.md             # Full documentation"
    echo "  SECURITY.md           # Privacy & security information"
    echo "  TROUBLESHOOTING.md    # Common issues & solutions"
    echo
    echo "To uninstall: ~/windowserver-fix/uninstall.sh"
    echo
    
    # Offer to run initial check
    read -p "Do you want to check WindowServer status now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$INSTALL_DIR" && ./monitor.sh check
        
        echo
        read -p "Do you want to start the daemon now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$INSTALL_DIR" && ./daemon.sh start
        fi
    fi
    
    echo
    echo "Thank you for using WindowServer Fix!"
    echo "For support and updates, visit: $REPO_URL"
}

show_version() {
    echo "WindowServer Fix Installer v${VERSION}"
    echo "Release Date: ${RELEASE_DATE}"
    echo "macOS Sequoia (15.x) Memory Leak Mitigation Toolkit"
}

show_help() {
    cat << EOF
WindowServer Fix Installer v${VERSION}

Usage: $0 [option]

Options:
    (no args)  - Run installation (default)
    version    - Show version information
    help       - Show this help message

Installation:
    This script will:
    1. Check your macOS version
    2. Install scripts to ~/windowserver-fix/
    3. Set up automatic monitoring daemon (optional)

For more information, visit: $REPO_URL
EOF
}

# Parse arguments
case "${1:-install}" in
    install)
        main
        ;;
    version|--version|-v)
        show_version
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
