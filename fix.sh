#!/bin/bash

# WindowServer Fix Script v2.1
# Implements intelligent mitigation strategies for WindowServer high CPU/memory usage
# Updated November 2025 for macOS Sequoia (15.x) with root cause analysis

set -e

# Version information
readonly VERSION="2.1.0"
readonly RELEASE_DATE="November 2025"

# Check required dependencies
if ! command -v bc >/dev/null 2>&1; then
    echo "Error: bc is required but not installed. Install with: brew install bc" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/fix_$(date +%Y%m%d_%H%M%S).log"

# Memory thresholds (MB)
readonly MEM_THRESHOLD_WARNING=2048
readonly MEM_THRESHOLD_CRITICAL=5120
readonly MEM_THRESHOLD_EMERGENCY=20480

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

# 2025 macOS Detection Functions
get_macos_version() {
    sw_vers -productVersion | cut -d. -f1
}

is_sequoia() {
    version=$(get_macos_version)
    [ "$version" -ge 15 ]
}

detect_iphone_mirroring() {
    pgrep -q "iPhone Mirroring" && echo "ACTIVE" || echo "INACTIVE"
}

kill_iphone_mirroring() {
    log_info "Checking for iPhone Mirroring process..."
    
    if pgrep -q "iPhone Mirroring"; then
        log_warning "iPhone Mirroring is active - known Sequoia leak trigger"
        read -p "Kill iPhone Mirroring process? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pkill "iPhone Mirroring"
            log_success "iPhone Mirroring terminated"
        else
            log_info "Skipping iPhone Mirroring termination"
        fi
    else
        log_success "iPhone Mirroring not running"
    fi
}

disable_iphone_mirroring_feature() {
    if is_sequoia; then
        log_info "Disabling iPhone Mirroring feature (Sequoia)..."
        
        # Note: There's no direct defaults command to disable iPhone Mirroring
        # User must do this manually in System Settings
        log_warning "To permanently disable iPhone Mirroring:"
        log_info "  1. Go to System Settings > General > AirDrop & Handoff"
        log_info "  2. Turn off 'iPhone Mirroring'"
        log_info "  3. Restart your Mac"
    fi
}

check_promotion_displays() {
    log_info "Checking for ProMotion displays..."
    
    if system_profiler SPDisplaysDataType | grep -q "120 Hz"; then
        log_warning "ProMotion (120Hz) display detected"
        log_info "If experiencing issues, try disabling ProMotion:"
        log_info "  System Settings > Displays > Refresh Rate > 60 Hz"
    else
        log_success "No ProMotion displays detected"
    fi
}

check_ultrawide_displays() {
    log_info "Checking for ultra-wide/high-res displays..."
    
    ultrawide=$(system_profiler SPDisplaysDataType | grep "Resolution:" | awk '{
        width = $2
        if (width >= 5120) print width " x " $4 " (ULTRA-WIDE)"
    }')
    
    if [ -n "$ultrawide" ]; then
        log_warning "Ultra-wide display detected: $ultrawide"
        log_warning "Ultra-wide displays (>5K) are HIGH-RISK leak triggers in Sequoia"
        log_info "Recommendation: Use default (non-scaled) resolution"
        log_info "  System Settings > Displays > Use 'Default for display'"
    else
        log_success "No ultra-wide displays detected"
    fi
}

check_problematic_browsers() {
    log_info "Checking for browsers with known video playback issues..."
    
    firefox_running=$(pgrep -q Firefox && echo "YES" || echo "NO")
    chrome_running=$(pgrep -q "Google Chrome" && echo "YES" || echo "NO")
    
    if [ "$firefox_running" = "YES" ]; then
        log_warning "Firefox is running - fullscreen video can trigger leaks"
        log_info "Consider using Safari for video playback instead"
    fi
    
    if [ "$chrome_running" = "YES" ]; then
        log_warning "Chrome is running - fullscreen video can trigger leaks"
        log_info "Consider using Safari for video playback instead"
    fi
    
    if [ "$firefox_running" = "NO" ] && [ "$chrome_running" = "NO" ]; then
        log_success "No problematic browsers detected"
    fi
}

sequoia_specific_checks() {
    if ! is_sequoia; then
        return 0
    fi
    
    log_info "=== macOS Sequoia (15.x) Leak Detection ==="
    log_warning "Running Sequoia $(sw_vers -productVersion) - enhanced leak monitoring active"
    
    kill_iphone_mirroring
    disable_iphone_mirroring_feature
    check_promotion_displays
    check_ultrawide_displays
    check_problematic_browsers
    
    log_info "=== Sequoia Checks Complete ==="
}

