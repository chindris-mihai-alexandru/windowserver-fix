#!/bin/bash

# WindowServer Auto-Fix Daemon
# Monitors WindowServer and applies fixes when thresholds are exceeded

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/daemon_$(date +%Y%m%d).log"
PID_FILE="$SCRIPT_DIR/.daemon.pid"

# Configuration
CPU_THRESHOLD=60.0
MEM_THRESHOLD_MB=600
CHECK_INTERVAL=60
ACTION_COOLDOWN=300  # Don't apply fixes more than once every 5 minutes

last_action_time=0

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
    stats=$(ps aux | grep "WindowServer" | grep -v grep | awk '{print $3, $4, $6}')
    
    if [ -z "$stats" ]; then
        log "ERROR: WindowServer process not found"
        return
    fi
    
    cpu=$(echo "$stats" | awk '{print $1}')
    mem_kb=$(echo "$stats" | awk '{print $3}')
    mem_mb=$((mem_kb / 1024))
    
    current_time=$(date +%s)
    time_since_action=$((current_time - last_action_time))
    
    # Check if thresholds exceeded
    needs_action=0
    
    if (( $(echo "$cpu > $CPU_THRESHOLD" | bc -l) )); then
        log "WARNING: CPU usage high (${cpu}% > ${CPU_THRESHOLD}%)"
        needs_action=1
    fi
    
    if [ "$mem_mb" -gt "$MEM_THRESHOLD_MB" ]; then
        log "WARNING: Memory usage high (${mem_mb}MB > ${MEM_THRESHOLD_MB}MB)"
        needs_action=1
    fi
    
    # Apply mitigation if needed and cooldown expired
    if [ "$needs_action" -eq 1 ] && [ "$time_since_action" -gt "$ACTION_COOLDOWN" ]; then
        log "Applying automatic fixes..."
        apply_automatic_fixes
        last_action_time=$(date +%s)
    elif [ "$needs_action" -eq 1 ]; then
        log "Fixes needed but in cooldown period (${time_since_action}s / ${ACTION_COOLDOWN}s)"
    fi
}

apply_automatic_fixes() {
    # Safe fixes that don't require restart
    
    # 1. Clear pasteboard (can cause memory bloat)
    pbcopy < /dev/null 2>/dev/null
    log "Cleared pasteboard"
    
    # 2. Purge inactive memory
    # Note: This requires sudo, so we'll skip it in automatic mode
    # sudo purge
    
    # 3. Kill problematic processes that might stress WindowServer
    # (Only if they're consuming unusual resources)
    
    # 4. Restart Dock (safe and often helps)
    killall Dock 2>/dev/null
    log "Restarted Dock"
    
    # 5. Send notification
    osascript -e 'display notification "WindowServer high usage detected. Applied automatic fixes." with title "WindowServer Monitor"' 2>/dev/null
    
    log "Automatic fixes applied"
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
