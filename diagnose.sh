#!/bin/bash
# diagnose.sh - Root cause analysis for WindowServer leaks
# Part of windowserver-fix v2.1 - Intelligent leak diagnosis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/windowserver-fix/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DIAG_LOG="$LOG_DIR/diagnosis_$TIMESTAMP.log"

# Known leak-causing applications database
KNOWN_LEAK_APPS=(
    "OBS:Screen recording - constantly buffers video frames"
    "Zoom.us:Video conferencing - screen sharing memory accumulation"
    "Microsoft Teams:Video conferencing - known WindowServer issues"
    "Slack:Screen sharing and video calls"
    "Google Chrome:Browser - memory leaks with many tabs (>50)"
    "Firefox:Browser - fullscreen video memory not released"
    "BetterDisplay:Display utility - custom resolution drivers"
    "SwitchResX:Display utility - resolution management leaks"
    "DisplayLink Manager:External display driver issues"
    "Lunar:Display utility - brightness control"
    "Figma:Design software - GPU memory accumulation"
    "Adobe Photoshop:Design software - layer rendering leaks"
    "Sketch:Design software - canvas memory buildup"
    "Final Cut Pro:Video editing - preview buffer leaks"
    "ScreenFlow:Screen recording - video buffer accumulation"
    "QuickTime Player:Recording mode - frame buffer issues"
    "Discord:Screen sharing and video"
    "Webex:Video conferencing"
    "OBS Studio:Screen recording"
    "Loom:Screen recording"
)

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_both() {
    echo "$1" | tee -a "$DIAG_LOG"
}

log_section() {
    echo "" | tee -a "$DIAG_LOG"
    echo -e "${BLUE}$1${NC}" | tee -a "$DIAG_LOG"
    echo "$(printf '=%.0s' {1..80})" | tee -a "$DIAG_LOG"
}

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Start diagnosis
log_section "🔍 WindowServer Leak Root Cause Analysis"
log_both "Timestamp: $(date)"
log_both "macOS Version: $(sw_vers -productVersion)"
log_both "Log file: $DIAG_LOG"
log_both ""

# Get WindowServer current memory
ws_pid=$(pgrep WindowServer || echo "")
if [ -z "$ws_pid" ]; then
    log_both "${RED}❌ WindowServer process not found!${NC}"
    exit 1
fi

mem_str=$(top -l 1 -stats pid,command,mem -pid "$ws_pid" 2>/dev/null | grep WindowServer | awk '{print $3}')
if [[ $mem_str == *G ]]; then
    mem_mb=$(echo "${mem_str%G} * 1024" | bc | cut -d. -f1)
elif [[ $mem_str == *M ]]; then
    mem_mb=$(echo "${mem_str%M}" | cut -d. -f1)
elif [[ $mem_str == *K ]]; then
    mem_mb=$(echo "${mem_str%K} / 1024" | bc | cut -d. -f1)
fi

log_both "Current WindowServer Memory: ${mem_mb}MB"
log_both ""

# Section 1: Known Leak-Causing Apps
log_section "🎯 Known Leak-Causing Apps Detection"
culprits_found=0
culprits_list=""

for app_entry in "${KNOWN_LEAK_APPS[@]}"; do
    app_name="${app_entry%%:*}"
    app_desc="${app_entry#*:}"
    
    # Check if app is running
    if pgrep -x "$app_name" > /dev/null 2>&1 || pgrep -i "$app_name" > /dev/null 2>&1; then
        ((culprits_found++))
        log_both "${RED}⚠️  FOUND: $app_name${NC}"
        log_both "   Reason: $app_desc"
        culprits_list="$culprits_list\n- $app_name ($app_desc)"
        
        # Get memory usage of this app
        app_mem=$(ps aux | grep -i "$app_name" | grep -v grep | head -1 | awk '{print $4"%"}')
        if [ ! -z "$app_mem" ]; then
            log_both "   Memory: $app_mem of system RAM"
        fi
    fi
done

if [ $culprits_found -eq 0 ]; then
    log_both "${GREEN}✅ No known leak-causing apps detected${NC}"
else
    log_both ""
    log_both "${YELLOW}Found $culprits_found known problematic app(s)${NC}"
fi

