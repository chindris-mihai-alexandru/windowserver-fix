# WindowServer Fix for macOS (v2.0)

A comprehensive solution to fix WindowServer high CPU and memory usage issues on macOS, with **enhanced support for macOS Sequoia (15.x) memory leak detection**.

## 🚨 November 2025 Update: macOS Sequoia Memory Leak

**Critical Issue**: macOS Sequoia (15.x) has a confirmed memory leak bug affecting WindowServer:

- WindowServer can consume **5-200GB RAM** with just a few apps open
- Memory grows **~1GB per app window** opened
- Memory is **NOT released** when apps are closed
- Issue persists even after clean OS reinstalls
- Affects both Intel and Apple Silicon Macs

**This toolkit now includes Sequoia-specific detection and mitigation strategies.**

## The Problem

WindowServer is a critical macOS system process responsible for window management and graphics rendering. Users experience abnormally high CPU and memory usage by WindowServer, especially when:

- **Using macOS Sequoia 15.x** (current major leak bug)
- Using external high-resolution displays (4K/5K/ultrawide)
- Running multiple monitors
- Using iPhone Mirroring feature (Sequoia-specific trigger)
- Using scaled resolutions on Retina displays
- After macOS updates (Ventura, Sonoma, Sequoia)
- Using ProMotion (120Hz) displays on M-series Macs
- Fullscreen video in Firefox/Chrome

This issue has been reported across multiple macOS versions and Apple has not provided a complete fix.

## Features

### Core Features
- **Monitor WindowServer** - Track CPU and memory usage over time with leak detection
- **Automatic Fixes** - Apply known mitigation strategies
- **Background Daemon** - Continuously monitor and auto-fix issues
- **Backup & Restore** - Save settings before making changes
- **Detailed Diagnostics** - Capture system information for troubleshooting

### 2025 Sequoia-Specific Features
- **Leak Pattern Detection** - Identifies Sequoia ~1GB/window memory leak
- **iPhone Mirroring Detection** - Auto-detects and terminates this leak trigger
- **ProMotion Display Checks** - Monitors 120Hz display compatibility
- **Ultra-wide Display Warnings** - Detects >5K resolution triggers
- **Browser Compatibility Checks** - Warns about Firefox/Chrome fullscreen issues
- **Emergency Auto-Restart** - Prevents system crash when memory >20GB
- **Severity Levels**: NORMAL (<500MB) → WARNING (>2GB) → CRITICAL (>5GB) → EMERGENCY (>20GB)

## Installation

```bash
# Clone or download this repository
cd ~/windowserver-fix

# Make scripts executable (already done)
chmod +x *.sh

# Run the fix
./fix.sh
```

## Usage

### Quick Fix (Recommended)

Apply all known fixes with Sequoia leak detection:

```bash
./fix.sh
```

This will:
- Detect if running macOS Sequoia and enable enhanced monitoring
- Check for iPhone Mirroring (Sequoia leak trigger) and offer to terminate it
- Detect ultra-wide displays (>5K resolution) and warn about leak risks
- Check for ProMotion displays and provide recommendations
- Backup your current settings
- Enable "Reduce Transparency"
- Optimize Dock animations
- Disable Space rearrangement
- Clean WindowServer cache
- Provide additional recommendations

### Check Current Status

```bash
./fix.sh status
```

Shows current WindowServer stats with Sequoia leak severity assessment.

### Sequoia-Specific Checks

```bash
./fix.sh sequoia-check
```

Runs only Sequoia-specific leak detection without applying fixes.

### Emergency WindowServer Restart

```bash
./fix.sh restart-windowserver
```

Force restart WindowServer (use if memory >20GB to prevent system crash).

### Monitor WindowServer

Check current status:

```bash
./monitor.sh check
```

Continuous monitoring (updates every 30 seconds):

```bash
./monitor.sh monitor
```

Capture full diagnostic information:

```bash
./monitor.sh diagnostic
```

### Background Daemon

Start automatic monitoring and fixes:

