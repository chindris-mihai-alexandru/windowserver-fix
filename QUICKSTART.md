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

### 4. Configure Settings (v2.1.0+)

Customize behavior before starting monitoring:
```bash
# View all available settings
cat config.sh

# Edit configuration (optional)
nano config.sh
```

**Key Settings:**
- `AUTO_FIX_ENABLED=true/false` - Enable/disable automatic fixes
- `DRY_RUN=true/false` - Test leak detection without applying fixes
- `CHECK_INTERVAL=300` - Check frequency in seconds
- `MEM_THRESHOLD_WARNING=2048` - Warning threshold in MB
- `GPU_MONITORING_ENABLED=true/false` - Track GPU VRAM usage

### 5. Background Monitoring

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

1. **Configure settings** (first time only):
   ```bash
   nano config.sh
   # Set AUTO_FIX_ENABLED=true for automatic fixes
   # Set DRY_RUN=false for production use
   ```

2. Start daemon on login:
   ```bash
   ./daemon.sh start
   ```

3. Check weekly metrics:
   ```bash
   cat logs/metrics.csv
   ```

4. Run dashboard when you notice issues:
   ```bash
   ./dashboard.sh
   ```

### Monitor-Only Mode (v2.1.0+)

Track metrics without applying fixes:
```bash
# Edit config.sh
AUTO_FIX_ENABLED=false

# Restart daemon
./daemon.sh restart
```

### Real-Time GPU Monitoring (v2.1.0+)

The dashboard now shows GPU metrics:
```bash
./dashboard.sh
```

Look for:
- **GPU VRAM**: Memory allocated on GPU
- **Page Tables**: Virtual memory overhead
- **Compositor**: Window buffer memory
- **Leak Patterns**: Recently detected patterns

## Tips

### Memory Thresholds (Traditional Measurement)
- **Normal Memory:** 100-300MB
- **High Memory:** 300-500MB
- **Critical Memory:** 500MB+

### Understanding VM vs RSS (v2.1.0+)
macOS reports two types of memory for processes:
- **VM (Virtual Memory)**: Total address space (shown by `top`)
- **RSS (Resident Set Size)**: Actual physical RAM used (shown by `ps`)

For WindowServer, VM can be 10-20x larger than RSS due to:
- **Page tables**: Metadata tracking virtual-to-physical mappings
- **Compositor buffers**: Offscreen window rendering buffers
- **GPU shared memory**: Memory-mapped GPU resources

**Normal Ratio**: VM is 2-5x RSS (e.g., 1GB VM, 200-500MB RSS)  
**Leak Detected**: VM is >10x RSS (e.g., 4GB VM, 200MB RSS = 2000% discrepancy)

This tool tracks both measurements and alerts when the discrepancy indicates a leak.

### CPU Thresholds
- **Normal CPU Usage:** 5-25%
- **High CPU Usage:** 40-60%
- **Critical CPU Usage:** 60%+

### GPU Memory (v2.1.0+)
- **Normal GPU VRAM:** 0-500MB (idle/basic usage)
- **High GPU VRAM:** 500-1024MB (active graphics)
- **Critical GPU VRAM:** 1024MB+ (leak suspected)

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
