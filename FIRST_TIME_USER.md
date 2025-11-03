# First Time Using WindowServer Fix?

**Welcome!** This guide walks you through everything you need to know to get started.

---

## Step 1: I Just Cloned the Repo, What Now?

### Quick Setup (2 minutes)

```bash
# Navigate to the cloned directory
cd windowserver-fix

# Make all scripts executable
chmod +x *.sh

# Check if you have the leak
./monitor.sh check
```

**That's it!** The check will tell you if WindowServer is using excessive memory.

---

## Step 2: How Do I Know If I Have the Leak?

### Memory Usage Guidelines

| Memory Level | Status | What It Means |
|-------------|--------|---------------|
| **<500 MB** | **NORMAL** | All good! No action needed |
| **500MB - 2GB** | **ELEVATED** | Monitor, but typically normal for multi-display setups |
| **2GB - 5GB** | **CONCERNING** | Likely a leak - consider running fixes |
| **5GB - 20GB** | **CRITICAL** | Definite leak - run fixes immediately |
| **>20GB** | **EMERGENCY** | System crash imminent - restart WindowServer |

### Context Matters

**Normal scenarios where high memory is OK:**
- Dual 5K displays: 1-3GB is typical
- Ultra-wide (>5K resolution): 2-5GB can be normal
- ProMotion (120Hz) displays: Higher baseline usage
- Video editing with multiple 4K previews: 3-8GB normal

**Sequoia leak indicators:**
- Memory >2GB with just a few apps open
- Memory grows rapidly (>500MB in 5 minutes)
- Memory never decreases when closing apps
- System becomes sluggish despite closing everything

### Run the Leak Check

```bash
./fix.sh sequoia-check
```

**Example output if you have the leak:**
```
LEAK_PATTERN_1: High memory usage with minimal apps (12288MB with estimated 8 windows)
TRIGGER_DETECTED: ULTRAWIDE_DETECTED - Ultra-wide/high-res display connected
CRITICAL: Memory at 12288MB exceeds critical threshold (>5GB)

VERDICT: SEQUOIA LEAK CONFIRMED
```

---

## Step 3: What Should I Do If Leak Is Detected?

### Option A: Install the Automatic Daemon (Recommended)

**Best for:** Peace of mind, hands-off monitoring

```bash
./install.sh
```

The installer will:
1. Set up the background daemon
2. Create a LaunchAgent (optional) to start on login
3. Configure automatic fixes when leaks detected
4. Show you where logs are stored

**After installation:**
```bash
# Start the daemon
./daemon.sh start

# Check it's running
./daemon.sh status

# View live logs
tail -f ~/windowserver-fix/logs/daemon_$(date +%Y%m%d).log
```

The daemon will now:
- Monitor WindowServer every 60 seconds
- Auto-apply fixes at WARNING/CRITICAL levels
- Send macOS notifications when actions taken
- Log everything for transparency

### Option B: Manual Fix (Quick One-Time Solution)

**Best for:** Testing, one-time issues, manual control

```bash
# Run all safe fixes
./fix.sh

# This will:
# 1. Terminate iPhone Mirroring (if active)
# 2. Clear pasteboard cache
# 3. Restart Dock
# 4. Log all actions
```

**Check what it would do first:**
```bash
./fix.sh status
```

### Option C: Emergency Restart (Last Resort)

**Use only when:** Memory >20GB and system about to crash

```bash
./fix.sh restart-windowserver
```

**WARNING:** This logs you out! Save all work first.

---

## Step 4: When Should I Restart WindowServer?

### Decision Matrix

| Memory Level | Action | Why |
|-------------|--------|-----|
| **<5GB** | Nothing | Normal operation |
| **5GB - 10GB** | Run `./fix.sh` | Try safe fixes first |
| **10GB - 20GB** | Run `./fix.sh`, monitor closely | Fixes may help, restart if growing |
| **>20GB** | **Restart WindowServer** | System crash imminent |

### How to Restart Safely

```bash
# 1. Save all work in all applications
# 2. Close unnecessary apps
# 3. Run the restart command
./fix.sh restart-windowserver

# You'll be logged out and back to login screen
# All unsaved work will be lost!
```

### After Restart

```bash
# Check memory is back to normal
./monitor.sh check

# Should see <500MB if successful
# If still high, may indicate hardware/display issue
```

---

## Step 5: Understanding Your Options

### Monitoring Options

| Command | When to Use | What It Does |
|---------|------------|--------------|
| `./monitor.sh check` | Quick status check | One-time memory/CPU snapshot |
| `./daemon.sh start` | Continuous monitoring | Background process, auto-fixes |
| `./dashboard.sh` | Interactive monitoring | Live updating terminal dashboard |

### Fix Options

| Command | Severity | What It Does |
|---------|----------|--------------|
| `./fix.sh status` | Info only | Shows what would be fixed |
| `./fix.sh` | Safe | Applies all non-destructive fixes |
| `./fix.sh sequoia-check` | Diagnostic | Checks for Sequoia leak patterns |
| `./fix.sh restart-windowserver` | Nuclear | Restarts WindowServer (logs you out) |

