#!/bin/bash

# WindowServer Monitor Script v2.0
# Monitors WindowServer CPU and memory usage with macOS Sequoia (15.x) leak detection
# Updated November 2025 for current WindowServer memory leak issues

LOG_DIR="$HOME/windowserver-fix/logs"
LOG_FILE="$LOG_DIR/windowserver_monitor_$(date +%Y%m%d).log"
METRICS_FILE="$LOG_DIR/metrics.csv"
HISTORY_FILE="$LOG_DIR/memory_history.txt"

# 2025 Sequoia-Specific Thresholds
CPU_THRESHOLD=50.0
MEM_THRESHOLD_NORMAL=500      # Normal: <500MB for basic usage
MEM_THRESHOLD_WARNING=2048    # Warning: >2GB with few apps (Sequoia leak indicator)
MEM_THRESHOLD_CRITICAL=5120   # Critical: >5GB (Sequoia confirmed leak)
MEM_THRESHOLD_EMERGENCY=20480 # Emergency: >20GB (system crash imminent)

# Create log directory
mkdir -p "$LOG_DIR"

# Initialize CSV if it doesn't exist
if [ ! -f "$METRICS_FILE" ]; then
    echo "timestamp,cpu_percent,mem_mb,mem_compressed_mb,open_files,display_count,resolution,iphone_mirror,app_count,severity" > "$METRICS_FILE"
fi

# Initialize memory history
touch "$HISTORY_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

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

detect_ultrawide_display() {
    system_profiler SPDisplaysDataType | grep "Resolution:" | awk '{
        width = $2
        if (width >= 5120) print "ULTRAWIDE_DETECTED"
    }' | head -1
}

detect_promotion() {
    system_profiler SPDisplaysDataType | grep -q "120 Hz" && echo "ENABLED" || echo "DISABLED"
}

count_app_windows() {
    # Count visible application windows (excluding WindowServer itself)
    windows=$(osascript -e 'tell application "System Events" to count (every window of every process whose background only is false)' 2>/dev/null)
    echo "${windows:-0}"
}

get_memory_growth_rate() {
    # Calculate memory growth rate from last 5 entries
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "0"
        return
    fi
    
    tail -5 "$HISTORY_FILE" | awk '{
        if (NR==1) first=$2
        if (NR==5) last=$2
    }
    END {
        if (first > 0 && last > 0) {
            growth = last - first
            print growth
        } else {
            print 0
        }
    }'
}

detect_sequoia_leak_pattern() {
    mem_mb=$1
    app_count=$2
    growth_rate=$(get_memory_growth_rate)
    
    # Pattern 1: >2GB with few apps (< 10 windows)
    if [ "$mem_mb" -gt 2048 ] && [ "$app_count" -lt 10 ]; then
        echo "LEAK_PATTERN_1: High memory with few apps"
        return 1
    fi
    
    # Pattern 2: Continuous growth (>500MB increase in last 5 checks)
    if [ "$growth_rate" -gt 500 ]; then
        echo "LEAK_PATTERN_2: Rapid memory growth detected (+${growth_rate}MB)"
        return 1
    fi
    
    # Pattern 3: Critical threshold exceeded
    if [ "$mem_mb" -gt "$MEM_THRESHOLD_CRITICAL" ]; then
        echo "LEAK_PATTERN_3: Critical Sequoia leak threshold exceeded"
        return 1
    fi
    
    echo "NO_LEAK"
    return 0
}

get_windowserver_stats() {
    # CRITICAL FIX: Use 'top' to get actual memory as shown in Activity Monitor
    # ps aux shows RSS (physical RAM only), but WindowServer uses massive virtual memory
    # for GPU buffers and window compositing that Activity Monitor includes
    ws_pid=$(pgrep WindowServer)
    if [ -z "$ws_pid" ]; then
        echo ""
        return 1
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
    
    echo "$cpu $mem_mb"
}

get_display_info() {
    system_profiler SPDisplaysDataType | grep -E "(Resolution|Display Type)" | wc -l
}