# Section 2: All Active Applications
log_section "📊 All Active Applications"
log_both "Apps with visible windows:"
active_apps=$(osascript -e 'tell application "System Events" to get name of (processes where background only is false)' 2>/dev/null | tr ',' '\n' | sed 's/^[ \t]*//' || echo "Unable to detect")
log_both "$active_apps"
app_count=$(echo "$active_apps" | wc -l | xargs)
log_both ""
log_both "Total visible apps: $app_count"

# Section 3: Screen Capture/Recording Detection
log_section "🎥 Screen Capture & Recording Detection"
recording_found=0
screen_capture_keywords="obs|screen|record|capture|loom|camtasia|screenflow"
screen_procs=$(ps aux | grep -iE "$screen_capture_keywords" | grep -v grep | grep -v diagnose.sh || echo "")

if [ ! -z "$screen_procs" ]; then
    log_both "${YELLOW}⚠️  Active screen capture/recording processes:${NC}"
    echo "$screen_procs" | awk '{print "   " $11 " (PID: " $2 ")"}' | tee -a "$DIAG_LOG"
    recording_found=1
else
    log_both "${GREEN}✅ No screen recording apps detected${NC}"
fi

# Section 4: Video Conferencing Apps
log_section "📹 Video Conferencing Apps"
video_keywords="zoom|teams|webex|slack|discord|meet"
video_procs=$(ps aux | grep -iE "$video_keywords" | grep -v grep | grep -v diagnose.sh || echo "")

if [ ! -z "$video_procs" ]; then
    log_both "${YELLOW}⚠️  Active video conferencing apps:${NC}"
    echo "$video_procs" | awk '{print "   " $11 " (PID: " $2 ", Memory: " $4 "%)"}' | tee -a "$DIAG_LOG"
else
    log_both "${GREEN}✅ No video conferencing apps detected${NC}"
fi

# Section 5: Browser Analysis
log_section "🌐 Browser Activity Analysis"

# Safari
safari_windows=$(osascript -e 'tell application "Safari" to count windows' 2>/dev/null || echo "0")
safari_tabs=$(osascript -e 'tell application "Safari" to count (every tab of every window)' 2>/dev/null || echo "0")
log_both "Safari: $safari_windows windows, $safari_tabs tabs"
if [ "$safari_tabs" -gt 50 ]; then
    log_both "${YELLOW}   ⚠️  High tab count (>50) - potential leak source${NC}"
fi

# Chrome
chrome_windows=$(osascript -e 'tell application "Google Chrome" to count windows' 2>/dev/null || echo "0")
if [ "$chrome_windows" != "0" ]; then
    chrome_tabs=$(osascript -e 'tell application "Google Chrome" to count (every tab of every window)' 2>/dev/null || echo "0")
    log_both "Chrome: $chrome_windows windows, $chrome_tabs tabs"
    if [ "$chrome_tabs" -gt 50 ]; then
        log_both "${YELLOW}   ⚠️  High tab count (>50) - potential leak source${NC}"
    fi
else
    log_both "Chrome: Not running"
fi

# Firefox
firefox_running=$(pgrep -x "Firefox" > /dev/null && echo "yes" || echo "no")
log_both "Firefox: $firefox_running"
if [ "$firefox_running" = "yes" ]; then
    log_both "${YELLOW}   ⚠️  Firefox has known fullscreen video memory issues${NC}"
fi

# Section 6: Login Items (Startup Apps)
log_section "🚀 Login Items Analysis"
login_items=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tr ',' '\n' | sed 's/^[ \t]*//' || echo "Unable to detect")
login_count=$(echo "$login_items" | wc -l | xargs)
log_both "Login items count: $login_count"
log_both "$login_items"

if [ "$login_count" -gt 15 ]; then
    log_both ""
    log_both "${YELLOW}⚠️  High login item count (>15) - may contribute to leaks${NC}"
    log_both "   Consider removing unused startup apps"
fi

# Section 7: Display Configuration
log_section "🖥️  Display Configuration"
display_count=$(system_profiler SPDisplaysDataType | grep -c "Resolution:" || echo "1")
log_both "Connected displays: $display_count"
log_both ""
log_both "Display details:"
system_profiler SPDisplaysDataType | grep -E "Resolution:|Retina:|Framebuffer" | tee -a "$DIAG_LOG"