### Daemon Options

| Command | Purpose |
|---------|---------|
| `./daemon.sh start` | Start background monitoring |
| `./daemon.sh stop` | Stop background monitoring |
| `./daemon.sh restart` | Restart the daemon |
| `./daemon.sh status` | Check if daemon is running |

---

## Step 6: Customizing Thresholds

If you have a high-end setup (dual 5K displays, etc.) and getting false positives:

### Edit Daemon Thresholds

```bash
# Open daemon.sh
nano daemon.sh

# Find these lines (around line 20-30):
MEM_THRESHOLD_WARNING=2048    # 2GB
MEM_THRESHOLD_CRITICAL=5120   # 5GB
MEM_THRESHOLD_EMERGENCY=20480 # 20GB

# Change to your needs, for example:
MEM_THRESHOLD_WARNING=5120    # 5GB
MEM_THRESHOLD_CRITICAL=10240  # 10GB
MEM_THRESHOLD_EMERGENCY=25600 # 25GB

# Save and restart daemon
./daemon.sh restart
```

---

## Step 7: Where Are My Logs?

All logs are stored in: `~/windowserver-fix/logs/`

### Log Files

| File | Contents |
|------|----------|
| `daemon_YYYYMMDD.log` | Background daemon activity |
| `windowserver_monitor_YYYYMMDD.log` | Manual check results |
| `fix_YYYYMMDD_HHMMSS.log` | Fix execution details |
| `metrics.csv` | Historical CPU/memory data |
| `memory_history.txt` | Last 100 memory readings |

### Viewing Logs

```bash
# Watch daemon in real-time
tail -f ~/windowserver-fix/logs/daemon_$(date +%Y%m%d).log

# View all today's checks
cat ~/windowserver-fix/logs/windowserver_monitor_$(date +%Y%m%d).log

# View metrics over time
cat ~/windowserver-fix/logs/metrics.csv

# Get last 100 memory readings
cat ~/windowserver-fix/logs/memory_history.txt
```

---

## Common Questions

### Q: Is this safe?
**A:** Yes! All fixes are:
- Non-destructive (no system file changes)
- Reversible (backed up before applying)
- Transparent (full logging)
- Open source (inspect every line)

### Q: Will this permanently fix the leak?
**A:** No. This is an OS-level bug only Apple can fix. This tool provides:
- Detection when leak occurs
- Automatic mitigation to delay crashes
- Emergency restart before system failure
- Cannot prevent the leak from happening

### Q: Does this slow down my Mac?
**A:** No. The daemon uses:
- <1% CPU average
- ~5 MB RAM
- Minimal disk I/O (logs every 60s)

### Q: What if I want to uninstall?
**A:** Easy removal:
```bash
./daemon.sh stop
./uninstall.sh
```

Or manual cleanup:
```bash
./daemon.sh stop
./fix.sh restore  # Revert changes
rm -rf ~/windowserver-fix
```

### Q: My WindowServer shows 12GB but Activity Monitor says it's normal?
**A:** For dual 5K displays or ultra-wide setups, this CAN be normal. The toolkit shows the same values as Activity Monitor. If you're not experiencing:
- System slowdowns
- App crashes
- Rapid memory growth
- Excessive swap usage

Then it might just be your display configuration. Monitor for growth over time - that's the real leak indicator.

---

## Getting Help

### Still Stuck?

1. **Check Troubleshooting Guide:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. **Review Test Results:** See [TEST_RESULTS.md](TEST_RESULTS.md) for validation
3. **Check Security Info:** See [SECURITY.md](SECURITY.md) for what the tool does/doesn't do
4. **Open an Issue:** [GitHub Issues](https://github.com/chindri-mihai-alexandru/windowserver-fix/issues)

### When Opening an Issue, Include:

- macOS version: `sw_vers`
- Mac model: "About This Mac" → Overview
- What you tried: Commands you ran
- What happened: Copy/paste terminal output
- Log excerpts: Relevant lines from `~/windowserver-fix/logs/`

---

## Quick Start Checklist

Use this checklist for your first time:

- [ ] Clone repository
- [ ] Run `chmod +x *.sh`
- [ ] Run `./monitor.sh check` to see current status
- [ ] If memory >5GB, run `./fix.sh sequoia-check` to confirm leak
- [ ] If leak confirmed, run `./install.sh`
- [ ] Start daemon: `./daemon.sh start`
- [ ] Verify daemon running: `./daemon.sh status`
- [ ] Check logs: `tail -f ~/windowserver-fix/logs/daemon_$(date +%Y%m%d).log`
- [ ] Bookmark this file for future reference!

---

## You're All Set!

The daemon is now monitoring 24/7. It will:
- Check WindowServer every 60 seconds
- Auto-apply fixes at WARNING/CRITICAL levels
- Send notifications when actions taken
- Prevent crashes with emergency restart at >20GB

**Relax and let the tool handle it.** Check logs occasionally to see what it's doing.

---

**Need more details?** See the [main README](README.md) for comprehensive documentation.
