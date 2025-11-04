# Daemon Setup & Restart Configuration Guide

## Your Questions Answered

### Q1: Is the daemon a LaunchAgent that runs at boot?

**Current Status:** NO - The daemon is NOT installed as a LaunchAgent yet.

**What You Have Now:**
- Manual daemon script (`daemon.sh`) that runs when you start it
- You run `./daemon.sh start` and it monitors in background
- It stops when you reboot (does not auto-start)

**What the Install Script Can Do:**
The `install.sh` script CAN create a LaunchAgent to auto-start the daemon at boot, but it's NOT currently installed on your system.

**Verification:**
```bash
# Checked for LaunchDaemons (system-level):
ls /Library/LaunchDaemons/com.windowserver.*
# Result: NOT FOUND

# Checked for LaunchAgents (user-level):
ls ~/Library/LaunchAgents/com.windowserver.*
# Result: NOT FOUND
```

### Should You Create a LaunchAgent?

**Recommendation: YES** - Here's why:

**Pros of Installing as LaunchAgent:**
- Automatic monitoring starts at boot (no manual start needed)
- Continuous protection against memory leaks
- Applies fixes automatically when you're away from keyboard
- Daemon survives reboots

**Cons:**
- Uses minimal resources (1% CPU, 5MB RAM)
- Runs continuously in background
- May apply fixes (Dock restart) without your direct action

**To Install LaunchAgent:**
```bash
cd /Users/mihai/windowserver-fix && ./install.sh
```

This will:
1. Copy toolkit to `~/windowserver-fix` (already there)
2. Create `~/Library/LaunchAgents/com.windowserver-fix.daemon.plist`
3. Auto-start daemon at every boot
4. Start daemon immediately

**To Uninstall LaunchAgent Later:**
```bash
cd /Users/mihai/windowserver-fix && ./uninstall.sh
```

---

## Q2: Should You Restart Your Mac Now?

**Answer: NOT NECESSARY** - Here's why:

**Current Situation:**
- Mitigations already applied via `fix.sh`
- Memory reduced from 6167MB → 6120MB
- Compressed memory reduced 20.6%
- System stable

**Restarting WOULD:**
- ✅ Reset WindowServer memory to ~200-500MB baseline
- ✅ Clear all accumulated memory leaks temporarily
- ✅ Give you a "fresh start" to test leak progression
- ❌ Interrupt your current workflow
- ❌ Require re-opening all apps

**Restarting is OPTIONAL for testing purposes:**
If you want to scientifically measure how fast the leak develops from a clean state, restart now. Otherwise, continue monitoring current state.

---

## Q3: How to Restart Without Reopening Windows

### Method 1: Uncheck Dialog Box (One-Time)

When you restart via Apple menu:

1. Click Apple Menu () → Restart
2. Dialog appears with checkbox: **"Reopen windows when logging back in"**
3. **UNCHECK** this box
4. Click "Restart"

Result: Clean restart with no windows reopening.

### Method 2: Change System Default (Permanent)

To ALWAYS restart without reopening windows:

```bash
# Disable window reopen on restart (PERMANENT SETTING)
defaults write com.apple.loginwindow TALLogoutSavesState -bool false
```

**Your Current Setting:**
```
TALLogoutSavesState = 0 (false)
```

**Good news:** Window reopen is ALREADY DISABLED on your system! Every restart will be clean.

### Method 3: System Settings GUI (Alternative)

macOS doesn't have a GUI toggle for this anymore (removed in recent versions). The command above is the only way to permanently disable it.

### Method 4: Keyboard Shortcut Restart (Advanced)

For instant restart without dialog:
1. Press **Control + Command + Power Button** (or Eject)
2. This forces immediate restart
3. No checkbox dialog (may lose unsaved work)

**Warning:** Only use this if you've saved everything.

---

## Recommended Workflow

### Option A: Continue Current State (Recommended)

1. **Don't restart** - continue monitoring from 6120MB
2. Install LaunchAgent for automatic monitoring:
   ```bash
   cd /Users/mihai/windowserver-fix && ./install.sh
   ```
3. Monitor memory every 30-60 minutes using:
   ```bash
   cd /Users/mihai/windowserver-fix && ./monitor.sh
   ```
4. Come back with trend data in 2-3 hours

**Why:** You already have an active leak to test against. Monitoring from this state shows real-world effectiveness.

### Option B: Clean Baseline Test (Scientific)

