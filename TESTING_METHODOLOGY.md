# WindowServer Memory Leak Mitigation Testing Methodology

## Overview

This document defines the comprehensive testing strategy for validating the effectiveness of the WindowServer memory leak mitigation toolkit on macOS Sequoia 15.x systems.

## Test Environment

### System Requirements
- macOS Sequoia 15.x (tested on 15.7.2 Build 24G325)
- Minimum 16GB RAM recommended for accurate baseline measurements
- Activity Monitor or terminal access for memory measurement

### Prerequisites
- WindowServer leak mitigation toolkit v2.0.0 or higher installed
- System restarted before baseline measurements
- No other memory-intensive applications running during tests

## Testing Framework

### 1. Baseline Measurement Phase

**Objective:** Establish normal WindowServer memory usage patterns without mitigation

**Duration:** 4-6 hours

**Procedure:**
1. Disable all mitigation services:
   ```bash
   sudo launchctl bootout system /Library/LaunchDaemons/com.windowserver.monitor.plist
   sudo launchctl bootout system /Library/LaunchDaemons/com.windowserver.daemon.plist
   ```
2. Restart system
3. Record initial WindowServer memory usage immediately after login
4. Execute test scenarios (see section 3)
5. Record WindowServer memory every 30 minutes
6. Document peak memory usage and rate of increase

### 2. Mitigation Validation Phase

**Objective:** Validate memory leak prevention with active mitigation

**Duration:** 4-6 hours

**Procedure:**
1. Re-enable mitigation services:
   ```bash
   sudo ./install.sh
   ```
2. Restart system
3. Record initial WindowServer memory usage immediately after login
4. Execute identical test scenarios from baseline phase
5. Record WindowServer memory every 30 minutes
6. Document peak memory usage and mitigation effectiveness

### 3. Test Scenarios

#### Scenario A: iPhone Mirroring Trigger
**Known Issue:** iPhone Mirroring feature causes rapid WindowServer memory growth

**Steps:**
1. Connect iPhone via USB or WiFi
2. Launch iPhone Mirroring application
3. Interact with iPhone interface for 30 minutes
4. Disconnect and reconnect iPhone 3 times during test period
5. Monitor WindowServer memory growth

**Expected Baseline:** 2-8GB increase over 2 hours
**Expected with Mitigation:** Less than 1GB increase, stable memory

#### Scenario B: Ultra-Wide Display Trigger
**Known Issue:** Ultra-wide or high-resolution external displays accelerate leak

**Steps:**
1. Connect external display (2560x1440 or higher resolution)
2. Move windows between displays repeatedly
3. Switch between different display arrangements
4. Open multiple windows across displays
5. Monitor WindowServer memory growth

**Expected Baseline:** 1-4GB increase over 4 hours
**Expected with Mitigation:** Less than 500MB increase, stable memory

#### Scenario C: Browser-Heavy Workload
**Known Issue:** Multiple browser windows/tabs with media content trigger leak

**Steps:**
1. Open Safari or Chrome with 20+ tabs
2. Include tabs with video content, animations, WebGL
3. Switch between tabs frequently
4. Open and close new windows
5. Monitor WindowServer memory growth

**Expected Baseline:** 1-3GB increase over 3 hours
**Expected with Mitigation:** Less than 500MB increase, stable memory

#### Scenario D: Combined Real-World Usage
**Known Issue:** Multiple triggers compound the leak effect

**Steps:**
1. Enable all known triggers simultaneously:
   - External display connected
   - iPhone Mirroring active
   - Multiple browser windows with media
   - Frequent app switching and window management
2. Simulate normal workday activities
3. Monitor WindowServer memory growth over extended period

**Expected Baseline:** 5-15GB increase over 6 hours, potential system instability
**Expected with Mitigation:** Less than 2GB increase, stable operation

### 4. Memory Measurement Commands

