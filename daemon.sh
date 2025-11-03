#!/bin/bash

# WindowServer Auto-Fix Daemon v2.0
# Monitors WindowServer and applies fixes when thresholds are exceeded
# Updated November 2025 for macOS Sequoia (15.x) leak auto-detection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/daemon_$(date +%Y%m%d).log"
PID_FILE="$SCRIPT_DIR/.daemon.pid"
HISTORY_FILE="$SCRIPT_DIR/logs/memory_history.txt"
LEAK_EVENTS_LOG="$SCRIPT_DIR/logs/leak_events.log"

# 2025 Sequoia-Specific Configuration
CPU_THRESHOLD=60.0
MEM_THRESHOLD_WARNING=2048    # 2GB - Start monitoring
MEM_THRESHOLD_CRITICAL=5120   # 5GB - Apply fixes
MEM_THRESHOLD_EMERGENCY=20480 # 20GB - Emergency restart
CHECK_INTERVAL=60
ACTION_COOLDOWN=300           # Don't apply fixes more than once every 5 minutes
EMERGENCY_COOLDOWN=3600       # Emergency restart cooldown: 1 hour

last_action_time=0
last_emergency_time=0

get_macos_version() {
    sw_vers -productVersion | cut -d. -f1
}

is_sequoia() {
    version=$(get_macos_version)
    [ "$version" -ge 15 ]
}

detect_iphone_mirroring() {
    pgrep -q "iPhone Mirroring" && echo "1" || echo "0"
}

get_app_count() {
    osascript -e 'tell application "System Events" to count (every window of every process whose background only is false)' 2>/dev/null || echo "0"
}

detect_leak_pattern() {
    mem_mb=$1
    app_count=$2
    
    # Pattern: High memory with few apps
    if [ "$mem_mb" -gt 2048 ] && [ "$app_count" -lt 10 ]; then
        return 1  # Leak detected
    fi
    
    # Pattern: Critical threshold
    if [ "$mem_mb" -gt "$MEM_THRESHOLD_CRITICAL" ]; then
        return 1  # Leak detected
    fi
    
    return 0  # No leak
}

log_leak_event() {
    mem_mb=$1
    
    # Log to leak events file for pattern analysis (app_patterns.sh uses this)
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] LEAK DETECTED - WindowServer: ${mem_mb}MB"
        echo "Active applications:"
        
        # Get all running GUI applications with their memory usage
        ps aux | awk 'NR>1 && $11 ~ /\.app\// {print $11 " - " $4 "% RAM"}' | sort -t '-' -k2 -rn | head -20
        
        echo "---"
    } >> "$LEAK_EVENTS_LOG"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