# Check for ultra-wide or high-res displays
ultrawide=$(system_profiler SPDisplaysDataType | grep -i "5K\|6K\|ultrawide" || echo "")
if [ ! -z "$ultrawide" ]; then
    log_both ""
    log_both "${YELLOW}⚠️  Ultra-wide or 5K+ display detected${NC}"
    log_both "   High-resolution displays increase WindowServer baseline memory"
    log_both "   Expected: 1-3GB per 5K display"
fi

# Section 8: Display Utilities
log_section "🔧 Display Management Utilities"
display_util_keywords="better|display|switch|lunar|resolution|monitor"
display_utils=$(ps aux | grep -iE "$display_util_keywords" | grep -v grep | grep -v diagnose.sh | grep -v "WindowServer" || echo "")

if [ ! -z "$display_utils" ]; then
    log_both "${YELLOW}⚠️  Display management utilities detected:${NC}"
    echo "$display_utils" | awk '{print "   " $11}' | tee -a "$DIAG_LOG"
    log_both "   These can cause memory leaks with custom resolutions"
else
    log_both "${GREEN}✅ No display management utilities detected${NC}"
fi

# Section 9: Top Memory Consumers
log_section "🔥 Top 10 Memory Consumers"
log_both "Rank  Memory  Process"
log_both "----  ------  -------"
ps aux | sort -nrk 4 | head -10 | awk '{printf "%-4s  %5s%%  %s\n", NR, $4, $11}' | tee -a "$DIAG_LOG"

# Section 10: WindowServer Connection Analysis
log_section "🪟 WindowServer Connection Analysis"
ws_connections=$(lsof -c WindowServer 2>/dev/null | wc -l | xargs || echo "Unable to detect")
log_both "Total WindowServer connections: $ws_connections"

if [ "$ws_connections" -gt 10000 ]; then
    log_both "${YELLOW}⚠️  Very high connection count (>10,000)${NC}"
    log_both "   May indicate connection leak from an app"
fi

# Section 11: Cache Analysis
log_section "💾 User Cache Analysis"
cache_size=$(du -sm ~/Library/Caches 2>/dev/null | awk '{print $1}')
log_both "User cache size: ${cache_size}MB"

if [ "$cache_size" -gt 5000 ]; then
    log_both "${YELLOW}⚠️  Large cache size (>5GB)${NC}"
    log_both "   Consider clearing: ~/Library/Caches"
elif [ "$cache_size" -gt 10000 ]; then
    log_both "${RED}⚠️  Very large cache size (>10GB)${NC}"
    log_both "   Recommended action: Clear caches immediately"
else
    log_both "${GREEN}✅ Cache size normal${NC}"
fi

# Section 12: System Load
log_section "⚡ System Load Analysis"
uptime_info=$(uptime)
log_both "$uptime_info"

# Section 13: iPhone Mirroring (Sequoia-specific)
log_section "📱 iPhone Mirroring Status"
if pgrep -x "iPhone Mirroring" > /dev/null; then
    log_both "${RED}⚠️  iPhone Mirroring is ACTIVE${NC}"
    log_both "   This is a known major leak source on Sequoia"
    log_both "   Recommendation: Terminate iPhone Mirroring"
else
    log_both "${GREEN}✅ iPhone Mirroring not active${NC}"
fi

# Section 14: Root Cause Summary
log_section "🎯 Root Cause Analysis Summary"

severity_score=0
root_causes=""

# Calculate severity and identify root causes
if [ $culprits_found -gt 0 ]; then
    severity_score=$((severity_score + culprits_found * 20))
    root_causes="${root_causes}\n${RED}HIGH PRIORITY:${NC} $culprits_found known leak-causing app(s) detected"
fi

if [ "$safari_tabs" -gt 50 ] || [ "$chrome_tabs" -gt 50 ]; then
    severity_score=$((severity_score + 15))
    root_causes="${root_causes}\n${YELLOW}MEDIUM:${NC} Browser with excessive tabs (>50)"
fi

if [ "$login_count" -gt 15 ]; then
    severity_score=$((severity_score + 10))
    root_causes="${root_causes}\n${YELLOW}MEDIUM:${NC} Too many login items ($login_count)"
fi

