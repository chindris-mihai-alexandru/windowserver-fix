#!/bin/bash
# app_patterns.sh - Historical leak pattern analyzer
# Part of windowserver-fix v2.1 - Pattern recognition for root causes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/windowserver-fix/logs"
LEAK_EVENTS_LOG="$LOG_DIR/leak_events.log"
PATTERN_REPORT="$LOG_DIR/pattern_analysis_$(date +%Y%m%d_%H%M%S).log"

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_both() {
    echo "$1" | tee -a "$PATTERN_REPORT"
}

log_section() {
    echo "" | tee -a "$PATTERN_REPORT"
    echo -e "${BLUE}$1${NC}" | tee -a "$PATTERN_REPORT"
    echo "$(printf '=%.0s' {1..80})" | tee -a "$PATTERN_REPORT"
}

# Check if leak_events.log exists
if [ ! -f "$LEAK_EVENTS_LOG" ]; then
    echo -e "${YELLOW}⚠️  No historical leak data found${NC}"
    echo ""
    echo "The leak events log doesn't exist yet. This log is created when:"
    echo "  1. The daemon detects a leak and logs active apps"
    echo "  2. You run the enhanced daemon (after v2.1 updates)"
    echo ""
    echo "To start collecting pattern data:"
    echo "  1. Make sure daemon.sh is updated with leak logging"
    echo "  2. Run: ./daemon.sh start"
    echo "  3. Wait for leaks to be detected"
    echo "  4. Run this script again after a few days"
    echo ""
    exit 0
fi

# Start analysis
log_section "📊 Historical Leak Pattern Analysis"
log_both "Timestamp: $(date)"
log_both "Analyzing: $LEAK_EVENTS_LOG"
log_both "Report saved to: $PATTERN_REPORT"
log_both ""

# Count total leak events
total_events=$(grep -c "LEAK DETECTED" "$LEAK_EVENTS_LOG" 2>/dev/null || echo "0")
log_both "Total leak events recorded: $total_events"

if [ "$total_events" -eq 0 ]; then
    log_both ""
    log_both "${GREEN}✅ No leak events recorded yet${NC}"
    log_both ""
    log_both "This is good news! Either:"
    log_both "  - No leaks have occurred"
    log_both "  - Daemon hasn't run long enough to detect patterns"
    log_both ""
    exit 0
fi

# Section 1: Most Common Apps During Leaks
log_section "🎯 Apps Most Frequently Present During Leaks"

# Extract all app names from leak events
temp_apps=$(mktemp)
awk '/LEAK DETECTED/,/---/' "$LEAK_EVENTS_LOG" | grep -v "LEAK DETECTED" | grep -v "---" | grep -v "^$" > "$temp_apps"

if [ -s "$temp_apps" ]; then
    # Count occurrences of each app
    log_both ""
    log_both "Rank  Count  % of Leaks  Application"
    log_both "----  -----  ----------  -----------"
    
    sort "$temp_apps" | uniq -c | sort -rn | head -20 | while read count app; do
        percentage=$((count * 100 / total_events))
        if [ $percentage -gt 70 ]; then
            color=$RED
            risk="HIGH RISK"
        elif [ $percentage -gt 40 ]; then
            color=$YELLOW
            risk="MEDIUM RISK"
        else
            color=$GREEN
            risk=""
        fi
        
        printf "${color}%-4s  %-5s  %-10s  %s  %s${NC}\n" "$((++rank))" "$count" "${percentage}%" "$(basename "$app")" "$risk" | tee -a "$PATTERN_REPORT"
    done
else
    log_both "${YELLOW}Unable to extract app data from logs${NC}"
fi

rm -f "$temp_apps"

# Section 2: High-Risk App Identification
log_section "🚨 High-Risk Applications (Present in >70% of Leaks)"

high_risk_apps=$(awk '/LEAK DETECTED/,/---/' "$LEAK_EVENTS_LOG" | grep -v "LEAK DETECTED" | grep -v "---" | grep -v "^$" | sort | uniq -c | sort -rn | awk -v total="$total_events" '{pct=$1*100/total; if(pct>70) print $0}')

