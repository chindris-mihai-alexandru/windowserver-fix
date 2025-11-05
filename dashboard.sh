#!/bin/bash

# WindowServer Dashboard - Real-time monitoring v2.1.0
# GPU Memory Tracking + Advanced Leak Detection

set -e

# Version information
readonly VERSION="2.1.0"
readonly RELEASE_DATE="November 2025"

# Load user configuration if exists
CONFIG_FILE="$(dirname "$0")/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Check required dependencies
if ! command -v bc >/dev/null 2>&1; then
    echo "Error: bc is required but not installed. Install with: brew install bc" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear_screen() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      WindowServer Monitoring Dashboard v2.1.0              ║${NC}"
    echo -e "${CYAN}║         GPU Memory + Advanced Leak Detection               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
}

get_status_color() {
    value=$1
    threshold=$2
    
    if (( $(echo "$value > $threshold" | bc -l) )); then
        echo "$RED"
    elif (( $(echo "$value > $threshold * 0.8" | bc -l) )); then
        echo "$YELLOW"
    else
        echo "$GREEN"
    fi
}

draw_bar() {
    value=$1
    max=$2
    width=40
    
    filled=$(echo "scale=0; $value * $width / $max" | bc)
    empty=$((width - filled))
    
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]"
}

get_gpu_memory() {
    if [ "${GPU_MONITORING_ENABLED:-true}" != "true" ]; then
        echo "0"
        return
    fi
    
    gpu_vram=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "VRAM" | head -1 | awk '{print $3}' | tr -d 'MB')
    echo "${gpu_vram:-0}"
}

get_page_table_memory() {
    if [ "${PAGE_TABLE_MONITORING_ENABLED:-true}" != "true" ]; then
        echo "0"
        return
    fi
    
    ws_pid=$(pgrep WindowServer)
    if [ -z "$ws_pid" ]; then
        echo "0"
        return
    fi
    
    vm_size=$(ps aux | grep WindowServer | grep -v grep | awk '{print $5}' | head -1)
    rss_size=$(ps aux | grep WindowServer | grep -v grep | awk '{print $6}' | head -1)
    
    if [ -n "$vm_size" ] && [ -n "$rss_size" ]; then
        page_table_mb=$(echo "scale=0; ($vm_size - $rss_size) / 1024" | bc 2>/dev/null || echo "0")
        if [ "$page_table_mb" -gt 2048 ]; then
            page_table_mb=2048
        fi
        echo "$page_table_mb"
    else
        echo "0"
    fi
}

get_compositor_memory() {
    if [ "${COMPOSITOR_MONITORING_ENABLED:-true}" != "true" ]; then
        echo "0"
        return
    fi
    
    display_count=$(system_profiler SPDisplaysDataType | grep -c "Resolution:")
    app_count=$(osascript -e 'tell application "System Events" to count (every window of every process whose background only is false)' 2>/dev/null || echo "0")
    
    width=$(system_profiler SPDisplaysDataType | grep "Resolution:" | head -1 | awk '{print $2}')
    height=$(system_profiler SPDisplaysDataType | grep "Resolution:" | head -1 | awk '{print $4}')
    
    if [ -n "$width" ] && [ -n "$height" ] && [ "$width" -gt 0 ] && [ "$height" -gt 0 ]; then
        bytes_per_window=$(echo "$width * $height * 4 * 2" | bc)
        total_bytes=$(echo "$bytes_per_window * $app_count" | bc)
        compositor_mb=$(echo "scale=0; $total_bytes / 1024 / 1024" | bc)
        echo "$compositor_mb"
    else
        echo "0"
    fi
}

