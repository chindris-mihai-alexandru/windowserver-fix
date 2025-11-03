#!/bin/bash
# diagnose_deep.sh - Deep WindowServer analysis using Asahi-inspired tracing
# Part of windowserver-fix v2.2 - Low-level diagnostic tracing
# Inspired by Asahi Linux reverse engineering methodology

set -e

# Check required dependencies
if ! command -v bc >/dev/null 2>&1; then
    echo "Error: bc is required but not installed. Install with: brew install bc" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/windowserver-fix/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEEP_LOG="$LOG_DIR/deep_diagnosis_$TIMESTAMP.log"

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_both() {
    echo "$1" | tee -a "$DEEP_LOG"
}

log_section() {
    echo "" | tee -a "$DEEP_LOG"
    echo -e "${BLUE}$1${NC}" | tee -a "$DEEP_LOG"
    echo "$(printf '=%.0s' {1..80})" | tee -a "$DEEP_LOG"
}

warn_sudo() {
    echo -e "${YELLOW}⚠️  Some operations require sudo access${NC}"
    echo "You may be prompted for your password for detailed profiling."
    echo ""
}

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Start deep analysis
log_section "🔬 Deep WindowServer Analysis (Asahi-Inspired)"
log_both "Timestamp: $(date)"
log_both "macOS Version: $(sw_vers -productVersion)"
log_both "Hardware: $(sysctl -n machdep.cpu.brand_string)"
log_both "Log file: $DEEP_LOG"
log_both ""

warn_sudo

# Get WindowServer PID
ws_pid=$(pgrep WindowServer || echo "")
if [ -z "$ws_pid" ]; then
    log_both "${RED}❌ WindowServer process not found!${NC}"
    exit 1
fi

log_both "WindowServer PID: $ws_pid"
log_both ""

# ============================================================================
# SECTION 1: IOSurface Leak Detection
# ============================================================================
log_section "📊 IOSurface Leak Detection"
log_both "IOSurfaces are framebuffers used for window composition."
log_both "Leaked IOSurfaces = unreleased window memory."
log_both ""

