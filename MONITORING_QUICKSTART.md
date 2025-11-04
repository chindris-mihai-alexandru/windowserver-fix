# WindowServer Monitoring - Quick Start Guide

## Your Current Status

**Baseline:** 6167 MB (before mitigation)  
**Now:** 6120 MB (after mitigation)  
**Change:** -47 MB (-0.8%)

You have an active Sequoia leak. The toolkit applied mitigations successfully. Now monitor if memory stays stable or continues climbing.

---

## Quick Check (Run Every 30-60 Minutes)

```bash
cd /Users/mihai/windowserver-fix && ./monitor.sh
```

Look for the line: `Memory Usage: XXXX MB`

---

## Simple Tracking

Create a tracking file and append each check:

```bash
echo "$(date '+%H:%M') - $(cd /Users/mihai/windowserver-fix && ./monitor.sh 2>/dev/null | grep 'Memory Usage' | awk '{print $3}')" >> ~/ws_track.txt
```

View your tracking:
```bash
cat ~/ws_track.txt
```

---

## What You're Looking For

### Good News (Mitigation Working)
- Memory stays 6000-6500 MB
- Growth <50 MB/hour
- System feels responsive

### Okay News (Leak Slowed)
- Memory grows 50-100 MB/hour  
- Stays below 8000 MB
- Better than nothing

### Bad News (Mitigation Failed)
- Memory climbs >100 MB/hour
- Exceeds 8000 MB quickly
- System gets sluggish

---

## When Memory Hits 7000 MB

Run fixes again:
```bash
cd /Users/mihai/windowserver-fix && ./fix.sh
```

## When Memory Hits 10000 MB

Consider restarting WindowServer (closes all windows):
```bash
cd /Users/mihai/windowserver-fix && ./fix.sh restart-windowserver
```

---

## Automatic Monitoring (Set and Forget)

Start daemon to auto-fix:
```bash
cd /Users/mihai/windowserver-fix && ./daemon.sh start
```

Stop daemon:
```bash
cd /Users/mihai/windowserver-fix && ./daemon.sh stop
```

The daemon checks every 60 seconds and applies fixes automatically when needed.

---

## Report Back When You Have

1. 3-4 measurements over 2-3 hours, OR
2. Memory hits 8000 MB, OR  
3. System becomes noticeably slow

Provide the tracking data and I'll analyze effectiveness.

---

## Files Reference

- **Full test results:** `/Users/mihai/windowserver-fix/TEST_RESULTS.md`
- **Test log:** `/Users/mihai/windowserver-fix/logs/test_validation_20251103.log`
- **Daemon logs:** `/Users/mihai/windowserver-fix/logs/daemon_20251103.log`

---

**Quick Answer to "Is It Working?"**

Check in 1-2 hours. If memory is still around 6000-6500 MB → YES, it's working.