cleanup() {
    log "Daemon stopped"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM

start_daemon() {
    if [ -f "$PID_FILE" ]; then
        old_pid=$(cat "$PID_FILE")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            echo "Daemon already running with PID $old_pid"
            exit 1
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    echo $$ > "$PID_FILE"
    log "Daemon started with PID $$"
    
    while true; do
        check_and_fix
        sleep "$CHECK_INTERVAL"
    done
}

check_and_fix() {
    # CRITICAL FIX: Use 'top' to get actual memory as shown in Activity Monitor
    ws_pid=$(pgrep WindowServer)
    
    if [ -z "$ws_pid" ]; then
        log "ERROR: WindowServer process not found"
        return
    fi
    
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
    
    current_time=$(date +%s)
    time_since_action=$((current_time - last_action_time))
    time_since_emergency=$((current_time - last_emergency_time))
    
    # 2025 Enhanced Detection
    app_count=$(get_app_count)
    iphone_mirror=$(detect_iphone_mirroring)
    
    # Log current state
    log "Status: CPU=${cpu}%, MEM=${mem_mb}MB, Apps=$app_count, iPhoneMirror=$iphone_mirror"
    
    # Emergency check (Sequoia leak > 20GB)
    if [ "$mem_mb" -gt "$MEM_THRESHOLD_EMERGENCY" ]; then
        if [ "$time_since_emergency" -gt "$EMERGENCY_COOLDOWN" ]; then
            log "🚨 EMERGENCY: Memory at ${mem_mb}MB - FORCING WindowServer restart"
            osascript -e 'display notification "WindowServer using '${mem_mb}'MB - Emergency restart in 10s" with title "WindowServer EMERGENCY" sound name "Basso"' 2>/dev/null
            sleep 10
            sudo killall -HUP WindowServer
            last_emergency_time=$(date +%s)
            return
        else
            log "EMERGENCY condition but in cooldown (${time_since_emergency}s / ${EMERGENCY_COOLDOWN}s)"
        fi
    fi
    
    # Check if action needed
    needs_action=0
    action_type="NONE"
    
    # CPU threshold
    if (( $(echo "$cpu > $CPU_THRESHOLD" | bc -l) )); then
        log "WARNING: CPU usage high (${cpu}% > ${CPU_THRESHOLD}%)"
        needs_action=1
        action_type="CPU"
    fi
    
    # Sequoia leak detection
    if is_sequoia && [ "$mem_mb" -gt "$MEM_THRESHOLD_CRITICAL" ]; then
        log "⚠️  CRITICAL: Sequoia memory leak detected (${mem_mb}MB > ${MEM_THRESHOLD_CRITICAL}MB)"
        needs_action=1
        action_type="SEQUOIA_LEAK"
    elif [ "$mem_mb" -gt "$MEM_THRESHOLD_WARNING" ]; then
        if detect_leak_pattern "$mem_mb" "$app_count"; then
            true  # No leak pattern
        else
            log "⚠️  WARNING: Potential leak pattern detected"
            needs_action=1
            action_type="LEAK_PATTERN"
        fi
    fi
    
    # Apply mitigation if needed and cooldown expired
    if [ "$needs_action" -eq 1 ] && [ "$time_since_action" -gt "$ACTION_COOLDOWN" ]; then
        log "Applying automatic fixes (type: $action_type)..."
        
        # Log leak event for pattern analysis
        log_leak_event "$mem_mb"
        
        apply_automatic_fixes "$action_type" "$mem_mb" "$iphone_mirror"
        last_action_time=$(date +%s)
    elif [ "$needs_action" -eq 1 ]; then
        log "Fixes needed but in cooldown period (${time_since_action}s / ${ACTION_COOLDOWN}s)"
    fi
}

apply_automatic_fixes() {
    action_type=$1
    mem_mb=$2
    iphone_mirror=$3
    
    log "Applying fixes for: $action_type (MEM=${mem_mb}MB)"
    
    # 1. Kill iPhone Mirroring if active (Sequoia leak trigger)
    if [ "$iphone_mirror" = "1" ]; then
        log "Terminating iPhone Mirroring (Sequoia leak trigger)"
        pkill "iPhone Mirroring" 2>/dev/null
        osascript -e 'display notification "iPhone Mirroring terminated to reduce WindowServer memory" with title "WindowServer Auto-Fix"' 2>/dev/null
    fi
    
    # 2. Clear pasteboard (can cause memory bloat)
    pbcopy < /dev/null 2>/dev/null
    log "Cleared pasteboard"
    
    # 3. Kill problematic browser processes in fullscreen
    if pgrep -f "Firefox.*fullscreen" > /dev/null; then
        log "Warning: Firefox in fullscreen detected (known leak trigger)"
    fi
    
    # 4. Restart Dock (safe and often helps)
    killall Dock 2>/dev/null
    log "Restarted Dock"
    
    # 5. Log top memory apps
    log "Top memory consuming apps:"
    ps aux | sort -rk 4 | head -5 | awk '{print $11 " - " $4 "%"}' >> "$LOG_FILE"
    
    # 6. Send notification with action details
    if [ "$action_type" = "SEQUOIA_LEAK" ]; then
        osascript -e 'display notification "Sequoia leak detected ('${mem_mb}'MB). Applied automatic fixes. Consider restarting if issue persists." with title "WindowServer Auto-Fix" sound name "Funk"' 2>/dev/null
    else
        osascript -e 'display notification "WindowServer high usage detected. Applied automatic fixes." with title "WindowServer Auto-Fix"' 2>/dev/null
    fi
    
    log "Automatic fixes applied successfully"
}

stop_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Daemon is not running"
        exit 1
    fi
    
    pid=$(cat "$PID_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        kill "$pid"
        echo "Daemon stopped (PID $pid)"
        rm -f "$PID_FILE"
    else
        echo "Daemon process not found"
        rm -f "$PID_FILE"
    fi
}

status_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Daemon is not running"
        exit 1
    fi
    
    pid=$(cat "$PID_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Daemon is running (PID $pid)"
        
        # Show recent log entries
        if [ -f "$LOG_FILE" ]; then
            echo -e "\nRecent log entries:"
            tail -10 "$LOG_FILE"
        fi
    else
        echo "Daemon process not found (stale PID file)"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Main execution
mkdir -p "$SCRIPT_DIR/logs"

case "${1:-start}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon 2>/dev/null || true
        sleep 1
        start_daemon
        ;;
    status)
        status_daemon
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
