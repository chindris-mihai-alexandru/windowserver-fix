#!/bin/bash

# WindowServer Dashboard - Real-time monitoring

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear_screen() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          WindowServer Monitoring Dashboard                 ║${NC}"
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

show_dashboard() {
    # Get WindowServer stats
    stats=$(ps aux | grep "WindowServer" | grep -v grep | awk '{print $3, $4, $6}')
    
    if [ -z "$stats" ]; then
        echo -e "${RED}ERROR: WindowServer process not found${NC}"
        return 1
    fi
    
    cpu=$(echo "$stats" | awk '{print $1}')
    mem_percent=$(echo "$stats" | awk '{print $2}')
    mem_kb=$(echo "$stats" | awk '{print $3}')
    mem_mb=$((mem_kb / 1024))
    
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
    fi
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo "Press Ctrl+C to stop | Refreshing every 5 seconds"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

# Main loop
trap "echo; echo 'Dashboard stopped'; exit 0" SIGINT SIGTERM

while true; do
    show_dashboard
    sleep 5
done