backup_settings() {
    log_info "Backing up current settings..."
    backup_dir="$SCRIPT_DIR/backups/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup WindowServer display preferences
    if ls ~/Library/Preferences/ByHost/com.apple.windowserver.* > /dev/null 2>&1; then
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
        log_info "Restarting WindowServer in 3 seconds..."
        sleep 1 && echo "3..." && sleep 1 && echo "2..." && sleep 1 && echo "1..."
        sudo killall -HUP WindowServer
    else
        log_info "Skipping WindowServer restart. Changes will take effect after logout/restart."
    fi
}

apply_intelligent_fixes() {
    log_info "=== Running Intelligent Diagnosis ==="
    
    # Check if diagnose.sh exists
    if [ ! -f "$SCRIPT_DIR/diagnose.sh" ]; then
        log_warning "diagnose.sh not found - skipping intelligent analysis"
        return 0
    fi
    
    # Run diagnosis and capture output
    diag_output=$(bash "$SCRIPT_DIR/diagnose.sh" 2>/dev/null || echo "")
    
    # Parse for known culprits
    obs_detected=$(echo "$diag_output" | grep -q "OBS" && echo "YES" || echo "NO")
    zoom_detected=$(echo "$diag_output" | grep -q "Zoom" && echo "YES" || echo "NO")
    chrome_tabs=$(echo "$diag_output" | grep "Chrome.*tabs" | grep -oE '[0-9]+ tabs' | grep -oE '[0-9]+' || echo "0")
    screen_recording=$(echo "$diag_output" | grep -q "Screen recording active" && echo "YES" || echo "NO")
    
    # Apply targeted fixes based on diagnosis
    if [ "$obs_detected" = "YES" ]; then
        log_warning "OBS detected - known major leak source (screen recording buffers)"
        log_info "Recommendation: Close OBS when not actively recording"
        read -p "Kill OBS now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pkill -9 "OBS" 2>/dev/null && log_success "OBS terminated" || log_warning "OBS not running"
        fi
    fi
    
    if [ "$zoom_detected" = "YES" ]; then
        log_warning "Zoom detected - video conferencing can cause memory buildup"
        log_info "Recommendation: Restart Zoom between long meetings"
        read -p "Restart Zoom now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pkill "zoom.us" 2>/dev/null
            sleep 2
            open -a "zoom.us" 2>/dev/null && log_success "Zoom restarted" || log_warning "Could not restart Zoom"
        fi
    fi
    
    if [ "$chrome_tabs" -gt 50 ]; then
        log_warning "Chrome has ${chrome_tabs} tabs open - can cause WindowServer memory leaks"
        log_info "Recommendation: Close unused tabs or restart Chrome"
        read -p "Restart Chrome now? (WARNING: Will close all tabs) (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pkill "Google Chrome" 2>/dev/null
            sleep 2
            log_success "Chrome closed - relaunch manually to restore session"
        fi
    fi
    
    if [ "$screen_recording" = "YES" ]; then
        log_warning "Active screen recording detected - constantly buffers frames"
        log_info "Stop screen recording when not needed to prevent memory buildup"
    fi
    
    # Check for display utilities
    betterdisp=$(pgrep -q "BetterDisplay" && echo "YES" || echo "NO")
    switchres=$(pgrep -q "SwitchResX" && echo "YES" || echo "NO")
    
    if [ "$betterdisp" = "YES" ] || [ "$switchres" = "YES" ]; then
        log_warning "Display utility detected (BetterDisplay/SwitchResX)"
        log_info "These can cause WindowServer issues with custom resolutions"
        log_info "Consider temporarily disabling to test if they're the cause"
    fi
    
    log_success "=== Intelligent diagnosis complete ==="
}

emergency_restart_windowserver() {
    log_error "EMERGENCY: Forcing WindowServer restart to prevent system crash"
    log_warning "This will immediately log you out!"
    
    # No confirmation in emergency mode
    sudo killall -HUP WindowServer
}

apply_all_fixes() {
    log_info "=== Starting WindowServer Fix Process (v2.1 - Nov 2025) ==="
    log_info "macOS Version: $(sw_vers -productVersion)"
    
    backup_settings
    
    # Run intelligent diagnosis first (v2.1 feature)
    apply_intelligent_fixes
    
    # Run Sequoia-specific checks
    sequoia_specific_checks
    
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
    
    if is_sequoia; then
        log_warning "Sequoia-specific recommendations:"
        log_info "  • Keep macOS updated (Apple is working on leak fixes)"
        log_info "  • Avoid iPhone Mirroring if possible"
        log_info "  • Use Safari instead of Firefox/Chrome for video"
        log_info "  • Monitor memory with: ./monitor.sh monitor"
        log_info "  • Run diagnosis: ./diagnose.sh"
    fi
    
    log_info "Some changes require a logout/restart to take full effect."
    
    restart_windowserver
}

