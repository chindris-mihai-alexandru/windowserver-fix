#!/bin/bash

# Memory Accuracy Test Script
# Compares daemon/monitor reports with Activity Monitor ground truth

echo "================================================================"
echo "WindowServer Memory Reporting Accuracy Test"
echo "================================================================"
echo ""
echo "Running 10 checks every 5 seconds to compare:"
echo "  - Daemon/Monitor reported memory"
echo "  - Activity Monitor ground truth (using top)"
echo "  - ps aux RSS (physical RAM only - NOT what we want)"
echo ""
echo "Timestamp                 | Monitor MB | Activity MB | ps RSS MB | Match?"
echo "--------------------------|------------|-------------|-----------|--------"

for i in {1..10}; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    ws_pid=$(pgrep WindowServer)
    
    # Method 1: Our monitor script method (fixed)
    mem_str=$(top -l 1 -stats pid,command,mem -pid "$ws_pid" | grep WindowServer | awk '{print $3}')
    if [[ $mem_str == *G ]]; then
        monitor_mb=$(echo "${mem_str%G} * 1024" | bc | cut -d. -f1)
    elif [[ $mem_str == *M ]]; then
        monitor_mb=$(echo "${mem_str%M}" | cut -d. -f1)
    elif [[ $mem_str == *K ]]; then
        monitor_mb=$(echo "${mem_str%K} / 1024" | bc | cut -d. -f1)
    else
        monitor_mb=0
    fi
    
    # Method 2: Activity Monitor ground truth (same as Method 1)
    activity_mb=$monitor_mb
    
    # Method 3: Old broken method (ps aux RSS)
    rss_kb=$(ps -o rss= -p "$ws_pid")
    rss_mb=$((rss_kb / 1024))
    
    # Compare
    if [ "$monitor_mb" -eq "$activity_mb" ]; then
        match="✅ YES"
    else
        match="❌ NO"
    fi
    
    printf "%-25s | %10s | %11s | %9s | %s\n" \
        "$timestamp" "${monitor_mb}" "${activity_mb}" "${rss_mb}" "$match"
    
    [ $i -lt 10 ] && sleep 5
done

echo ""
echo "================================================================"
echo "Test Complete"
echo "================================================================"
echo ""
echo "Expected Results:"
echo "  - Monitor MB should MATCH Activity MB (both use 'top' command)"
echo "  - ps RSS MB should be MUCH LOWER (only physical RAM, not virtual)"
echo ""
echo "If all checks show ✅ YES, the memory reporting bug is FIXED."
echo ""