if [ "$cache_size" -gt 10000 ]; then
    severity_score=$((severity_score + 15))
    root_causes="${root_causes}\n${YELLOW}MEDIUM:${NC} Excessive cache size (${cache_size}MB)"
fi

if [ ! -z "$ultrawide" ] && [ "$mem_mb" -gt 8000 ]; then
    severity_score=$((severity_score + 5))
    root_causes="${root_causes}\n${GREEN}INFO:${NC} High-resolution displays increase baseline memory (expected)"
fi

if [ $recording_found -eq 1 ]; then
    severity_score=$((severity_score + 20))
    root_causes="${root_causes}\n${RED}HIGH PRIORITY:${NC} Screen recording/capture software active"
fi

if pgrep -x "iPhone Mirroring" > /dev/null; then
    severity_score=$((severity_score + 30))
    root_causes="${root_causes}\n${RED}CRITICAL:${NC} iPhone Mirroring active (known Sequoia leak)"
fi

log_both ""
log_both "Severity Score: $severity_score/100"
log_both ""

if [ $severity_score -gt 50 ]; then
    log_both "${RED}🚨 CRITICAL: Multiple leak sources identified${NC}"
elif [ $severity_score -gt 25 ]; then
    log_both "${YELLOW}⚠️  WARNING: Likely leak sources found${NC}"
elif [ $severity_score -gt 0 ]; then
    log_both "${YELLOW}ℹ️  INFO: Minor contributing factors detected${NC}"
else
    log_both "${GREEN}✅ No obvious leak sources detected${NC}"
    log_both "   Your high memory usage may be normal for your configuration"
fi

if [ ! -z "$root_causes" ]; then
    log_both ""
    log_both "Identified Root Causes:"
    echo -e "$root_causes" | tee -a "$DIAG_LOG"
fi

# Section 15: Actionable Recommendations
log_section "💡 Recommended Actions (Priority Order)"

echo "" | tee -a "$DIAG_LOG"

# Generate specific recommendations
if pgrep -x "iPhone Mirroring" > /dev/null; then
    log_both "1. ${RED}[CRITICAL]${NC} Terminate iPhone Mirroring immediately"
    log_both "   Command: pkill 'iPhone Mirroring'"
fi

if [ $culprits_found -gt 0 ]; then
    log_both "2. ${RED}[HIGH]${NC} Close or restart these apps:$culprits_list"
fi

if [ $recording_found -eq 1 ]; then
    log_both "3. ${RED}[HIGH]${NC} Stop screen recording/capture when not needed"
fi

if [ "$safari_tabs" -gt 50 ]; then
    log_both "4. ${YELLOW}[MEDIUM]${NC} Reduce Safari tabs to <50 (currently: $safari_tabs)"
fi

if [ "$chrome_tabs" -gt 50 ]; then
    log_both "5. ${YELLOW}[MEDIUM]${NC} Reduce Chrome tabs to <50 (currently: $chrome_tabs)"
fi

if [ "$cache_size" -gt 10000 ]; then
    log_both "6. ${YELLOW}[MEDIUM]${NC} Clear user caches (${cache_size}MB)"
    log_both "   Safe command: rm -rf ~/Library/Caches/*"
fi

if [ "$login_count" -gt 15 ]; then
    log_both "7. ${YELLOW}[MEDIUM]${NC} Remove unused login items"
    log_both "   Location: System Settings > General > Login Items"
fi

if [ "$mem_mb" -gt 20000 ]; then
    log_both "8. ${RED}[EMERGENCY]${NC} WindowServer >20GB - Restart WindowServer immediately"
    log_both "   Command: ./fix.sh restart-windowserver"
elif [ "$mem_mb" -gt 5000 ] && [ $severity_score -gt 25 ]; then
    log_both "9. ${YELLOW}[MEDIUM]${NC} Apply toolkit fixes"
    log_both "   Command: ./fix.sh"
fi

log_both ""
log_both "${BLUE}Next Steps:${NC}"
log_both "1. Review the recommendations above"
log_both "2. Address HIGH priority items first"
log_both "3. Run './monitor.sh check' after changes to verify improvement"
log_both "4. Run './diagnose.sh' again in 1 hour to track progress"
log_both ""
log_both "Full diagnosis saved to: $DIAG_LOG"
log_both ""
log_both "${GREEN}Diagnosis complete!${NC}"