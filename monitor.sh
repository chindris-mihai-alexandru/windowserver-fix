#!/bin/bash

# WindowServer Monitor Script
# Monitors WindowServer CPU and memory usage and logs detailed information

LOG_DIR="$HOME/windowserver-fix/logs"
LOG_FILE="$LOG_DIR/windowserver_monitor_$(date +%Y%m%d).log"
METRICS_FILE="$LOG_DIR/metrics.csv"

# Thresholds
CPU_THRESHOLD=50.0
MEM_THRESHOLD_MB=500

# Create log directory
mkdir -p "$LOG_DIR"

# Initialize CSV if it doesn't exist
if [ ! -f "$METRICS_FILE" ]; then
    echo "timestamp,cpu_percent,mem_mb,mem_compressed_mb,open_files,display_count,resolution" > "$METRICS_FILE"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_windowserver_stats() {
    ps aux | grep "WindowServer" | grep -v grep | awk '{print $3, $4, $6}'
}

get_display_info() {
    system_profiler SPDisplaysDataType | grep -E "(Resolution|Display Type)" | wc -l
}

check_windowserver() {
    log "=== WindowServer Status Check ==="
    
    # Get WindowServer stats
    stats=$(get_windowserver_stats)
    if [ -z "$stats" ]; then
        log "ERROR: WindowServer process not found"
        return 1
    fi
    
    cpu=$(echo "$stats" | awk '{print $1}')
    mem_percent=$(echo "$stats" | awk '{print $2}')
    mem_kb=$(echo "$stats" | awk '{print $3}')
    mem_mb=$((mem_kb / 1024))
    
    # Get additional info
    ws_pid=$(pgrep WindowServer)
    open_files=$(lsof -p "$ws_pid" 2>/dev/null | wc -l | tr -d ' ')
    display_count=$(system_profiler SPDisplaysDataType | grep -c "Resolution:")
    
    # Get current resolution
    resolution=$(system_profiler SPDisplaysDataType | grep "Resolution:" | head -1 | awk '{print $2, $3, $4}')
    
    log "CPU Usage: ${cpu}%"
    log "Memory Usage: ${mem_mb}MB (${mem_percent}%)"
    log "Open Files: $open_files"
    log "Connected Displays: $display_count"
    log "Primary Resolution: $resolution"
    
    # Check for memory leaks (compressed memory)
    vm_stat_output=$(vm_stat)
    compressed_mb=$(echo "$vm_stat_output" | grep "Pages occupied by compressor:" | awk '{print $5}' | tr -d '.')
    compressed_mb=$((compressed_mb * 4096 / 1024 / 1024))
    log "Compressed Memory: ${compressed_mb}MB"
    
    # Save metrics to CSV
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,$cpu,$mem_mb,$compressed_mb,$open_files,$display_count,\"$resolution\"" >> "$METRICS_FILE"
    
    # Check if thresholds exceeded
    if (( $(echo "$cpu > $CPU_THRESHOLD" | bc -l) )); then
        log "WARNING: CPU usage exceeds threshold (${cpu}% > ${CPU_THRESHOLD}%)"
        return 2
    fi
    
    if [ "$mem_mb" -gt "$MEM_THRESHOLD_MB" ]; then
        log "WARNING: Memory usage exceeds threshold (${mem_mb}MB > ${MEM_THRESHOLD_MB}MB)"
        return 3
    fi
    
    log "Status: Normal"
    return 0
}

capture_diagnostic_info() {
    log "=== Capturing Diagnostic Information ==="
    
    diagnostic_file="$LOG_DIR/diagnostic_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== System Info ==="
        sw_vers
        sysctl -n machdep.cpu.brand_string
        
        echo -e "\n=== Display Configuration ==="
        system_profiler SPDisplaysDataType
        
        echo -e "\n=== WindowServer Process Details ==="
        ps aux | grep WindowServer | grep -v grep
        
        echo -e "\n=== Open Files Count ==="
        lsof -p $(pgrep WindowServer) 2>/dev/null | wc -l
        
        echo -e "\n=== Memory Statistics ==="
        vm_stat
        
        echo -e "\n=== Power Management ==="
        pmset -g
        
        echo -e "\n=== Display Preferences ==="
        defaults read ~/Library/Preferences/ByHost/com.apple.windowserver.* 2>/dev/null || echo "No preferences found"
        
        echo -e "\n=== Transparency Settings ==="
        defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo "Not set"
        
        echo -e "\n=== Dock Settings ==="
        defaults read com.apple.dock mru-spaces 2>/dev/null || echo "Not set"
        
        echo -e "\n=== Top Processes ==="
        top -l 1 -n 20 -o cpu
        
        echo -e "\n=== Console Errors (Last 50) ==="
        log show --predicate 'process == "WindowServer"' --last 1h --style compact 2>/dev/null | tail -50
        
    } > "$diagnostic_file"
    
    log "Diagnostic info saved to: $diagnostic_file"
}

# Main execution
case "${1:-check}" in
    check)
        check_windowserver
        exit $?
        ;;
    monitor)
        log "Starting continuous monitoring (Ctrl+C to stop)"
        while true; do
            check_windowserver
            sleep 30
        done
        ;;
    diagnostic)
        capture_diagnostic_info
        ;;
    *)
        echo "Usage: $0 {check|monitor|diagnostic}"
        echo "  check      - Single check of WindowServer status"
        echo "  monitor    - Continuous monitoring (30s interval)"
        echo "  diagnostic - Capture full diagnostic information"
        exit 1
        ;;
esac
