# Security Policy

## Overview

**WindowServer Fix** is an open-source toolkit designed to monitor and mitigate macOS WindowServer memory leaks. This document explains exactly what the toolkit does, what permissions it requires, and how it protects your privacy.

---

## What This Tool Does (and Doesn't Do)

### ✅ What It DOES

| Action | Purpose | Risk Level |
|--------|---------|-----------|
| **Monitor WindowServer memory/CPU** | Detect leaks using `ps`, `top`, and `pgrep` commands | 🟢 None - read-only |
| **Apply safe system preferences** | Modify user-level settings (transparency, Dock) | 🟢 None - reversible |
| **Restart Dock** | `killall Dock` (user process, auto-restarts) | 🟢 None - harmless |
| **Clear pasteboard** | `pbcopy < /dev/null` (clipboard cache) | 🟢 None - temporary |
| **Terminate iPhone Mirroring** | `pkill "iPhone Mirroring"` (app-level) | 🟢 None - user app |
| **Store logs locally** | Write to `~/windowserver-fix/logs/` | 🟢 None - your home directory |
| **Send macOS notifications** | Alert you when fixes applied | 🟢 None - system API |
| **Emergency WindowServer restart** | `sudo killall -HUP WindowServer` (optional) | 🟡 Low - requires password, logs you out |

### ❌ What It DOES NOT Do

| What We DON'T Do | Why This Matters |
|-----------------|------------------|
| ❌ **Modify system files** | No `/System/` or `/Library/` changes |
| ❌ **Require root by default** | Everything runs with user permissions |
| ❌ **Send data off your machine** | Zero network calls, zero telemetry |
| ❌ **Collect analytics** | No tracking, no usage stats |
| ❌ **Run hidden processes** | All scripts visible in Activity Monitor |
| ❌ **Install kernel extensions** | No low-level system access |
| ❌ **Modify other applications** | Only interacts with system processes |
| ❌ **Store sensitive information** | Logs contain only system stats |

---

## Open Source Transparency

### Auditable by Design

**Every line of code is reviewable:**

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/windowserver-fix.git
cd windowserver-fix

