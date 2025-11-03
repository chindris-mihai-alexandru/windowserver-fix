#!/bin/bash

# WindowServer Fix Script
# Implements various mitigation strategies for WindowServer high CPU/memory usage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/fix_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_warning() {
    log "${YELLOW}⚠ $1${NC}"
}

log_error() {
    log "${RED}✗ $1${NC}"
}

log_info() {
    log "${BLUE}ℹ $1${NC}"
}

check_sudo() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Do not run this script with sudo. It will ask for password when needed."
        exit 1
    fi
}

backup_settings() {
    log_info "Backing up current settings..."
    backup_dir="$SCRIPT_DIR/backups/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup WindowServer display preferences
    if [ -f ~/Library/Preferences/ByHost/com.apple.windowserver.* ]; then
        cp ~/Library/Preferences/ByHost/com.apple.windowserver.* "$backup_dir/" 2>/dev/null || true
    fi
    
    # Backup Dock preferences
    defaults read com.apple.dock > "$backup_dir/dock_preferences.plist" 2>/dev/null || true
    
    # Backup Universal Access preferences
    defaults read com.apple.universalaccess > "$backup_dir/universalaccess_preferences.plist" 2>/dev/null || true
    
    log_success "Settings backed up to: $backup_dir"
    echo "$backup_dir" > "$SCRIPT_DIR/.last_backup"
}

fix_transparency() {
    log_info "Applying transparency fix..."
    
    current=$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo "0")
    
    if [ "$current" = "1" ]; then
        log_warning "Reduce transparency already enabled"
        return 0
    fi
    
    defaults write com.apple.universalaccess reduceTransparency -bool true
    log_success "Transparency effects reduced"
}

fix_dock_animations() {
    log_info "Optimizing Dock animations..."
    
    # Disable automatic Space rearrangement
    defaults write com.apple.dock mru-spaces -bool false
    
    # Speed up Mission Control animations
    defaults write com.apple.dock expose-animation-duration -float 0.1
    
    # Disable Dashboard
    defaults write com.apple.dashboard mcx-disabled -bool true
    
    log_success "Dock animations optimized"
}

fix_window_shadows() {
    log_info "Disabling window shadows for screenshots..."
    
    defaults write com.apple.screencapture disable-shadow -bool true
    defaults write com.apple.screencapture show-thumbnail -bool false
    
    log_success "Screenshot shadows disabled"
}

clean_windowserver_cache() {
    log_info "Cleaning WindowServer caches..."
    
    # Remove WindowServer display preferences (will be regenerated)
    ws_plist=$(find ~/Library/Preferences/ByHost/ -name "com.apple.windowserver.displays.*.plist" 2>/dev/null)
    
    if [ -n "$ws_plist" ]; then
        log_warning "Found WindowServer display preferences: $ws_plist"
        read -p "Do you want to remove and regenerate them? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$ws_plist"
            log_success "WindowServer display preferences removed (will regenerate on next login)"
        else
            log_info "Skipping WindowServer preferences removal"
        fi
    fi
}

fix_display_resolution() {
    log_info "Checking display resolution settings..."
    
    display_count=$(system_profiler SPDisplaysDataType | grep -c "Resolution:")
    log_info "Connected displays: $display_count"
    
    if [ "$display_count" -gt 1 ]; then
        log_warning "Multiple displays detected. High-resolution external displays are a common cause."
        log_info "Consider using default (non-scaled) resolution for external displays."
        log_info "Go to: System Settings > Displays > Select your external display > Use default resolution"
    fi
}

optimize_power_settings() {
    log_info "Optimizing power management settings..."
    
    # Prevent automatic graphics switching (if on MacBook)
    if system_profiler SPHardwareDataType | grep -q "Book"; then
        log_info "Detected MacBook - checking graphics settings"
        log_warning "If you have automatic graphics switching enabled, consider disabling it:"
        log_info "System Settings > Battery > Options > Automatic graphics switching"
    fi
}

