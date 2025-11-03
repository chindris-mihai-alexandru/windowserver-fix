#!/bin/bash
# health_check.sh - User account health validation
# Part of windowserver-fix v2.1 - System health diagnostics

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/windowserver-fix/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HEALTH_LOG="$LOG_DIR/health_check_$TIMESTAMP.log"

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_both() {
    echo "$1" | tee -a "$HEALTH_LOG"
}

log_section() {
    echo "" | tee -a "$HEALTH_LOG"
    echo -e "${BLUE}$1${NC}" | tee -a "$HEALTH_LOG"
    echo "$(printf '=%.0s' {1..80})" | tee -a "$HEALTH_LOG"
}

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Start health check
log_section "🩺 User Account Health Check"
log_both "Timestamp: $(date)"
log_both "User: $(whoami)"
log_both "Home: $HOME"
log_both "Log file: $HEALTH_LOG"
log_both ""

health_score=100
issues_found=0

# Check 1: Login Items
log_section "🚀 Login Items Analysis"
login_count=$(osascript -e 'tell application "System Events" to count login items' 2>/dev/null || echo "0")
log_both "Login items count: $login_count"

if [ "$login_count" -gt 20 ]; then
    log_both "${RED}❌ CRITICAL: Too many login items (>20)${NC}"
    log_both "   This can cause significant memory leaks at startup"
    health_score=$((health_score - 20))
    ((issues_found++))
elif [ "$login_count" -gt 15 ]; then
    log_both "${YELLOW}⚠️  WARNING: High login item count (>15)${NC}"
    log_both "   Consider removing unused startup apps"
    health_score=$((health_score - 10))
    ((issues_found++))
else
    log_both "${GREEN}✅ Login items count is healthy${NC}"
fi

# Check 2: Cache Size
log_section "💾 Cache Analysis"
cache_size=$(du -sm ~/Library/Caches 2>/dev/null | awk '{print $1}')
log_both "User cache size: ${cache_size}MB"

if [ "$cache_size" -gt 20000 ]; then
    log_both "${RED}❌ CRITICAL: Cache extremely large (>20GB)${NC}"
    log_both "   Action required: Clear caches immediately"
    health_score=$((health_score - 25))
    ((issues_found++))
elif [ "$cache_size" -gt 10000 ]; then
    log_both "${YELLOW}⚠️  WARNING: Cache very large (>10GB)${NC}"
    log_both "   Recommended: Clear caches soon"
    health_score=$((health_score - 15))
    ((issues_found++))
elif [ "$cache_size" -gt 5000 ]; then
    log_both "${YELLOW}⚠️  Cache moderately large (>5GB)${NC}"
    log_both "   Consider clearing if experiencing issues"
    health_score=$((health_score - 5))
else
    log_both "${GREEN}✅ Cache size is normal${NC}"
fi

# Check 3: Preference Files Corruption
log_section "📋 Preference Files Health"
corrupted_prefs=$(find ~/Library/Preferences -name "*.plist" -size 0 2>/dev/null | wc -l | xargs)
total_prefs=$(find ~/Library/Preferences -name "*.plist" 2>/dev/null | wc -l | xargs)
log_both "Total preference files: $total_prefs"
log_both "Corrupted (0-byte) files: $corrupted_prefs"

if [ "$corrupted_prefs" -gt 10 ]; then
    log_both "${RED}❌ CRITICAL: Many corrupted preference files (>10)${NC}"
    log_both "   This indicates serious account corruption"
    health_score=$((health_score - 25))
    ((issues_found++))
elif [ "$corrupted_prefs" -gt 0 ]; then
    log_both "${YELLOW}⚠️  WARNING: Found $corrupted_prefs corrupted preference file(s)${NC}"
    log_both "   May cause app or system issues"
    health_score=$((health_score - 10))
    ((issues_found++))
    
    # List corrupted files
    log_both "   Corrupted files:"
    find ~/Library/Preferences -name "*.plist" -size 0 2>/dev/null | head -5 | while read file; do
        log_both "   - $(basename "$file")"
    done
else
    log_both "${GREEN}✅ No corrupted preference files found${NC}"
fi