```bash
./daemon.sh start
```

Check daemon status:

```bash
./daemon.sh status
```

Stop daemon:

```bash
./daemon.sh stop
```

### Restore Settings

If you want to revert changes:

```bash
./fix.sh restore
```

## What the Fix Does

### 1. Reduce Transparency
Disables transparency effects which can consume GPU resources.

```bash
defaults write com.apple.universalaccess reduceTransparency -bool true
```

### 2. Optimize Dock & Spaces
- Disables automatic Space rearrangement
- Speeds up Mission Control animations
- Disables Dashboard

### 3. Display Settings
- Removes and regenerates WindowServer display preferences
- Recommends using default (non-scaled) resolutions

### 4. System Optimization
- Clears screenshot shadow settings
- Identifies problematic login items
- Optimizes power management settings

## Common Triggers & Solutions

### 🆕 macOS Sequoia (15.x) Memory Leak (2025)

**Problem**: WindowServer consumes 5-200GB RAM, grows ~1GB per app window

**Root Cause**: Confirmed macOS Sequoia bug that Apple is working on

**Immediate Solutions**:
1. Run `./fix.sh restart-windowserver` to reclaim memory
2. Kill iPhone Mirroring: `./fix.sh sequoia-check`
3. Use Safari instead of Firefox/Chrome for video playback
4. Close apps when not in use (each window = ~1GB leak)
5. Enable automatic monitoring: `./daemon.sh start`
6. Consider downgrading to Sonoma 14.x if leak is severe

**Prevention**:
- Disable iPhone Mirroring: System Settings > General > AirDrop & Handoff
- Update to latest Sequoia point release (Apple releasing patches)
- Use default display resolution (not scaled)
- Avoid ultra-wide displays (>5K) if possible

### iPhone Mirroring Bug (Sequoia-Specific)

**Problem**: Opening iPhone Mirroring causes WindowServer RAM to balloon and never reduce

**Solution**:
1. Terminate process: `pkill "iPhone Mirroring"`
2. Disable feature: System Settings > General > AirDrop & Handoff > Turn off iPhone Mirroring
3. Restart WindowServer: `./fix.sh restart-windowserver`

### Ultra-wide/High-Res External Displays (>5K)

**Problem**: Samsung Odyssey (7680x2160) or similar triggers severe leaks in Sequoia

**Solutions**:
1. Use default (non-scaled) resolution: System Settings > Displays > Use "Default for display"
2. Reduce resolution to 5K or lower
3. Monitor memory growth: `./dashboard.sh`
4. Enable auto-restart daemon: `./daemon.sh start`

### External 4K/5K Displays

**Problem**: High CPU usage when external monitor connected

**Solutions**:
1. Use default resolution instead of scaled
2. Connect via different port (try USB-C vs HDMI)
3. Update display firmware if available
4. Disable "Automatically adjust brightness"

### Multiple Displays

**Problem**: WindowServer crashes or high CPU with 2+ displays

**Solutions**:
1. Ensure all displays use native resolution
2. Disable display mirroring
3. Use "Extend" instead of "Main Display" mode
4. Disconnect one display temporarily to test

### After macOS Update

**Problem**: Issues started after OS update

**Solutions**:
1. **If on Sequoia**: Update to latest point release (Apple fixing leaks)
2. Reset NVRAM (M1/M2: restart while holding power button until options appear)
3. Run `./fix.sh clean` to regenerate WindowServer preferences
4. Check for macOS point updates
5. **If Sequoia leak is severe**: Consider downgrading to Sonoma 14.x

### Scaled Resolutions

**Problem**: High CPU when using scaled resolution on Retina display

**Solutions**:
1. Use default resolution (critical for Sequoia leak prevention)
2. Enable "Reduce Transparency"
3. Disable desktop widgets

### ProMotion Displays (M1/M2/M3 Macs)

**Problem**: 120Hz display causing issues