# Count total IOSurfaces in the system
log_both "Querying IORegistry for IOSurface objects..."
iosurface_count=$(ioreg -l -w0 -r -c IOSurface 2>/dev/null | grep -c "IOSurface" | head -1 || echo "0")
iosurface_count=${iosurface_count//[^0-9]/}  # Remove non-numeric characters
[ -z "$iosurface_count" ] && iosurface_count=0
log_both "Total active IOSurfaces: $iosurface_count"
log_both ""

# Get detailed IOSurface information
log_both "IOSurface details (showing size and properties):"
ioreg -l -w0 -r -c IOSurface 2>/dev/null | grep -E "IOSurfaceWidth|IOSurfaceHeight|IOSurfaceAllocSize" | head -30 | tee -a "$DEEP_LOG"
log_both ""

# Calculate approximate IOSurface memory usage
iosurface_sizes=$(ioreg -l -w0 -r -c IOSurface 2>/dev/null | grep "IOSurfaceAllocSize" | grep -o '[0-9]\+' || echo "")
if [ ! -z "$iosurface_sizes" ]; then
    total_iosurface_mb=0
    while IFS= read -r size; do
        size_mb=$((size / 1024 / 1024))
        total_iosurface_mb=$((total_iosurface_mb + size_mb))
    done <<< "$iosurface_sizes"
    log_both "Estimated total IOSurface memory: ${total_iosurface_mb}MB"
else
    log_both "${YELLOW}⚠️  Unable to calculate IOSurface memory usage${NC}"
fi

# Analysis
log_both ""
if [ "$iosurface_count" -gt 500 ]; then
    log_both "${RED}⚠️  CRITICAL: Very high IOSurface count (>500)${NC}"
    log_both "   Likely cause: Apps not releasing framebuffers"
    log_both "   Recommendation: Close unused applications"
elif [ "$iosurface_count" -gt 200 ]; then
    log_both "${YELLOW}⚠️  WARNING: High IOSurface count (>200)${NC}"
    log_both "   This is elevated for typical usage"
elif [ "$iosurface_count" -gt 0 ]; then
    log_both "${GREEN}✅ IOSurface count appears normal${NC}"
else
    log_both "${YELLOW}ℹ️  Unable to determine IOSurface count${NC}"
fi

# ============================================================================
# SECTION 2: GPU Memory Pressure Analysis
# ============================================================================
log_section "🎮 GPU Memory Pressure Analysis"
log_both "Analyzing Metal GPU memory usage and pressure..."
log_both ""

# Get GPU info from system_profiler
log_both "GPU Hardware Configuration:"
system_profiler SPDisplaysDataType | grep -E "Chipset Model|VRAM|Metal" | tee -a "$DEEP_LOG"
log_both ""

# Check for GPU memory pressure (requires Metal framework)
log_both "Checking GPU memory pressure indicators..."
log_both ""

# On Apple Silicon, GPU and CPU share unified memory
# Check if we're on Apple Silicon
cpu_brand=$(sysctl -n machdep.cpu.brand_string)
if [[ "$cpu_brand" == *"Apple"* ]]; then
    log_both "${CYAN}Apple Silicon detected - Unified Memory Architecture${NC}"
    log_both "GPU shares system RAM. WindowServer GPU usage is part of its total memory."
    log_both ""
    
    # Get total system memory pressure
    memory_pressure=$(memory_pressure 2>/dev/null || echo "")
    if [ ! -z "$memory_pressure" ]; then
        log_both "System Memory Pressure Status:"
        echo "$memory_pressure" | tee -a "$DEEP_LOG"
    fi
else
    log_both "Discrete GPU detected"
    log_both "GPU has separate VRAM pool"
fi

log_both ""

# ============================================================================
# SECTION 3: WindowServer Activity Profiling
# ============================================================================
log_section "⚙️  WindowServer Activity Profiling"
log_both "Sampling WindowServer CPU activity for 5 seconds..."
log_both "This shows which functions WindowServer spends time in."
log_both ""

# Check if user has sudo access for sampling
if sudo -n true 2>/dev/null; then
    log_both "Running CPU sample (5 seconds)..."
    sample_output=$(sudo sample "$ws_pid" 5 2>&1 || echo "Sample failed")
    
    # Extract hot functions
    hot_functions=$(echo "$sample_output" | grep -E "Heavy|Hot|WindowServer" | head -20 || echo "No hot functions identified")
    
    if [[ "$hot_functions" != "No hot functions identified" ]] && [[ "$hot_functions" != *"Sample failed"* ]]; then
        log_both "Top CPU-intensive functions:"
        echo "$hot_functions" | tee -a "$DEEP_LOG"
        log_both ""
        
        # Analyze patterns
        if echo "$hot_functions" | grep -qi "composition\|render\|draw"; then
            log_both "${YELLOW}⚠️  High rendering activity detected${NC}"
            log_both "   Likely cause: Many visible windows or animations"
        fi
        
        if echo "$hot_functions" | grep -qi "event\|input"; then
            log_both "${YELLOW}⚠️  High input processing activity${NC}"
            log_both "   Likely cause: Mouse/keyboard event handling"
        fi
    else
        log_both "${YELLOW}⚠️  Unable to sample WindowServer (try with sudo)${NC}"
    fi
else
    log_both "${YELLOW}⚠️  Sudo required for CPU sampling - skipping${NC}"
    log_both "   Run: sudo ./diagnose_deep.sh for detailed profiling"
fi

log_both ""

# ============================================================================
# SECTION 4: Memory Region Mapping (vmmap)
# ============================================================================
log_section "💾 Memory Region Mapping"
log_both "Analyzing WindowServer memory regions with vmmap..."
log_both "This shows how memory is allocated (MALLOC, IOSurface, GPU, etc.)"
log_both ""

# Run vmmap
log_both "Generating memory map..."
vmmap_output=$(vmmap "$ws_pid" 2>/dev/null || echo "vmmap failed")

if [[ "$vmmap_output" != "vmmap failed" ]]; then
    # Summarize memory regions
    log_both "Memory Region Summary:"
    echo "$vmmap_output" | grep -E "^[A-Z]" | head -30 | tee -a "$DEEP_LOG"
    log_both ""
    
    # Extract key regions
    log_both "Key Memory Regions:"
    log_both ""
    
    # MALLOC regions (heap allocations)
    malloc_regions=$(echo "$vmmap_output" | grep "MALLOC" || echo "")
    if [ ! -z "$malloc_regions" ]; then
        malloc_count=$(echo "$malloc_regions" | wc -l | xargs)
        log_both "MALLOC regions (heap allocations): $malloc_count"
        # Sum up MALLOC sizes if possible
        log_both "   (Standard application memory allocations)"
    fi
    
    # IOSurface regions (framebuffers)
    iosurface_regions=$(echo "$vmmap_output" | grep -i "IOSurface" || echo "")
    if [ ! -z "$iosurface_regions" ]; then
        iosurface_region_count=$(echo "$iosurface_regions" | wc -l | xargs)
        log_both "IOSurface regions (framebuffers): $iosurface_region_count"
        log_both "   ${YELLOW}⚠️  Each region = one window or layer buffer${NC}"
        
        if [ "$iosurface_region_count" -gt 200 ]; then
            log_both "   ${RED}CRITICAL: Excessive IOSurface regions (>200)${NC}"
            log_both "   Recommendation: Close applications with many windows"
        fi
    else
        log_both "IOSurface regions: None detected"
    fi
    
    # GPU/Metal regions
    gpu_regions=$(echo "$vmmap_output" | grep -iE "GPU|Metal|AGX" || echo "")
    if [ ! -z "$gpu_regions" ]; then
        gpu_region_count=$(echo "$gpu_regions" | wc -l | xargs)
        log_both "GPU/Metal regions: $gpu_region_count"
        log_both "   (Graphics API memory allocations)"
    fi
    
    # Shared memory regions
    shared_regions=$(echo "$vmmap_output" | grep -i "shared" || echo "")
    if [ ! -z "$shared_regions" ]; then
        shared_count=$(echo "$shared_regions" | wc -l | xargs)
        log_both "Shared memory regions: $shared_count"
        log_both "   (IPC with other processes)"
    fi
    
    log_both ""
    
    # Memory fragmentation check
    log_both "Checking for memory fragmentation..."
    region_count=$(echo "$vmmap_output" | grep -c "^[A-Z]" | head -1 || echo "0")
    region_count=${region_count//[^0-9]/}  # Remove non-numeric characters
    [ -z "$region_count" ] && region_count=0
    log_both "Total memory regions: $region_count"
    
    if [ "$region_count" -gt 5000 ]; then
        log_both "${RED}⚠️  CRITICAL: Severe memory fragmentation (>5000 regions)${NC}"
        log_both "   This can cause performance issues and increased memory usage"
        log_both "   Recommendation: Restart WindowServer to defragment"
    elif [ "$region_count" -gt 2000 ]; then
        log_both "${YELLOW}⚠️  WARNING: High memory fragmentation (>2000 regions)${NC}"
        log_both "   Consider restarting WindowServer if performance is degraded"
    else
        log_both "${GREEN}✅ Memory fragmentation appears normal${NC}"
    fi
else
    log_both "${YELLOW}⚠️  Unable to run vmmap${NC}"
    region_count=0
fi

log_both ""

# ============================================================================
# SECTION 5: Recent WindowServer Events & Errors
# ============================================================================
log_section "📋 Recent WindowServer Events & Errors"
log_both "Querying system logs for WindowServer issues (last 5 minutes)..."
log_both ""

# Query unified log for WindowServer errors
log_both "Recent errors and warnings:"
log_output=$(log show --predicate 'process == "WindowServer"' --style compact --last 5m 2>/dev/null | grep -iE "error|warning|fault|leak|crash" | tail -20 || echo "")

if [ ! -z "$log_output" ]; then
    echo "$log_output" | tee -a "$DEEP_LOG"
    log_both ""
    
    # Analyze error patterns
    if echo "$log_output" | grep -qi "memory"; then
        log_both "${RED}⚠️  Memory-related errors detected${NC}"
    fi
    
    if echo "$log_output" | grep -qi "leak"; then
        log_both "${RED}⚠️  Leak-related errors detected${NC}"
    fi
    
    if echo "$log_output" | grep -qi "surface\|buffer\|framebuffer"; then
        log_both "${RED}⚠️  Surface/buffer errors detected${NC}"
        log_both "   Possible framebuffer leak or corruption"
    fi
else
    log_both "${GREEN}✅ No recent errors or warnings${NC}"
fi

log_both ""

# Check for IOSurface-specific errors
log_both "Checking for IOSurface-related issues..."
iosurface_errors=$(log show --predicate 'subsystem == "com.apple.iosurface"' --style compact --last 5m 2>/dev/null | grep -iE "error|warning|fault" | tail -10 || echo "")

if [ ! -z "$iosurface_errors" ]; then
    log_both "${YELLOW}⚠️  IOSurface errors detected:${NC}"
    echo "$iosurface_errors" | tee -a "$DEEP_LOG"
else
    log_both "${GREEN}✅ No IOSurface errors${NC}"
fi

log_both ""

# ============================================================================
# SECTION 6: Display Baseline Calculation (Asahi-inspired)
# ============================================================================
log_section "🖥️  Display Memory Baseline Calculation"
log_both "Calculating expected WindowServer memory for your display configuration..."
log_both "Based on Apple Silicon tile-based rendering architecture."
log_both ""

# Get display resolutions
displays=$(system_profiler SPDisplaysDataType 2>/dev/null)
display_resolutions=$(echo "$displays" | grep "Resolution:" || echo "")

log_both "Detected Displays:"
echo "$display_resolutions" | tee -a "$DEEP_LOG"
log_both ""

# Parse resolutions and calculate expected memory
# Format: "Resolution: 5120 x 2880 Retina"
total_baseline_mb=0
display_num=0

while IFS= read -r line; do
    if [[ "$line" =~ Resolution:\ ([0-9]+)\ x\ ([0-9]+) ]]; then
        width="${BASH_REMATCH[1]}"
        height="${BASH_REMATCH[2]}"
        ((display_num++))
        
        # Calculate memory per display
        # Formula: width × height × 4 bytes (RGBA) × 3 buffers (triple buffering)
        pixels=$((width * height))
        bytes_per_buffer=$((pixels * 4))
        triple_buffer=$((bytes_per_buffer * 3))
        mb_per_display=$((triple_buffer / 1024 / 1024))
        
        # Add 30% overhead for composition, effects, caches
        mb_with_overhead=$((mb_per_display * 130 / 100))
        
        total_baseline_mb=$((total_baseline_mb + mb_with_overhead))
        
        log_both "Display $display_num: ${width}×${height}"
        log_both "  Framebuffer (triple-buffered): ${mb_per_display}MB"
        log_both "  With composition overhead: ${mb_with_overhead}MB"
    fi
done <<< "$display_resolutions"

log_both ""
log_both "Expected WindowServer baseline: ${total_baseline_mb}MB"
log_both "  (This is normal for your display configuration)"
log_both ""

# Get actual WindowServer memory
mem_str=$(top -l 1 -stats pid,command,mem -pid "$ws_pid" 2>/dev/null | grep WindowServer | awk '{print $3}')
if [[ $mem_str == *G ]]; then
    actual_mb=$(echo "${mem_str%G} * 1024" | bc | cut -d. -f1)
elif [[ $mem_str == *M ]]; then
    actual_mb=$(echo "${mem_str%M}" | cut -d. -f1)
fi

log_both "Actual WindowServer memory: ${actual_mb}MB"
log_both ""

# Calculate excess memory
excess_mb=$((actual_mb - total_baseline_mb))

if [ "$excess_mb" -lt 0 ]; then
    log_both "${GREEN}✅ Memory usage is BELOW baseline (excellent)${NC}"
elif [ "$excess_mb" -lt 2000 ]; then
    log_both "${GREEN}✅ Memory usage is normal (${excess_mb}MB above baseline)${NC}"
    log_both "   This excess is expected for active applications and caches"
elif [ "$excess_mb" -lt 5000 ]; then
    log_both "${YELLOW}⚠️  WARNING: ${excess_mb}MB above baseline${NC}"
    log_both "   Likely cause: Many active applications or leaked buffers"
else
    log_both "${RED}⚠️  CRITICAL: ${excess_mb}MB above baseline${NC}"
    log_both "   Strong indication of memory leak"
fi

log_both ""

# ============================================================================
# SECTION 7: App-to-WindowServer Connection Correlation
# ============================================================================
log_section "🔗 App-to-WindowServer Connection Analysis"
log_both "Analyzing which apps have the most WindowServer connections..."
log_both ""

# Get all processes with WindowServer connections
log_both "Top 10 apps by WindowServer connections:"
lsof_output=$(lsof -c WindowServer 2>/dev/null | grep -v "WindowServer" | awk '{print $1}' | sort | uniq -c | sort -rn | head -10 || echo "")

if [ ! -z "$lsof_output" ]; then
    echo "$lsof_output" | tee -a "$DEEP_LOG"
    log_both ""
    
    # Identify heavy users
    heavy_user=$(echo "$lsof_output" | head -1 | awk '{print $2}')
    heavy_count=$(echo "$lsof_output" | head -1 | awk '{print $1}')
    
    if [ "$heavy_count" -gt 1000 ]; then
        log_both "${RED}⚠️  $heavy_user has excessive connections ($heavy_count)${NC}"
        log_both "   This app may be leaking WindowServer connections"
        log_both "   Recommendation: Restart $heavy_user"
    fi
else
    log_both "${YELLOW}⚠️  Unable to analyze connections (try with sudo)${NC}"
fi

log_both ""

# ============================================================================
# SECTION 8: Deep Diagnosis Summary
# ============================================================================
log_section "📊 Deep Diagnosis Summary"

log_both ""
log_both "Key Findings:"
log_both "  IOSurfaces: $iosurface_count active"
log_both "  Memory regions: $region_count"
log_both "  Expected baseline: ${total_baseline_mb}MB"
log_both "  Actual usage: ${actual_mb}MB"
log_both "  Excess: ${excess_mb}MB"
log_both ""

# Generate technical recommendations
log_both "Technical Insights:"
log_both ""

if [ "$iosurface_count" -gt 300 ]; then
    log_both "1. ${RED}Excessive IOSurface allocations detected${NC}"
    log_both "   Root cause: Applications not releasing framebuffers"
    log_both "   Technical: Each window/layer creates IOSurface objects"
    log_both "   Solution: Close applications, especially those with many windows"
    log_both ""
fi

if [ "$region_count" -gt 3000 ]; then
    log_both "2. ${RED}Severe memory fragmentation${NC}"
    log_both "   Root cause: Long uptime + many allocation/deallocation cycles"
    log_both "   Technical: Virtual memory map has too many regions"
    log_both "   Solution: Restart WindowServer to defragment address space"
    log_both ""
fi

if [ "$excess_mb" -gt 5000 ]; then
    log_both "3. ${RED}Significant memory leak confirmed${NC}"
    log_both "   Excess memory: ${excess_mb}MB above display baseline"
    log_both "   Technical: Memory not accounted for by framebuffers"
    log_both "   Solution: Run diagnose.sh to identify leak-causing apps"
    log_both ""
fi

log_both "${CYAN}Next Steps:${NC}"
log_both "1. Review technical findings above"
log_both "2. Cross-reference with ./diagnose.sh for app-level analysis"
log_both "3. Apply recommendations based on severity"
log_both "4. Re-run this tool after changes to measure improvement"
log_both ""
log_both "Full deep analysis saved to: $DEEP_LOG"
log_both ""
log_both "${GREEN}Deep diagnosis complete!${NC}"
log_both ""
log_both "${CYAN}Pro Tip:${NC} Run with sudo for more detailed profiling:"
log_both "  sudo ./diagnose_deep.sh"