# Check 4: WindowServer Preference Health
log_section "🪟 WindowServer Preference Files"
ws_prefs=$(find ~/Library/Preferences/ByHost -name "com.apple.windowserver*" 2>/dev/null || echo "")
if [ ! -z "$ws_prefs" ]; then
    log_both "WindowServer preference files found:"
    echo "$ws_prefs" | while read file; do
        size=$(du -h "$file" | awk '{print $1}')
        log_both "   $(basename "$file") - $size"
    done
    
    # Check for abnormally large WindowServer prefs
    large_ws_prefs=$(find ~/Library/Preferences/ByHost -name "com.apple.windowserver*" -size +1M 2>/dev/null || echo "")
    if [ ! -z "$large_ws_prefs" ]; then
        log_both "${YELLOW}⚠️  WARNING: Large WindowServer preference file detected (>1MB)${NC}"
        log_both "   May contain corrupted data"
        health_score=$((health_score - 10))
        ((issues_found++))
    fi
else
    log_both "${GREEN}✅ WindowServer preferences normal${NC}"
fi

# Check 5: Zombie Processes
log_section "👻 Zombie Process Detection"
zombie_count=$(ps aux | awk '$8 ~ /Z/ {print $0}' | wc -l | xargs)
log_both "Zombie processes: $zombie_count"

if [ "$zombie_count" -gt 10 ]; then
    log_both "${RED}❌ CRITICAL: Many zombie processes (>10)${NC}"
    log_both "   System may be unstable"
    health_score=$((health_score - 20))
    ((issues_found++))
elif [ "$zombie_count" -gt 0 ]; then
    log_both "${YELLOW}⚠️  WARNING: Found $zombie_count zombie process(es)${NC}"
    log_both "   Usually harmless but can indicate issues"
    health_score=$((health_score - 5))
else
    log_both "${GREEN}✅ No zombie processes detected${NC}"
fi

# Check 6: Home Directory Size
log_section "📁 Home Directory Analysis"
home_size=$(du -sm "$HOME" 2>/dev/null | awk '{print $1}')
log_both "Home directory size: ${home_size}MB (~$((home_size / 1024))GB)"

if [ "$home_size" -gt 500000 ]; then
    log_both "${YELLOW}⚠️  Very large home directory (>500GB)${NC}"
    log_both "   May slow down system operations"
    health_score=$((health_score - 5))
fi

# Check 7: Disk Space
log_section "💽 Disk Space Analysis"
disk_avail=$(df -h "$HOME" | tail -1 | awk '{print $4}')
disk_pct=$(df -h "$HOME" | tail -1 | awk '{print $5}' | sed 's/%//')
log_both "Available disk space: $disk_avail"
log_both "Disk usage: ${disk_pct}%"

if [ "$disk_pct" -gt 95 ]; then
    log_both "${RED}❌ CRITICAL: Very low disk space (<5% free)${NC}"
    log_both "   Can cause WindowServer and system issues"
    health_score=$((health_score - 30))
    ((issues_found++))
elif [ "$disk_pct" -gt 90 ]; then
    log_both "${YELLOW}⚠️  WARNING: Low disk space (<10% free)${NC}"
    log_both "   Free up space soon"
    health_score=$((health_score - 15))
    ((issues_found++))
else
    log_both "${GREEN}✅ Disk space is adequate${NC}"
fi