1. **Restart Mac** (windows won't reopen - already disabled)
   - Apple Menu → Restart
   - Uncheck "Reopen windows" if dialog appears
2. **After restart**, install LaunchAgent:
   ```bash
   cd /Users/mihai/windowserver-fix && ./install.sh
   ```
3. **Measure baseline** WindowServer memory (~200-500MB expected)
4. **Use your Mac normally** (reconnect displays, open apps)
5. **Watch leak develop** over 2-4 hours
6. **Document progression** from clean state

**Why:** Gives you scientific before/after data showing leak development rate with and without mitigation.

### Option C: Just Install LaunchAgent, No Restart

1. Install LaunchAgent:
   ```bash
   cd /Users/mihai/windowserver-fix && ./install.sh
   ```
2. Daemon starts automatically
3. Continue using Mac normally
4. Let daemon apply fixes automatically when needed
5. Only restart if memory exceeds 10GB

**Why:** Simplest option. Set and forget. Daemon handles everything automatically.

---

## Testing Each Option

### If You Choose Option A (No Restart, Continue Monitoring)

**Commands:**
```bash
# Install LaunchAgent
cd /Users/mihai/windowserver-fix && ./install.sh

# Verify daemon is running
./daemon.sh status

# Check current memory
./monitor.sh

# Track over time (run every 30-60 min)
echo "$(date '+%H:%M') - $(./monitor.sh 2>/dev/null | grep 'Memory Usage' | awk '{print $3}')" >> ~/ws_track.txt
```

**Expected Result:**
- Memory stays around 6000-6500MB (success)
- Memory grows slowly <100MB/hour (partial success)
- Daemon applies fixes automatically when thresholds breach

### If You Choose Option B (Restart + Clean Baseline)

**Steps:**
1. Close all apps and save work
2. Apple Menu → Restart (uncheck window reopen if shown)
3. After login, run:
   ```bash
   cd /Users/mihai/windowserver-fix
   ./install.sh
   ./monitor.sh  # Should show ~200-500MB baseline
   ```
4. Reconnect 5K display, open normal apps
5. Monitor every 30 minutes:
   ```bash
   echo "$(date '+%H:%M') - $(./monitor.sh 2>/dev/null | grep 'Memory Usage' | awk '{print $3}')" >> ~/ws_track.txt
   ```

**Expected Result:**
- Baseline: 200-500MB WindowServer
- After reconnecting 5K display: Gradual climb to 3000-6000MB over 2-4 hours
- Daemon detects and applies fixes at 5000MB threshold
- Memory stabilizes after fixes

### If You Choose Option C (Just Install LaunchAgent)

**Command:**
```bash
cd /Users/mihai/windowserver-fix && ./install.sh
```

**That's it.** Daemon runs automatically. Check logs periodically:
```bash
tail -20 ~/windowserver-fix/logs/daemon_$(date +%Y%m%d).log
```

---

## Summary

### Your System Status

| Setting | Current State | Notes |
|---------|---------------|-------|
| LaunchAgent Installed | ❌ NO | Manual start only |
| Window Reopen on Restart | ✅ DISABLED | Clean restarts |
| Daemon Currently Running | ❌ NO | Stopped after last test |
| WindowServer Memory | 6120 MB | CRITICAL level |
| Mitigation Applied | ✅ YES | Via fix.sh |

### My Recommendation

**Install LaunchAgent now, restart later if needed:**

```bash
# 1. Install LaunchAgent for automatic monitoring
cd /Users/mihai/windowserver-fix && ./install.sh

# 2. Verify it's running
./daemon.sh status

# 3. Monitor memory periodically
./monitor.sh
```

**Restart only if:**
- You want clean baseline for scientific testing
- Memory exceeds 10GB and becomes problematic
- System feels sluggish

Your window reopen setting is already disabled, so any restart will be clean.

---

## Quick Reference Commands

```bash
# Check if LaunchAgent is installed
ls -la ~/Library/LaunchAgents/com.windowserver-fix.daemon.plist

# Install LaunchAgent (auto-start at boot)
cd /Users/mihai/windowserver-fix && ./install.sh

# Uninstall LaunchAgent
cd /Users/mihai/windowserver-fix && ./uninstall.sh

# Check daemon status
cd /Users/mihai/windowserver-fix && ./daemon.sh status

# Check current WindowServer memory
cd /Users/mihai/windowserver-fix && ./monitor.sh

# Disable window reopen permanently (ALREADY DISABLED)
defaults write com.apple.loginwindow TALLogoutSavesState -bool false

# Check window reopen setting
defaults read com.apple.loginwindow TALLogoutSavesState
# 0 = disabled, 1 = enabled
```

---

**Bottom Line:**

1. **LaunchAgent:** Install it for automatic protection
2. **Restart:** Not necessary now, but window reopen is already disabled for when you do
3. **Next Step:** Install LaunchAgent and let it run automatically

Want me to help you install the LaunchAgent now?