if [ ! -z "$high_risk_apps" ]; then
    log_both ""
    echo "$high_risk_apps" | while read count app; do
        percentage=$((count * 100 / total_events))
        app_name=$(basename "$app")
        log_both "${RED}⚠️  $app_name${NC}"
        log_both "   Present in: $count/$total_events leak events (${percentage}%)"
        log_both "   Recommendation: Close or remove this app"
    done
else
    log_both "${GREEN}✅ No apps present in >70% of leak events${NC}"
fi

# Section 3: Temporal Patterns
log_section "⏰ Temporal Analysis"

log_both "Leak events by hour of day:"
log_both ""
grep "LEAK DETECTED" "$LEAK_EVENTS_LOG" | awk '{print $2}' | cut -d: -f1 | sort | uniq -c | sort -k2 -n | while read count hour; do
    bar=$(printf '█%.0s' $(seq 1 $count))
    printf "  %02d:00  %-5s  %s\n" "$hour" "$count" "$bar" | tee -a "$PATTERN_REPORT"
done

log_both ""
log_both "Leak events by day of week:"
log_both ""
grep "LEAK DETECTED" "$LEAK_EVENTS_LOG" | awk '{print $1}' | xargs -I {} date -jf "%Y-%m-%d" {} "+%A" 2>/dev/null | sort | uniq -c | sort -rn | while read count day; do
    bar=$(printf '█%.0s' $(seq 1 $count))
    printf "  %-10s  %-5s  %s\n" "$day" "$count" "$bar" | tee -a "$PATTERN_REPORT"
done

# Section 4: Leak Severity Trends
log_section "📈 Memory Usage Trends"

log_both "Leak events by memory threshold:"
log_both ""

critical_count=$(grep "LEAK DETECTED" "$LEAK_EVENTS_LOG" | grep -c "CRITICAL" || echo "0")
warning_count=$(grep "LEAK DETECTED" "$LEAK_EVENTS_LOG" | grep -c "WARNING" || echo "0")
emergency_count=$(grep "LEAK DETECTED" "$LEAK_EVENTS_LOG" | grep -c "EMERGENCY" || echo "0")

log_both "  CRITICAL (5-20GB):  $critical_count events"
log_both "  WARNING (2-5GB):    $warning_count events"
log_both "  EMERGENCY (>20GB):  $emergency_count events"

if [ "$emergency_count" -gt 0 ]; then
    log_both ""
    log_both "${RED}⚠️  Emergency-level leaks detected!${NC}"
    log_both "   System reached >20GB WindowServer memory $emergency_count time(s)"
fi

# Section 5: Correlation Analysis
log_section "🔗 App Correlation Analysis"

log_both "Apps that frequently appear together during leaks:"
log_both ""

# Find common app pairs
temp_pairs=$(mktemp)
awk '/LEAK DETECTED/{getline; events++; apps=""} /---/{if(apps) print apps; apps=""} !/LEAK DETECTED/ && !/---/ && NF {apps=apps" "$0}' "$LEAK_EVENTS_LOG" | while read -r line; do
    echo "$line" | tr ' ' '\n' | sort | uniq | while read app1; do
        echo "$line" | tr ' ' '\n' | sort | uniq | while read app2; do
            if [ "$app1" != "$app2" ] && [ ! -z "$app1" ] && [ ! -z "$app2" ]; then
                if [[ "$app1" < "$app2" ]]; then
                    echo "$(basename "$app1")|$(basename "$app2")"
                else
                    echo "$(basename "$app2")|$(basename "$app1")"
                fi
            fi
        done
    done
done | sort | uniq -c | sort -rn | head -10 > "$temp_pairs"

if [ -s "$temp_pairs" ]; then
    log_both "Top app combinations (present together during leaks):"
    log_both ""
    cat "$temp_pairs" | while read count pair; do
        app1=$(echo "$pair" | cut -d'|' -f1)
        app2=$(echo "$pair" | cut -d'|' -f2)
        percentage=$((count * 100 / total_events))
        log_both "  $app1 + $app2: $count times (${percentage}%)"
    done
else
    log_both "Insufficient data for correlation analysis"
fi

rm -f "$temp_pairs"

# Section 6: Recent vs Historical Comparison
log_section "📅 Recent Trend Analysis"