check_windowserver() {
    log "=== WindowServer Status Check (macOS $(sw_vers -productVersion)) ==="
    
    # Get WindowServer stats
    stats=$(get_windowserver_stats)
    if [ -z "$stats" ]; then
        log "ERROR: WindowServer process not found"
        return 1
    fi
    
    cpu=$(echo "$stats" | awk '{print $1}')
    mem_mb=$(echo "$stats" | awk '{print $2}')
    
    # Calculate memory percentage based on total RAM
    total_ram_mb=$(sysctl hw.memsize | awk '{print $2/1024/1024}' | cut -d. -f1)
    mem_percent=$(echo "scale=1; $mem_mb * 100 / $total_ram_mb" | bc)
    
    # Get additional info
    ws_pid=$(pgrep WindowServer)
    open_files=$(lsof -p "$ws_pid" 2>/dev/null | wc -l | tr -d ' ')
    display_count=$(system_profiler SPDisplaysDataType | grep -c "Resolution:")
    
    # Get current resolution
    resolution=$(system_profiler SPDisplaysDataType | grep "Resolution:" | head -1 | awk '{print $2, $3, $4}')
    
    # 2025 Enhanced Detection
    iphone_mirror=$(detect_iphone_mirroring)
    app_count=$(count_app_windows)
    ultrawide=$(detect_ultrawide_display)
    promotion=$(detect_promotion)
    
    log "CPU Usage: ${cpu}%"
    log "Memory Usage: ${mem_mb}MB (${mem_percent}%)"
    log "Open Files: $open_files"
    log "Connected Displays: $display_count"
    log "Primary Resolution: $resolution"
    log "App Windows Open: $app_count"
    
    # Sequoia-specific warnings
    if is_sequoia; then
        log "macOS Sequoia Detected - Enhanced leak monitoring active"
        log "iPhone Mirroring: $iphone_mirror"
        [ -n "$ultrawide" ] && log "WARNING: $ultrawide - Known leak trigger"
        log "ProMotion: $promotion"
    fi
    
    # Check for memory leaks (compressed memory)
    vm_stat_output=$(vm_stat)
    compressed_mb=$(echo "$vm_stat_output" | grep "Pages occupied by compressor:" | awk '{print $5}' | tr -d '.')
    compressed_mb=$((compressed_mb * 4096 / 1024 / 1024))
    log "Compressed Memory: ${compressed_mb}MB"
    
    # Store memory history for growth tracking
    echo "$(date +%s) $mem_mb" >> "$HISTORY_FILE"
    
    # Keep only last 100 entries
    tail -100 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    
    # Determine severity level
    severity="NORMAL"
    if [ "$mem_mb" -gt "$MEM_THRESHOLD_EMERGENCY" ]; then
        severity="EMERGENCY"
    elif [ "$mem_mb" -gt "$MEM_THRESHOLD_CRITICAL" ]; then
        severity="CRITICAL"
    elif [ "$mem_mb" -gt "$MEM_THRESHOLD_WARNING" ]; then
        severity="WARNING"
    fi
    
    # Save metrics to CSV
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,$cpu,$mem_mb,$compressed_mb,$open_files,$display_count,\"$resolution\",$iphone_mirror,$app_count,$severity" >> "$METRICS_FILE"
    
    # Check for Sequoia leak pattern
    if is_sequoia; then
        leak_result=$(detect_sequoia_leak_pattern "$mem_mb" "$app_count")
        if [ "$leak_result" != "NO_LEAK" ]; then
            log "⚠️  SEQUOIA MEMORY LEAK DETECTED: $leak_result"
            log "💡 Recommendation: Run ./fix.sh restart-windowserver or close iPhone Mirroring"
        fi
    fi
    
    # Check if thresholds exceeded
    if (( $(echo "$cpu > $CPU_THRESHOLD" | bc -l) )); then
        log "WARNING: CPU usage exceeds threshold (${cpu}% > ${CPU_THRESHOLD}%)"
    fi
    
    case "$severity" in
        EMERGENCY)
            log "🚨 EMERGENCY: Memory at ${mem_mb}MB - System crash imminent!"
            log "ACTION REQUIRED: Restart WindowServer immediately"
            return 4
            ;;
        CRITICAL)
            log "❌ CRITICAL: Memory at ${mem_mb}MB - Sequoia leak confirmed"
            log "ACTION: Run ./fix.sh restart-windowserver"
            return 3
            ;;
        WARNING)
            log "⚠️  WARNING: Memory at ${mem_mb}MB - Monitoring for leak pattern"
            return 2
            ;;
        *)
            log "✅ Status: Normal"
            return 0
            ;;
    esac
}

capture_diagnostic_info() {
    log "=== Capturing Diagnostic Information (2025 Enhanced) ==="
    
    diagnostic_file="$LOG_DIR/diagnostic_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== System Info ==="
        sw_vers
        sysctl -n machdep.cpu.brand_string
        
        echo -e "\n=== macOS Sequoia Leak Detection ==="
        if is_sequoia; then
            echo "macOS Sequoia Detected: YES"
            echo "iPhone Mirroring Status: $(detect_iphone_mirroring)"
            echo "ProMotion Status: $(detect_promotion)"
            echo "Ultra-wide Display: $(detect_ultrawide_display)"
            echo "App Windows Count: $(count_app_windows)"
            echo "Memory Growth Rate: $(get_memory_growth_rate)MB"
        else
            echo "macOS Sequoia: NO (Version $(get_macos_version))"
        fi
        
        echo -e "\n=== Display Configuration ==="
        system_profiler SPDisplaysDataType
        
        echo -e "\n=== WindowServer Process Details ==="
        ps aux | grep WindowServer | grep -v grep
        
        echo -e "\n=== Open Files Count ==="
        lsof -p $(pgrep WindowServer) 2>/dev/null | wc -l
        
        echo -e "\n=== Memory Statistics ==="
        vm_stat
        
        echo -e "\n=== Top Memory Consuming Apps ==="
        ps aux | sort -rk 4 | head -20
        
        echo -e "\n=== Problematic Processes (Known Leak Triggers) ==="
        echo "Firefox: $(pgrep -q Firefox && echo 'RUNNING' || echo 'NOT RUNNING')"
        echo "Chrome: $(pgrep -q "Google Chrome" && echo 'RUNNING' || echo 'NOT RUNNING')"
        echo "Safari: $(pgrep -q Safari && echo 'RUNNING' || echo 'NOT RUNNING')"
        echo "iPhone Mirroring: $(detect_iphone_mirroring)"
        echo "OBS: $(pgrep -q obs && echo 'RUNNING' || echo 'NOT RUNNING')"
        echo "Screen Recording: $(pgrep -q screencapture && echo 'ACTIVE' || echo 'INACTIVE')"
        
        echo -e "\n=== Memory History (Last 10 samples) ==="
        tail -10 "$HISTORY_FILE"
        
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