show_current_status() {
    log_info "=== Current WindowServer Status ==="
    log_info "macOS Version: $(sw_vers -productVersion)"
    
    # Get WindowServer PID
    ws_pid=$(pgrep WindowServer)
    
    # Use top for accurate memory (matches Activity Monitor)
    cpu=$(ps aux | grep "WindowServer" | grep -v grep | awk '{print $3}')
    mem_str=$(top -l 1 -stats pid,command,mem -pid "$ws_pid" | grep WindowServer | awk '{print $3}')
    
    # Convert memory string (e.g., "12G", "500M", "100K") to MB
    if [[ $mem_str == *G ]]; then
        mem_mb=$(echo "${mem_str%G} * 1024" | bc | cut -d. -f1)
    elif [[ $mem_str == *M ]]; then
        mem_mb=$(echo "${mem_str%M}" | cut -d. -f1)
    elif [[ $mem_str == *K ]]; then
        mem_mb=$(echo "${mem_str%K} / 1024" | bc | cut -d. -f1)
    else
        mem_mb=0
    fi
    
    # Calculate percentage of total memory
    total_mem=$(sysctl -n hw.memsize)
    total_mem_mb=$((total_mem / 1024 / 1024))
    mem_percent=$(echo "scale=1; ($mem_mb * 100) / $total_mem_mb" | bc)
    
    echo "CPU Usage: ${cpu}%"
    echo "Memory Usage: ${mem_mb}MB (${mem_percent}%)"
    
    # 2025 Sequoia Status
    if is_sequoia; then
        echo -e "\nmacOS Sequoia Leak Detection:"
        echo "  iPhone Mirroring: $(detect_iphone_mirroring)"
        echo "  ProMotion: $(system_profiler SPDisplaysDataType | grep -q '120 Hz' && echo 'ENABLED' || echo 'DISABLED')"
        
        # Memory severity assessment
        if [ "$mem_mb" -gt "$MEM_THRESHOLD_EMERGENCY" ]; then
            echo -e "  ${RED}Status: EMERGENCY (${mem_mb}MB) - Restart recommended!${NC}"
        elif [ "$mem_mb" -gt "$MEM_THRESHOLD_CRITICAL" ]; then
            echo -e "  ${RED}Status: CRITICAL (${mem_mb}MB) - Leak detected${NC}"
        elif [ "$mem_mb" -gt "$MEM_THRESHOLD_WARNING" ]; then
            echo -e "  ${YELLOW}Status: WARNING (${mem_mb}MB) - Monitoring${NC}"
        else
            echo -e "  ${GREEN}Status: NORMAL (${mem_mb}MB)${NC}"
        fi
    fi
    
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

show_version() {
    echo "WindowServer Fix Script v${VERSION}"
    echo "Release Date: ${RELEASE_DATE}"
    echo "macOS Sequoia (15.x) Memory Leak Mitigation Toolkit"
}

show_help() {
    cat << EOF
WindowServer Fix Script v2.1 - Help (November 2025)

Usage: $0 [command]

Commands:
    fix                Apply all fixes (default) with intelligent diagnosis
    status             Show current WindowServer status
    backup             Backup current settings only
    restore            Restore from last backup
    clean              Clean WindowServer cache only
    restart-windowserver  Force restart WindowServer (emergency)
    sequoia-check      Run Sequoia-specific leak checks only
    version            Show version information
    help               Show this help message

v2.1 Intelligent Diagnosis Features:
    • Detects specific apps causing leaks (OBS, Zoom, Chrome, etc.)
    • Provides targeted fixes based on root cause
    • Analyzes browser tab count, screen recording, display config
    • Offers app-specific recommendations before generic fixes

2025 Sequoia-Specific Features:
    • Detects macOS Sequoia (15.x) memory leak patterns
    • iPhone Mirroring detection and termination
    • ProMotion display compatibility checks
    • Ultra-wide display (>5K) warnings
    • Browser compatibility warnings (Firefox/Chrome fullscreen video)
    • Memory severity levels: NORMAL < 500MB, WARNING > 2GB, CRITICAL > 5GB

Examples:
    $0                        # Apply all fixes with intelligent diagnosis
    $0 status                 # Check current status with leak assessment
    $0 sequoia-check          # Run only Sequoia-specific checks
    $0 restart-windowserver   # Emergency restart (if memory > 20GB)

Companion Tools:
    ./diagnose.sh             # Run detailed root cause analysis
    ./health_check.sh         # Check system health
    ./app_patterns.sh         # Analyze historical leak patterns
    ./monitor.sh monitor      # Real-time monitoring

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
    restart-windowserver)
        log_warning "Force restarting WindowServer..."
        restart_windowserver
        ;;
    sequoia-check)
        if is_sequoia; then
            sequoia_specific_checks
        else
            log_info "Not running macOS Sequoia (version: $(sw_vers -productVersion))"
            log_info "Sequoia-specific checks not needed"
        fi
        ;;
    version|--version|-v)
        show_version
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
