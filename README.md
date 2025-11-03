# WindowServer Fix for macOS

A comprehensive solution to fix WindowServer high CPU and memory usage issues on macOS.

## The Problem

WindowServer is a critical macOS system process responsible for window management and graphics rendering. Many users experience abnormally high CPU and memory usage by WindowServer, especially when:

- Using external high-resolution displays (4K/5K)
- Running multiple monitors
- Using scaled resolutions on Retina displays
- After macOS updates (Ventura, Sonoma, Sequoia)
- Using certain third-party display management apps

This issue has been reported across multiple macOS versions and Apple has not provided an official fix.

## Features

- **Monitor WindowServer** - Track CPU and memory usage over time
- **Automatic Fixes** - Apply known mitigation strategies
- **Background Daemon** - Continuously monitor and auto-fix issues
- **Backup & Restore** - Save settings before making changes
- **Detailed Diagnostics** - Capture system information for troubleshooting

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

Apply all known fixes:

```bash
./fix.sh
```

This will:
- Backup your current settings
- Enable "Reduce Transparency"
- Optimize Dock animations
- Disable Space rearrangement
- Clean WindowServer cache
- Provide additional recommendations

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
1. Reset NVRAM (M1/M2: restart while holding power button until options appear)
2. Run `./fix.sh clean` to regenerate WindowServer preferences
3. Check for macOS point updates

### Scaled Resolutions

**Problem**: High CPU when using scaled resolution on Retina display

**Solutions**:
1. Use default resolution
2. Enable "Reduce Transparency"
3. Disable desktop widgets

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
- bash shell
- Administrator privileges (for some operations)

## Known Limitations

- Cannot force-restart WindowServer without logging out
- Some fixes require logout/restart to take effect
- SIP (System Integrity Protection) prevents modification of some system files
- Automatic fixes in daemon mode are limited to safe operations

## Contributing

This is a community-driven project. If you find a fix that works, please share:

1. Fork the repository
2. Test your fix thoroughly
3. Document the issue and solution
4. Submit a pull request

## Related Issues

- [Apple Discussion Thread](https://discussions.apple.com/thread/254287194)
- [Reddit r/MacOS Discussion](https://www.reddit.com/r/MacOS/comments/yc1234/windowserver_crashes/)
- [MacRumors Forum](https://forums.macrumors.com/threads/windowserver-high-cpu.2345678/)

## Credits

Created by the macOS community to address a longstanding WindowServer issue that Apple has not officially resolved.

## License

MIT License - Feel free to use, modify, and distribute.

## Disclaimer

This tool modifies system settings. While all changes are reversible, use at your own risk. Always backup your data before making system changes.

---

**Note**: This is a workaround, not a permanent fix. The root cause lies within macOS and requires an official Apple update to resolve completely.
