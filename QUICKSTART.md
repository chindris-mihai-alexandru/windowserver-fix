# Quick Start Guide

## Installation

```bash
cd ~/windowserver-fix
./install.sh
```

## Basic Usage

### 1. Check Current Status

```bash
./fix.sh status
```

Output:
```
CPU Usage: 42.7%
Memory Usage: 242MB (0.7%)

Current Settings:
  Reduce Transparency: 1
  MRU Spaces: 0
  Connected Displays: 2
```

### 2. Apply Fixes

```bash
./fix.sh
```

This will:
- Backup your settings
- Apply all known fixes
- Show recommendations
- Ask if you want to restart WindowServer

### 3. Monitor WindowServer

Real-time dashboard (updates every 5 seconds):
```bash
./dashboard.sh
```

Single check:
```bash
./monitor.sh check
```

Continuous monitoring (every 30 seconds):
```bash
./monitor.sh monitor
```

### 4. Background Monitoring

Start automatic monitoring:
```bash
./daemon.sh start
```

Check status:
```bash
./daemon.sh status
```

Stop monitoring:
```bash
./daemon.sh stop
```

## Most Common Fixes

### High CPU Usage

```bash
# Apply all fixes
./fix.sh

# Then check display settings manually:
# System Settings > Displays > Use "Default" resolution
```

### High Memory Usage

```bash
# Clean cache
./fix.sh clean

# Clear pasteboard
pbcopy < /dev/null
```

### Crashes on Wake

```bash
# Reset display preferences
rm ~/Library/Preferences/ByHost/com.apple.windowserver.displays.*.plist

# Then logout and login
```

### Multiple Display Issues

1. Use default (non-scaled) resolution
2. Connect via USB-C directly (not hub)
3. Set as "Extended" display, not "Main"

## Restore Settings

If something goes wrong:

```bash
./fix.sh restore
```

## Get Help

1. Check logs:
   ```bash
   cat logs/windowserver_monitor_$(date +%Y%m%d).log
   ```

2. Run diagnostics:
   ```bash
   ./monitor.sh diagnostic
   ```

3. Read troubleshooting guide:
   ```bash
   cat TROUBLESHOOTING.md
   ```

## Daily Usage

### Best Practice

1. Start daemon on login:
   ```bash
   ./daemon.sh start
   ```

2. Check weekly metrics:
   ```bash
   cat logs/metrics.csv
   ```

3. Run dashboard when you notice issues:
   ```bash
   ./dashboard.sh
   ```

## Tips

- **Normal CPU Usage:** 5-25%
- **High CPU Usage:** 40-60%
- **Critical CPU Usage:** 60%+

- **Normal Memory:** 100-300MB
- **High Memory:** 300-500MB
- **Critical Memory:** 500MB+

## Keyboard Shortcuts

When dashboard is running:
- `Ctrl+C` - Stop dashboard
- `Cmd+Tab` - Switch to other apps (dashboard keeps running)

## Files & Directories

```
~/windowserver-fix/
├── fix.sh              # Main fix script
├── monitor.sh          # Monitoring script
├── daemon.sh           # Background daemon
├── dashboard.sh        # Real-time dashboard
├── install.sh          # Installation
├── logs/               # All logs
│   ├── metrics.csv     # Historical data
│   └── *.log          # Various logs
└── backups/           # Settings backups
```

## What Not to Do

- Don't run scripts with `sudo` (they'll ask when needed)
- Don't delete the backups directory
- Don't modify system files manually
- Don't disable SIP (not required!)

## Next Steps

1. Read [README.md](README.md) for full documentation
2. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if you have issues
3. Star the GitHub repo if this helps you!
4. Report your results to help others

---

**Need immediate help?**

```bash
./fix.sh help
./monitor.sh
./daemon.sh
```

All scripts show usage when run without arguments.