fix_login_items() {
    log_info "Checking for problematic login items..."
    
    # List login items that might cause issues
    problematic_apps=(
        "DisplayLink"
        "BetterDisplay"
        "SwitchResX"
        "Magnet"
        "Rectangle"
        "Bartender"
    )
    
    for app in "${problematic_apps[@]}"; do
        if osascript -e "tell application \"System Events\" to get the name of every login item" 2>/dev/null | grep -q "$app"; then
            log_warning "Found potentially problematic login item: $app"
            log_info "Consider temporarily disabling it to test if it's causing issues"
        fi
    done
}

restart_windowserver() {
    log_warning "Restarting WindowServer will log you out and close all applications!"
    read -p "Do you want to restart WindowServer now? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restarting WindowServer..."
        sudo killall -HUP WindowServer
    else
        log_info "Skipping WindowServer restart. Changes will take effect after logout/restart."
    fi
}

apply_all_fixes() {
    log_info "=== Starting WindowServer Fix Process ==="
    
    backup_settings
    
    fix_transparency
    fix_dock_animations
    fix_window_shadows
    clean_windowserver_cache
    fix_display_resolution
    optimize_power_settings
    fix_login_items
    
    # Restart Dock to apply changes
    killall Dock 2>/dev/null || true
    
    log_success "=== All fixes applied successfully ==="
    log_info "Some changes require a logout/restart to take full effect."
    
    restart_windowserver
}

show_current_status() {
    log_info "=== Current WindowServer Status ==="
    
    stats=$(ps aux | grep "WindowServer" | grep -v grep | awk '{print $3, $4, $6}')
    cpu=$(echo "$stats" | awk '{print $1}')
    mem_percent=$(echo "$stats" | awk '{print $2}')
    mem_kb=$(echo "$stats" | awk '{print $3}')
    mem_mb=$((mem_kb / 1024))
    
    echo "CPU Usage: ${cpu}%"
    echo "Memory Usage: ${mem_mb}MB (${mem_percent}%)"
    
    echo -e "\nCurrent Settings:"
    echo "  Reduce Transparency: $(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo 'not set')"
    echo "  MRU Spaces: $(defaults read com.apple.dock mru-spaces 2>/dev/null || echo 'not set')"
    echo "  Connected Displays: $(system_profiler SPDisplaysDataType | grep -c 'Resolution:')"
}

restore_backup() {
    if [ ! -f "$SCRIPT_DIR/.last_backup" ]; then
        log_error "No backup found to restore"
        exit 1
    fi
    
    backup_dir=$(cat "$SCRIPT_DIR/.last_backup")
    
    if [ ! -d "$backup_dir" ]; then
        log_error "Backup directory not found: $backup_dir"
        exit 1
    fi
    
    log_info "Restoring settings from: $backup_dir"
    
    # Restore WindowServer preferences
    if ls "$backup_dir"/com.apple.windowserver.* 1> /dev/null 2>&1; then
        cp "$backup_dir"/com.apple.windowserver.* ~/Library/Preferences/ByHost/
        log_success "WindowServer preferences restored"
    fi
    
    # Restore other preferences would require plutil or defaults import
    log_warning "Some preferences require manual restoration from backup files"
    
    killall Dock 2>/dev/null || true
    log_success "Restoration complete. Please logout and login again."
}

show_help() {
    cat << EOF
WindowServer Fix Script - Help

Usage: $0 [command]

Commands:
    fix         Apply all fixes (default)
    status      Show current WindowServer status
    backup      Backup current settings only
    restore     Restore from last backup
    clean       Clean WindowServer cache only
    help        Show this help message

Examples:
    $0           # Apply all fixes
    $0 status    # Check current status
    $0 backup    # Backup settings before making changes
    $0 restore   # Restore previous settings

For more information, visit: https://github.com/yourusername/windowserver-fix
EOF
}

# Main execution
mkdir -p "$SCRIPT_DIR/logs"
mkdir -p "$SCRIPT_DIR/backups"

check_sudo

case "${1:-fix}" in
    fix)
        apply_all_fixes
        ;;
    status)
        show_current_status
        ;;
    backup)
        backup_settings
        ;;
    restore)
        restore_backup
        ;;
    clean)
        backup_settings
        clean_windowserver_cache
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