# Get first and last dates
first_date=$(grep "LEAK DETECTED" "$LEAK_EVENTS_LOG" | head -1 | awk '{print $1}')
last_date=$(grep "LEAK DETECTED" "$LEAK_EVENTS_LOG" | tail -1 | awk '{print $1}')

log_both "Data range: $first_date to $last_date"
log_both ""

# Last 7 days vs earlier
recent_count=$(grep "LEAK DETECTED" "$LEAK_EVENTS_LOG" | tail -20 | wc -l | xargs)
older_count=$((total_events - recent_count))

log_both "Recent leak events (last 20 logs): $recent_count"
log_both "Older leak events: $older_count"
log_both ""

if [ "$recent_count" -gt "$older_count" ] && [ "$older_count" -gt 0 ]; then
    log_both "${RED}⚠️  Leak frequency is INCREASING${NC}"
    log_both "   Trend: Getting worse over time"
elif [ "$recent_count" -lt "$older_count" ]; then
    log_both "${GREEN}✅ Leak frequency is DECREASING${NC}"
    log_both "   Trend: Getting better over time"
else
    log_both "${YELLOW}➡️  Leak frequency is STABLE${NC}"
    log_both "   Trend: Consistent pattern"
fi

# Section 7: Actionable Recommendations
log_section "💡 Actionable Recommendations"

log_both ""
log_both "Based on $total_events leak events analyzed:"
log_both ""

recommendation_num=1

# Extract high-risk apps again for recommendations
high_risk=$(awk '/LEAK DETECTED/,/---/' "$LEAK_EVENTS_LOG" | grep -v "LEAK DETECTED" | grep -v "---" | grep -v "^$" | sort | uniq -c | sort -rn | awk -v total="$total_events" '{pct=$1*100/total; if(pct>70) print $2}' | head -3)

if [ ! -z "$high_risk" ]; then
    log_both "${recommendation_num}. ${RED}[CRITICAL]${NC} Remove or replace these high-risk apps:"
    echo "$high_risk" | while read app; do
        log_both "   - $(basename "$app")"
    done
    log_both ""
    ((recommendation_num++))
fi

medium_risk=$(awk '/LEAK DETECTED/,/---/' "$LEAK_EVENTS_LOG" | grep -v "LEAK DETECTED" | grep -v "---" | grep -v "^$" | sort | uniq -c | sort -rn | awk -v total="$total_events" '{pct=$1*100/total; if(pct>40 && pct<=70) print $2}' | head -3)

if [ ! -z "$medium_risk" ]; then
    log_both "${recommendation_num}. ${YELLOW}[MEDIUM]${NC} Monitor or limit use of these apps:"
    echo "$medium_risk" | while read app; do
        log_both "   - $(basename "$app")"
    done
    log_both ""
    ((recommendation_num++))
fi

if [ "$emergency_count" -gt 0 ]; then
    log_both "${recommendation_num}. ${RED}[CRITICAL]${NC} Reduce time between './monitor.sh check' runs"
    log_both "   Emergency levels reached $emergency_count time(s)"
    log_both ""
    ((recommendation_num++))
fi

# Check for known problematic apps
known_bad=$(awk '/LEAK DETECTED/,/---/' "$LEAK_EVENTS_LOG" | grep -iE "OBS|Chrome|Firefox|Zoom|Teams|Slack|BetterDisplay|iPhone Mirroring" | sort | uniq)

if [ ! -z "$known_bad" ]; then
    log_both "${recommendation_num}. ${YELLOW}[INFO]${NC} Known problematic apps detected in your logs:"
    echo "$known_bad" | while read app; do
        log_both "   - $(basename "$app")"
    done
    log_both "   See: ./diagnose.sh for known issues with these apps"
    log_both ""
    ((recommendation_num++))
fi

log_both "${BLUE}Next Steps:${NC}"
log_both "1. Address high-risk apps (present in >70% of leaks)"
log_both "2. Run './diagnose.sh' for current system analysis"
log_both "3. Continue monitoring with daemon for more data"
log_both "4. Re-run this analysis in 1 week to track progress"
log_both ""
log_both "Full pattern analysis saved to: $PATTERN_REPORT"
log_both ""
log_both "${GREEN}Pattern analysis complete!${NC}"