# Check 8: LaunchAgents/LaunchDaemons
log_section "⚙️  LaunchAgents Analysis"
user_agents=$(ls ~/Library/LaunchAgents/*.plist 2>/dev/null | wc -l | xargs)
log_both "User LaunchAgents: $user_agents"

if [ "$user_agents" -gt 30 ]; then
    log_both "${YELLOW}⚠️  Many LaunchAgents (>30)${NC}"
    log_both "   Some may be running unnecessary background tasks"
    health_score=$((health_score - 5))
fi

# Check for known problematic agents
problematic_agents=$(ls ~/Library/LaunchAgents/*.plist 2>/dev/null | grep -iE "adobe|dropbox|creative" | wc -l | xargs)
if [ "$problematic_agents" -gt 0 ]; then
    log_both "${YELLOW}   Note: Found $problematic_agents agent(s) from Adobe/Dropbox/etc${NC}"
    log_both "   These can contribute to system load"
fi

# Check 9: System Logs for Errors
log_section "📝 Recent System Errors"
log_both "Checking for WindowServer-related errors in last 24 hours..."
ws_errors=$(log show --predicate 'process == "WindowServer"' --style syslog --last 24h 2>/dev/null | grep -i "error\|crash\|fault" | wc -l | xargs || echo "0")
log_both "WindowServer errors found: $ws_errors"

if [ "$ws_errors" -gt 50 ]; then
    log_both "${RED}❌ CRITICAL: Many WindowServer errors (>50)${NC}"
    log_both "   Check Console.app for details"
    health_score=$((health_score - 20))
    ((issues_found++))
elif [ "$ws_errors" -gt 10 ]; then
    log_both "${YELLOW}⚠️  WARNING: Some WindowServer errors (>10)${NC}"
    log_both "   May indicate underlying issues"
    health_score=$((health_score - 10))
    ((issues_found++))
else
    log_both "${GREEN}✅ Low error count${NC}"
fi

# Check 10: Memory Pressure
log_section "🧠 Memory Pressure"
memory_pressure=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $5}' | sed 's/%//' || echo "unknown")
if [ "$memory_pressure" != "unknown" ]; then
    log_both "System memory free: ${memory_pressure}%"
    
    if [ "$memory_pressure" -lt 10 ]; then
        log_both "${RED}❌ CRITICAL: Very low free memory (<10%)${NC}"
        log_both "   System under extreme memory pressure"
        health_score=$((health_score - 20))
        ((issues_found++))
    elif [ "$memory_pressure" -lt 20 ]; then
        log_both "${YELLOW}⚠️  WARNING: Low free memory (<20%)${NC}"
        log_both "   Close unnecessary apps"
        health_score=$((health_score - 10))
    else
        log_both "${GREEN}✅ Memory pressure normal${NC}"
    fi
else
    log_both "Unable to determine memory pressure"
fi

# Final Health Score
log_section "🎯 Overall Health Score"
log_both ""
log_both "Health Score: $health_score/100"
log_both "Issues Found: $issues_found"
log_both ""

if [ $health_score -ge 90 ]; then
    log_both "${GREEN}✅ EXCELLENT: User account is healthy${NC}"
    log_both "   No significant issues detected"
elif [ $health_score -ge 75 ]; then
    log_both "${GREEN}✅ GOOD: Minor issues detected${NC}"
    log_both "   Address warnings when convenient"
elif [ $health_score -ge 60 ]; then
    log_both "${YELLOW}⚠️  FAIR: Some issues need attention${NC}"
    log_both "   Review and address warnings"
elif [ $health_score -ge 40 ]; then
    log_both "${YELLOW}⚠️  POOR: Multiple issues detected${NC}"
    log_both "   Address critical issues soon"
else
    log_both "${RED}❌ CRITICAL: Serious account health issues${NC}"
    log_both "   Immediate action required"
fi

# Recommendations
log_section "💡 Recommendations"
echo "" | tee -a "$HEALTH_LOG"

recommendation_count=1

if [ "$cache_size" -gt 10000 ]; then
    log_both "$recommendation_count. Clear user caches (${cache_size}MB)"
    log_both "   Command: rm -rf ~/Library/Caches/*"
    ((recommendation_count++))
fi

if [ "$corrupted_prefs" -gt 0 ]; then
    log_both "$recommendation_count. Remove corrupted preference files"
    log_both "   Command: find ~/Library/Preferences -name '*.plist' -size 0 -delete"
    ((recommendation_count++))
fi

if [ "$login_count" -gt 15 ]; then
    log_both "$recommendation_count. Remove unused login items"
    log_both "   Location: System Settings > General > Login Items"
    ((recommendation_count++))
fi

if [ "$disk_pct" -gt 90 ]; then
    log_both "$recommendation_count. Free up disk space (currently ${disk_pct}% used)"
    log_both "   Use Disk Utility or clean up large files"
    ((recommendation_count++))
fi

if [ $health_score -lt 40 ]; then
    log_both ""
    log_both "${YELLOW}⚠️  Consider creating a new user account for testing:${NC}"
    log_both "   1. System Settings > Users & Groups > Add User"
    log_both "   2. Log in to new account and test WindowServer memory"
    log_both "   3. If memory is normal, current account may be corrupted"
    log_both "   4. Migrate data carefully or use Migration Assistant"
fi

log_both ""
log_both "${BLUE}Next Steps:${NC}"
log_both "1. Address critical issues (marked with ❌) immediately"
log_both "2. Fix warnings (marked with ⚠️) when possible"
log_both "3. Run './diagnose.sh' to check for app-specific leak causes"
log_both "4. Re-run this health check after fixes: ./health_check.sh"
log_both ""
log_both "Full health report saved to: $HEALTH_LOG"
log_both ""
log_both "${GREEN}Health check complete!${NC}"