show_dashboard() {
    # Get WindowServer stats
    ws_pid=$(pgrep WindowServer)
    
    if [ -z "$ws_pid" ]; then
        echo -e "${RED}ERROR: WindowServer process not found${NC}" >&2
        return 1
    fi
    
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
    
    # Get display info
    display_count=$(system_profiler SPDisplaysDataType | grep -c "Resolution:")
    
    # Get system info
    cpu_cores=$(sysctl -n hw.ncpu)
    total_mem_gb=$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024}')
    
    # Get uptime
    uptime_sec=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//')
    current_sec=$(date +%s)
    uptime_hours=$(( (current_sec - uptime_sec) / 3600 ))
    
    # Display dashboard
    clear_screen
    
    echo -e "${BLUE}System Information:${NC}"
    echo "  macOS Version: $(sw_vers -productVersion)"
    echo "  Chip: $(sysctl -n machdep.cpu.brand_string)"
    echo "  Uptime: ${uptime_hours}h"
    echo "  Displays: $display_count"
    echo
    
    # CPU Usage
    cpu_color=$(get_status_color "$cpu" 60)
    echo -e "${BLUE}CPU Usage:${NC} ${cpu_color}${cpu}%${NC}"
    echo -n "  "
    draw_bar "$cpu" 100
    echo " (Threshold: 60%)"
    echo
    
    # Memory Usage
    mem_color=$(get_status_color "$mem_mb" 500)
    echo -e "${BLUE}Memory Usage:${NC} ${mem_color}${mem_mb}MB${NC} (${mem_percent}%)"
    echo -n "  "
    draw_bar "$mem_mb" 1000
    echo " (Threshold: 500MB)"
    echo
    
    # v2.1.0: GPU and Advanced Memory Metrics
    if [ "${GPU_MONITORING_ENABLED:-true}" = "true" ]; then
        gpu_vram=$(get_gpu_memory)
        gpu_color=$(get_status_color "$gpu_vram" "${GPU_LEAK_THRESHOLD:-1024}")
        echo -e "${MAGENTA}GPU VRAM:${NC} ${gpu_color}${gpu_vram}MB${NC}"
        echo -n "  "
        draw_bar "$gpu_vram" 2048
        echo " (Threshold: ${GPU_LEAK_THRESHOLD:-1024}MB)"
        echo
    fi
    
    if [ "${PAGE_TABLE_MONITORING_ENABLED:-true}" = "true" ]; then
        page_table_mb=$(get_page_table_memory)
        pt_color=$(get_status_color "$page_table_mb" 1024)
        echo -e "${MAGENTA}Page Tables (VM):${NC} ${pt_color}${page_table_mb}MB${NC}"
        echo -n "  "
        draw_bar "$page_table_mb" 2048
        echo " (Threshold: 1024MB)"
        echo
    fi
    
    if [ "${COMPOSITOR_MONITORING_ENABLED:-true}" = "true" ]; then
        compositor_mb=$(get_compositor_memory)
        comp_color=$(get_status_color "$compositor_mb" 500)
        echo -e "${MAGENTA}Compositor Buffers:${NC} ${comp_color}${compositor_mb}MB${NC}"
        echo -n "  "
        draw_bar "$compositor_mb" 1000
        echo " (Estimated window buffers)"
        echo
    fi
    
    # System Memory
    vm_stats=$(vm_stat)
    pages_free=$(echo "$vm_stats" | grep "Pages free:" | awk '{print $3}' | tr -d '.')
    pages_active=$(echo "$vm_stats" | grep "Pages active:" | awk '{print $3}' | tr -d '.')
    pages_inactive=$(echo "$vm_stats" | grep "Pages inactive:" | awk '{print $3}' | tr -d '.')
    pages_wired=$(echo "$vm_stats" | grep "Pages wired down:" | awk '{print $4}' | tr -d '.')
    pages_compressed=$(echo "$vm_stats" | grep "Pages occupied by compressor:" | awk '{print $5}' | tr -d '.')
    
    free_mb=$((pages_free * 4096 / 1024 / 1024))
    active_mb=$((pages_active * 4096 / 1024 / 1024))
    wired_mb=$((pages_wired * 4096 / 1024 / 1024))
    compressed_mb=$((pages_compressed * 4096 / 1024 / 1024))
    
    echo -e "${BLUE}System Memory:${NC}"
    echo "  Free: ${free_mb}MB | Active: ${active_mb}MB | Wired: ${wired_mb}MB"
    echo "  Compressed: ${compressed_mb}MB"
    echo
    
    # Display Configuration
    echo -e "${BLUE}Display Configuration:${NC}"
    system_profiler SPDisplaysDataType | grep -E "(Display Type|Resolution):" | while read line; do
        echo "  $line"
    done
    echo
    
    # Settings Status
    echo -e "${BLUE}Optimization Settings:${NC}"
    
    transparency=$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo "0")
    if [ "$transparency" = "1" ]; then
        echo -e "  Reduce Transparency: ${GREEN}✓ Enabled${NC}"
    else
        echo -e "  Reduce Transparency: ${YELLOW}✗ Disabled${NC}"
    fi
    
    mru_spaces=$(defaults read com.apple.dock mru-spaces 2>/dev/null || echo "1")
    if [ "$mru_spaces" = "0" ]; then
        echo -e "  Space Rearrangement: ${GREEN}✓ Disabled${NC}"
    else
        echo -e "  Space Rearrangement: ${YELLOW}✗ Enabled${NC}"
    fi
    
    echo
    
    # Recent issues
    if [ -f "$SCRIPT_DIR/logs/metrics.csv" ]; then
        high_cpu_count=$(tail -100 "$SCRIPT_DIR/logs/metrics.csv" | awk -F, '$2 > 60 {count++} END {print count}')
        echo -e "${BLUE}Recent Activity (last 100 checks):${NC}"
        echo "  High CPU events: $high_cpu_count"
        
        # v2.1.0: Show detected leak patterns
        leak_patterns=$(tail -100 "$SCRIPT_DIR/logs/metrics.csv" | grep -v "NO_LEAK" | grep "LEAK_PATTERN" | wc -l | tr -d ' ')
        if [ "$leak_patterns" -gt 0 ]; then
            echo -e "  ${RED}Leak patterns detected: $leak_patterns${NC}"
            
            # Show most recent leak pattern
            recent_leak=$(tail -100 "$SCRIPT_DIR/logs/metrics.csv" | grep "LEAK_PATTERN" | tail -1 | awk -F, '{print $16}')
            if [ -n "$recent_leak" ]; then
                echo -e "  ${YELLOW}Latest: $recent_leak${NC}"
            fi
        else
            echo -e "  ${GREEN}No leak patterns detected${NC}"
        fi
    fi
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo "Press Ctrl+C to stop | Refreshing every 5 seconds"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

show_version() {
    echo "WindowServer Dashboard v${VERSION}"
    echo "Release Date: ${RELEASE_DATE}"
    echo "Real-time GPU Memory Tracking + Advanced Leak Detection"
}

# Parse arguments
if [ $# -gt 0 ]; then
    case "$1" in
        version|--version|-v)
            show_version
            exit 0
            ;;
        help|--help|-h)
            echo "Usage: $0 [option]"
            echo "  (no args)  - Start dashboard (default)"
            echo "  version    - Show version information"
            echo "  help       - Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [version|help]"
            exit 1
            ;;
    esac
fi

# Main loop
trap "echo; echo 'Dashboard stopped'; exit 0" SIGINT SIGTERM

while true; do
    show_dashboard
    sleep 5
done