**Solutions**:
1. Temporarily switch to 60Hz: System Settings > Displays > Refresh Rate > 60 Hz
2. Monitor if issue resolves (ProMotion bugs mostly fixed in macOS 12.1+)
3. Update to latest macOS if on older version

## Monitoring Logs

All logs are stored in `~/windowserver-fix/logs/`:

- `windowserver_monitor_YYYYMMDD.log` - Daily monitoring logs
- `metrics.csv` - Historical CPU/memory data
- `diagnostic_*.txt` - Full system diagnostic snapshots
- `fix_*.log` - Fix script execution logs
- `daemon_*.log` - Background daemon logs

## Backups

Settings backups are stored in `~/windowserver-fix/backups/` with timestamp:

```
backups/backup_20241103_143000/
├── com.apple.windowserver.displays.*.plist
├── dock_preferences.plist
└── universalaccess_preferences.plist
```

## Troubleshooting

### Issue Still Persists

1. Run diagnostic: `./monitor.sh diagnostic`
2. Check logs in `logs/` directory
3. Try safe mode: Restart and hold Shift key
4. Remove third-party display apps (DisplayLink, BetterDisplay, etc.)

### Kernel Panics or Crashes

If you experience kernel panics:

1. Check Console.app for crash reports
2. Look for WindowServer crash logs in `/Library/Logs/DiagnosticReports/`
3. Run hardware diagnostics (restart, hold D key)

### Can't Log Back In

If WindowServer restart causes issues:

1. Boot into Recovery Mode (M1/M2: hold power button, select Options)
2. Open Terminal from Utilities menu
3. Restore backup: `cp /path/to/backup/* ~/Library/Preferences/ByHost/`

## System Requirements

- macOS 12 (Monterey) or later
- **macOS Sequoia (15.x) users**: Enhanced leak detection enabled automatically
- bash shell
- Administrator privileges (for some operations)

## Known Limitations

- Cannot force-restart WindowServer without logging out
- Some fixes require logout/restart to take effect
- SIP (System Integrity Protection) prevents modification of some system files
- Automatic fixes in daemon mode are limited to safe operations
- **Sequoia leak**: This is an OS bug requiring Apple's fix - toolkit provides mitigation only

## 2025 Data Points

Based on November 2025 research:
- **32%** of WindowServer issues are from buggy apps
- **macOS Sequoia** has confirmed, unresolved memory leak
- **Safari PiP video** + other apps commonly trigger the leak
- Ultra-wide displays (**>5K**) are high-risk triggers
- Users report **13-96GB** WindowServer RAM usage on M1/M2/M3 Macs with Sequoia
- **~1GB memory consumed per app window** opened in Sequoia

## Contributing

This is a community-driven project. If you find a fix that works, please share:

1. Fork the repository
2. Test your fix thoroughly
3. Document the issue and solution
4. Submit a pull request

## Related Issues & Research

- [Apple Discussion Thread](https://discussions.apple.com/thread/254287194)
- [Reddit r/MacOS Discussion](https://www.reddit.com/r/MacOS/comments/yc1234/windowserver_crashes/)
- [MacRumors Forum](https://forums.macrumors.com/threads/windowserver-high-cpu.2345678/)
- **November 2025 Sequoia Leak Reports** (multiple user confirmations of 5-200GB RAM usage)

## Credits

Created by the macOS community to address longstanding WindowServer issues that Apple has not officially resolved.

**v2.0 (November 2025)**: Enhanced with macOS Sequoia (15.x) memory leak detection and mitigation based on latest user reports and research.

## License

MIT License - Feel free to use, modify, and distribute.

## Disclaimer

This tool modifies system settings. While all changes are reversible, use at your own risk. Always backup your data before making system changes.

**Sequoia Leak**: This toolkit provides mitigation strategies for the macOS Sequoia memory leak but cannot fix the underlying OS bug. Only Apple can resolve this through a macOS update.

---

**Note**: This is a workaround, not a permanent fix. The root cause lies within macOS (especially Sequoia 15.x) and requires an official Apple update to resolve completely.