# Read any script
cat monitor.sh
cat daemon.sh
cat fix.sh
```

**No binaries, no compilation:** All scripts are plain bash, readable by humans.

### What Each Script Does

| Script | Purpose | System Changes |
|--------|---------|----------------|
| `monitor.sh` | Check WindowServer stats | None - read-only |
| `fix.sh` | Apply mitigation fixes | User preferences only (backed up) |
| `daemon.sh` | Background monitoring | None - calls fix.sh when needed |
| `dashboard.sh` | Real-time display | None - read-only |
| `install.sh` | Setup toolkit | Creates `~/windowserver-fix/` directory |
| `test_memory_accuracy.sh` | Validate reporting | None - read-only |

### Community Audit

We encourage security researchers to:
1. Review the source code
2. Report vulnerabilities responsibly
3. Suggest improvements via pull requests

---

## Permissions Explained

### What Permissions Are Required?

| Permission | Required? | Reason | How to Audit |
|-----------|----------|--------|-------------|
| **Read WindowServer process info** | ✅ Yes | Monitor memory/CPU | `ps aux \| grep WindowServer` |
| **Write to home directory** | ✅ Yes | Store logs and backups | `ls ~/windowserver-fix/logs/` |
| **Modify user preferences** | ✅ Yes | Apply fixes (transparency, Dock) | Check `~/Library/Preferences/` before/after |
| **Send notifications** | ✅ Yes | Alert when fixes applied | macOS system API |
| **Kill user processes** | ✅ Yes | Restart Dock, iPhone Mirroring | `killall Dock` (harmless, auto-restarts) |
| **Sudo/root access** | ⚠️ Optional | Emergency WindowServer restart only | Prompted only when you run `restart-windowserver` |

### When Does It Ask for Sudo?

**Only in one scenario:**

```bash
./fix.sh restart-windowserver
```

This command requires your password because it runs:
```bash
sudo killall -HUP WindowServer
```

**Effect:** Logs you out immediately (WindowServer restarts). Save work first!

**All other operations** run with standard user permissions.

---

## Privacy Guarantee

### Local-Only Operation

**Zero network activity:**
- No telemetry
- No analytics
- No crash reporting
- No "phone home" functionality
- No external API calls

**Verify yourself:**
```bash
# Monitor network activity while daemon runs
sudo lsof -i -P | grep daemon.sh
# Should return: (nothing)
```

### What's Stored Locally

All data stays in `~/windowserver-fix/`:

| File/Directory | Contents | Sensitive? |
|----------------|----------|-----------|
| `logs/*.log` | WindowServer stats (CPU, memory, timestamps) | No - system stats only |
| `logs/metrics.csv` | Historical data | No - numerical values |
| `backups/` | Preferences before changes | No - user settings |
| `.daemon.pid` | Daemon process ID | No - PID number |

**No personal information collected.** No browsing history, no passwords, no documents.

### Viewing Your Data

```bash
# See exactly what's logged
cat ~/windowserver-fix/logs/daemon_$(date +%Y%m%d).log

# Example entry:
# [2025-11-03 15:46:32] Status: CPU=38.6%, MEM=12288MB, Apps=0, iPhoneMirror=0
```

### Deleting Your Data

```bash
# Stop daemon
./daemon.sh stop

# Remove all logs
rm -rf ~/windowserver-fix/logs/

# Or uninstall completely
rm -rf ~/windowserver-fix/
```

---

## What Changes Are Made

### System Preferences Modified

When you run `./fix.sh`, these user preferences change:

| Setting | Command | Effect | Reversible? |
|---------|---------|--------|------------|
| Reduce Transparency | `defaults write com.apple.universalaccess reduceTransparency -bool true` | Disables translucent menus/windows | ✅ Yes - backed up |
| Disable Space Rearrangement | `defaults write com.apple.dock mru-spaces -bool false` | Spaces stay in order | ✅ Yes - backed up |
| Speed up Mission Control | `defaults write com.apple.dock expose-animation-duration -float 0.1` | Faster animations | ✅ Yes - backed up |
| Remove WindowServer prefs | `rm ~/Library/Preferences/ByHost/com.apple.windowserver.*` | Forces regeneration | ✅ Yes - backed up |

**All backed up to:** `~/windowserver-fix/backups/backup_TIMESTAMP/`

### Restore Original Settings

```bash
./fix.sh restore
```

Copies files from most recent backup to original locations.

---

## Security Best Practices

### How We Protect Users

1. **No sudo by default** - Everything runs with user permissions
2. **Explicit backups** - Settings saved before changes
3. **Detailed logging** - Full audit trail of all actions
4. **Cooldown periods** - Prevents fix spam (5 min standard, 1 hour emergency)
5. **Read-only monitoring** - Most operations just observe
6. **Open source** - No hidden code

### What You Should Do

1. **Review the code** before running (seriously!)
2. **Check logs** periodically: `~/windowserver-fix/logs/`
3. **Backup your Mac** before first use (Time Machine)
4. **Update regularly** - `git pull` for latest security fixes
5. **Report issues** - See "Reporting Security Issues" below

---

## Known Risks & Limitations

### Low-Risk Operations

| Operation | Risk | Mitigation |
|-----------|------|-----------|
| **Restart Dock** | Desktop icons disappear briefly | Auto-restarts in 1-2 seconds |
| **Clear pasteboard** | Clipboard contents lost | Don't run if clipboard important |
| **Modify transparency** | Visual appearance changes | Backed up, reversible |

### Medium-Risk Operations

| Operation | Risk | Mitigation |
|-----------|------|-----------|
| **Emergency WindowServer restart** | Logs you out, unsaved work lost | Only at >20GB threshold, password required |

### What Could Go Wrong?

**Theoretical worst-case scenarios:**

1. **Backup restoration fails**
   - **Likelihood:** Very low (backups tested)
   - **Impact:** Settings remain changed
   - **Recovery:** Manually restore from `backups/` directory

2. **WindowServer won't restart**
   - **Likelihood:** Extremely rare
   - **Impact:** Can't log back in
   - **Recovery:** Boot to Recovery Mode, restore backup

3. **Daemon causes high CPU**
   - **Likelihood:** Very low (<1% CPU measured)
   - **Impact:** Battery drain
   - **Recovery:** `./daemon.sh stop`

**We've tested extensively** and not encountered these issues. See [TEST_RESULTS.md](TEST_RESULTS.md).

---

## Reporting Security Issues

### Responsible Disclosure

**Found a vulnerability?** We appreciate responsible disclosure:

1. **Email:** chindris.mihai.alexandru@gmail.com
   - Subject: `[SECURITY] WindowServer Fix Vulnerability`
   - Include: Detailed description, reproduction steps, impact assessment

2. **Do NOT:**
   - Post publicly before we've had time to fix
   - Exploit the vulnerability maliciously

3. **Timeline:**
   - We'll acknowledge within **48 hours**
   - Provide a fix within **90 days** (sooner for critical issues)
   - Credit you in CHANGELOG.md (if desired)

### Security Hall of Fame

Contributors who responsibly disclose security issues:

*(No vulnerabilities reported yet - be the first!)*

---

## Threat Model

### What We Protect Against

| Threat | Protection |
|--------|-----------|
| **Malicious scripts** | All code open-source, reviewable |
| **Data exfiltration** | Zero network calls, local-only operation |
| **Privilege escalation** | No setuid binaries, minimal sudo use |
| **Data loss** | Automatic backups before changes |

### What We DON'T Protect Against

| Threat | Why Not in Scope |
|--------|------------------|
| **Physical access attacks** | Toolkit assumes trusted local user |
| **Kernel exploits** | No kernel-level code |
| **Other malware** | Not an antivirus tool |
| **Apple's own bugs** | Can only mitigate, not fix OS issues |

---

## Compliance

### Open Source License

**MIT License** - See [LICENSE](LICENSE) file

**Key points:**
- Free to use, modify, distribute
- No warranty provided
- Attribution required

### Privacy Laws

**This toolkit complies with:**
- GDPR (no personal data collected)
- CCPA (no data sales, no tracking)
- COPPA (no data from children)

**Reason:** We don't collect ANY user data, so privacy laws are satisfied by default.

---

## Technical Security Details

### How Daemon Runs

```bash
# Daemon process (visible in Activity Monitor)
/bin/bash /Users/YOU/windowserver-fix/daemon.sh start

# What it does every 60 seconds:
1. Run: top -l 1 -stats mem -pid $(pgrep WindowServer)
2. Parse memory value
3. Check if > threshold
4. If yes: Apply fixes (logged)
5. Sleep 60 seconds
6. Repeat
```

**No elevated privileges.** Runs as your user.

### Memory Reporting Method

```bash
# Get WindowServer memory (matches Activity Monitor)
ws_pid=$(pgrep WindowServer)
mem_str=$(top -l 1 -stats pid,command,mem -pid "$ws_pid" | grep WindowServer | awk '{print $3}')

# Result: "12G" or "500M" or "100K"
# Convert to MB for threshold comparison
```

**Why `top` and not `ps aux`?**
- `ps aux` shows RSS (physical RAM only) - underreports by 60x!
- `top` with `mem` stats matches Activity Monitor exactly
- See [technical writeup](README.md#technical-details)

### Files Created

```
~/windowserver-fix/
├── logs/
│   ├── daemon_20251103.log    # Daemon activity
│   ├── monitor_20251103.log   # Manual checks
│   ├── metrics.csv             # Historical data
│   └── memory_history.txt      # Last 100 readings
├── backups/
│   └── backup_20251103_150000/ # Settings before changes
└── .daemon.pid                 # Daemon process ID
```

**Permissions:** `chmod 644` (owner read/write, others read-only)

---

## Updates & Patching

### How to Update

```bash
cd ~/windowserver-fix
git pull origin main
```

**Check for updates:** Monthly, or when new macOS version releases.

### Security Patches

We commit to:
- Fix critical vulnerabilities within **7 days**
- Fix high-severity issues within **30 days**
- Fix medium/low issues within **90 days**

**Notification:** GitHub releases page + README changelog

---

## Questions?

### Security-Related Questions

Email: chindris.mihai.alexandru@gmail.com  
Subject: `[SECURITY] Your Question Here`

### General Support

- [Open an Issue](https://github.com/YOUR_USERNAME/windowserver-fix/issues)
- [Discussions](https://github.com/YOUR_USERNAME/windowserver-fix/discussions)

---

## Certification

**This security policy last updated:** November 3, 2025

**Reviewed by:**
- Project maintainers
- Community security researchers (pending)

**Next review:** February 2026 (every 3 months)

---

<div align="center">

**Your security is our priority. When in doubt, read the code.**

[View Source Code](https://github.com/YOUR_USERNAME/windowserver-fix) • [Report Security Issue](mailto:chindris.mihai.alexandru@gmail.com)

</div>