#### Using Activity Monitor (GUI)
1. Open Activity Monitor.app
2. Select "Memory" tab
3. Search for "WindowServer" process
4. Record "Memory" column value

#### Using Terminal (CLI)
```bash
# Current WindowServer memory usage in MB
ps aux | grep WindowServer | grep -v grep | awk '{print $6/1024 " MB"}'

# Detailed memory breakdown
sudo footprint WindowServer

# Continuous monitoring (updates every 60 seconds)
watch -n 60 'ps aux | grep WindowServer | grep -v grep | awk "{print \$6/1024 \" MB\"}"'
```

#### Using Diagnostic Script
```bash
# Run built-in diagnostic
sudo ./diagnose.sh

# Check service health
./health_check.sh
```

### 5. Data Collection Template

Create CSV file with following columns:

```
Timestamp,Phase,Scenario,WindowServer_Memory_MB,Uptime_Hours,Notes
2025-11-03 09:00,Baseline,Initial,450,0.1,System just restarted
2025-11-03 09:30,Baseline,Scenario_A,1200,0.5,iPhone Mirroring started
2025-11-03 10:00,Baseline,Scenario_A,2400,1.0,Noticeable slowdown
```

### 6. Success Criteria

**Pass Conditions:**
- WindowServer memory growth reduced by at least 70% compared to baseline
- No system crashes or freezes during 6-hour test period
- Peak WindowServer memory stays below 3GB with mitigation enabled
- Memory remains stable (less than 100MB growth per hour after initial plateau)

**Fail Conditions:**
- WindowServer memory exceeds 5GB during mitigation test
- System becomes unresponsive or requires force restart
- Memory leak rate similar to baseline (less than 50% improvement)

### 7. Known Variables and Exclusions

**Exclude from testing:**
- Third-party window managers (Magnet, Rectangle, etc.) - disable during tests
- Screen recording or capture software - may affect WindowServer independently
- Virtual machines with display passthrough - creates abnormal WindowServer load
- Beta or developer builds of macOS - behavior may differ from release versions

**Document if present:**
- Number and resolution of connected displays
- iPhone model and iOS version (for Mirroring tests)
- GPU model and VRAM amount
- Any kernel extensions or system modifications

### 8. Troubleshooting During Tests

**If mitigation services fail:**
```bash
# Check service status
sudo launchctl list | grep windowserver

# Check logs
sudo log show --predicate 'subsystem == "com.windowserver.fix"' --last 1h

# Restart services
sudo launchctl kickstart system/com.windowserver.monitor
sudo launchctl kickstart system/com.windowserver.daemon
```

**If system becomes unstable:**
1. Save all work immediately
2. Document current state (screenshot Activity Monitor)
3. Run emergency diagnostic: `sudo ./diagnose_deep.sh`
4. Force WindowServer restart: `sudo killall -HUP WindowServer` (logs out user)

### 9. Reporting Results

**Required Information:**
- macOS version and build number
- Hardware specifications (Mac model, RAM, GPU)
- Test duration for both baseline and mitigation phases
- Memory measurements at 30-minute intervals
- Peak memory reached in each phase
- Percentage improvement calculation
- Any anomalies or unexpected behavior

**Report Format:**
```
SYSTEM: MacBook Pro 16" 2023, 32GB RAM, M2 Max
MACOS: 15.7.2 (24G325)
BASELINE PEAK: 12.4GB after 5 hours
MITIGATION PEAK: 2.1GB after 6 hours
IMPROVEMENT: 83% reduction in memory growth
SCENARIOS TESTED: A, B, C, D
CONCLUSION: Mitigation effective, system remained stable
```

## Continuous Monitoring

For long-term validation beyond initial testing:

1. Enable daily health checks via cron
2. Monitor `/var/log/windowserver_monitor.log` for patterns
3. Set memory threshold alerts in monitoring dashboard
4. Document any regression after macOS updates

## Version History

- v1.0 (2025-11-03): Initial testing methodology for v2.0.0 toolkit
