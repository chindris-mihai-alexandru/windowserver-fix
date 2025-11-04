# Post-Restart Scientific Measurement Plan
**Created:** November 3, 2025
**Status:** Ready for restart

## Current State Summary
- **WindowServer Memory:** 6184MB (CRITICAL)
- **Compressed Memory:** 3047MB
- **System:** macOS Sequoia 15.7.2
- **Hardware:** Ultra-wide 5K display (3456 x 2234) - Known leak trigger
- **Mitigations Applied:** Yes (via fix.sh)
- **LaunchAgent Status:** Created, will auto-start on restart

## FIRST STEPS AFTER RESTART

### Immediate Actions (Do these right after login):

1. **Wait 60 seconds** for LaunchAgent to auto-start daemon
2. **Verify daemon is running:**
   ```bash
   cd ~/windowserver-fix
   ./daemon.sh status
   ```
3. **Take baseline measurement:**
   ```bash
   ./monitor.sh check
   ```
4. **Record baseline in TEST_RESULTS.md** (expect 200-500MB)
5. **Begin Phase 1 testing** (see below)

### Quick Commands:
```bash
cd ~/windowserver-fix
./daemon.sh status              # Verify daemon is running
./monitor.sh check              # Check WindowServer memory
tail -f logs/daemon.log         # Monitor daemon activity
./dashboard.sh                  # View interactive dashboard
```

---

## Research Findings (November 2025)

### Confirmed Leak Triggers on Sequoia 15.7.x:
1. **Ultra-wide displays (>5K)** - HIGHEST RISK (you have this)
2. **iPhone Mirroring** - MAJOR trigger (you don't use this)
3. **Multiple external displays** - HIGH RISK (you have 2 displays)
4. **Browser fullscreen video** (Firefox/Chrome) - MEDIUM RISK
5. **CursorUIViewService** leak - Still present in 15.7.2
6. **Safari 26.0.1** - Reported 400GB leaks in some cases

### Community Status:
- WindowServer leaks **NOT FIXED** in macOS 15.7.2 (Nov 2025)
- Users reporting 6GB-42GB leaks with external displays
- Leak develops over hours/days even after restart
- Apple aware but no ETA on fix (as of Nov 2025)

## Post-Restart Plan

### Phase 1: Clean Baseline (0-2 hours after restart)
**Expected Memory:** 200-500MB

**Actions:**
1. Log in normally - LaunchAgent will auto-start daemon
2. Verify daemon is running: `cd ~/windowserver-fix && ./daemon.sh status`
3. Take baseline measurement: `./monitor.sh check`
4. Record baseline in tracking table (TEST_RESULTS.md)
5. Continue normal usage

**Monitoring:**
- Check every 30-60 minutes
- Watch for leak development pattern
- Note which apps/activities trigger growth

### Phase 2: Leak Development (2-24 hours)
**Expected Memory:** 500MB → 2048MB (WARNING threshold)

**What to Watch For:**
- Memory growth rate (MB/hour)
- Activities that accelerate leak (video, screen sharing, etc.)
- Daemon detection and notification
- Effectiveness of automatic mitigations

**Actions:**
- Log activities when memory spikes
- Test daemon auto-detection (should trigger at 2GB warning)
- Let automation handle fixes - observe results
- Document in TEST_RESULTS.md tracking table

### Phase 3: Critical Threshold Testing (24+ hours)
**Expected Memory:** 2048MB → 5120MB (CRITICAL threshold)

**Daemon Will:**
- Auto-detect leak at 5GB
- Apply fixes automatically:
  - Kill iPhone Mirroring (if active)
  - Clear pasteboard
  - Restart Dock
  - Log top memory apps
  - Send notification
- Cool down for 5 minutes before next action

**Your Role:**
- Observe automation effectiveness
- Note if memory stabilizes after fixes
- Document any issues with automation
- Continue normal usage

### Phase 4: Long-term Monitoring (1 week+)
**Goal:** Determine if automation keeps system stable

**Success Criteria:**
- Memory stays below 10GB with active mitigation
- Daemon successfully detects and applies fixes
- No manual intervention needed
- System remains usable

## Measurement Tracking

### Key Metrics to Record:
1. **Baseline:** WindowServer memory immediately after restart
2. **Growth Rate:** MB gained per hour of usage
3. **Peak Memory:** Maximum before daemon intervention
4. **Post-Fix Memory:** Memory after automatic fixes
5. **Time to Critical:** Hours from restart to 5GB threshold
6. **Compressed Memory:** Track alongside WindowServer memory

### Use Tracking Table in TEST_RESULTS.md:
```
| Time | WS Memory | Compressed | Apps Open | Activity | Notes |
```

## Automation Improvements Identified

### High Priority Enhancements:

#### 1. Add Compressed Memory Monitoring
**Current:** Daemon only tracks WindowServer memory
**Issue:** Compressed memory buildup also indicates leak
**Fix:** Add compressed memory check to daemon.sh:line 146

#### 2. Improve Memory Calculation Accuracy
**Current:** Works well (using `top` command)
**Status:** ✓ Already accurate

#### 3. Add Leak Rate Detection
**Current:** Only checks absolute thresholds
**Enhancement:** Track MB/hour growth rate
**Benefit:** Detect slow leaks earlier

#### 4. LaunchAgent Bootstrap Fix
**Current:** LaunchAgent load had I/O errors
**Issue:** May not auto-start reliably
**Fix:** Use `launchctl bootstrap` instead of `load`

#### 5. Add Display Configuration Monitoring
**Current:** Checks for ultra-wide displays in fix.sh
**Enhancement:** Daemon should warn if display config changes
**Benefit:** Detect when new leak trigger added

### Medium Priority Enhancements:

#### 6. Smart Cooldown Adjustment
**Current:** Fixed 5-minute cooldown
**Enhancement:** Adjust based on leak severity
- Slow leak (< 100MB/hour): 10 min cooldown
- Fast leak (> 500MB/hour): 3 min cooldown

#### 7. Historical Pattern Analysis
**Current:** app_patterns.sh analyzes leak events
**Enhancement:** Daemon should learn which apps cause leaks
**Benefit:** Proactive warnings when risky apps launch

#### 8. Notification Improvements
**Current:** Generic notifications
**Enhancement:** Include specific culprit apps in notification
**Example:** "Chrome (200 tabs) detected - known leak trigger"

### Low Priority Enhancements:

#### 9. Web Dashboard
**Current:** Terminal-based monitoring
**Enhancement:** Optional web interface for monitoring
**Benefit:** Easier to check from other devices

#### 10. Metric Export
**Current:** Logs stored locally
**Enhancement:** Export to CSV/JSON for analysis
**Benefit:** Track patterns over weeks/months

## Implementation Priority

### Implement First (Before/During Testing):
1. **LaunchAgent bootstrap fix** - Critical for auto-start
2. **Compressed memory monitoring** - Important metric
3. **Leak rate detection** - Better early warning

### Implement After Initial Testing (Based on Results):
4. Display configuration monitoring
5. Smart cooldown adjustment
6. Notification improvements

### Implement Later (Nice-to-have):
7. Historical pattern analysis integration
8. Web dashboard
9. Metric export

## Testing Protocol

### Daily Check Routine:
```bash
cd ~/windowserver-fix

# Quick status
./monitor.sh check

# Full diagnosis (if memory > 2GB)
./diagnose.sh

# View daemon activity
./daemon.sh status

# Update tracking table
# (manually add row to TEST_RESULTS.md)
```

### Weekly Analysis:
```bash
# Analyze leak patterns
./app_patterns.sh

# Review logs
tail -100 logs/daemon_$(date +%Y%m%d).log

# Check memory history
cat logs/memory_history.txt | tail -50
```

## Restart Instructions

### When Ready to Restart:

1. **Save all work** - Restart closes everything
2. **Commit documentation** (if using git)
3. **Restart Mac:** Apple menu → Restart
4. **After login:**
   ```bash
   cd ~/windowserver-fix
   ./daemon.sh status  # Verify auto-start
   ./monitor.sh check  # Record baseline
   ```
5. **Update TEST_RESULTS.md** with new baseline

### First Measurements to Take:
1. Immediately after login: Baseline memory
2. After 1 hour: First growth check
3. After 4 hours: Growth rate calculation
4. After 8 hours: Daemon effectiveness check
5. After 24 hours: Full analysis

## Expected Outcomes

### Best Case:
- Baseline: 200-500MB
- Daemon detects leak at 5GB
- Fixes reduce memory 500-1000MB
- System stable below 6GB indefinitely

### Realistic Case:
- Baseline: 200-500MB
- Leak develops over 12-24 hours to 5GB
- Daemon applies fixes, memory drops to 4-4.5GB
- Leak continues slowly, requires restart every 3-5 days

### Worst Case:
- Baseline: 200-500MB
- Rapid leak (> 500MB/hour)
- Daemon fixes provide temporary relief only
- Requires daily restarts or display disconnection

## Next Session Goals

After restart and initial baseline measurements:

1. **Implement Priority Fixes:**
   - LaunchAgent bootstrap correction
   - Compressed memory monitoring
   - Leak rate detection

2. **Collect Data:**
   - Populate tracking table with hourly measurements
   - Document automation effectiveness
   - Note any manual interventions needed

3. **Analyze Patterns:**
   - Which activities trigger rapid growth?
   - Do automatic fixes actually work?
   - How long until critical threshold?

4. **Optimize Automation:**
   - Adjust thresholds if needed
   - Improve fix strategies
   - Add missing detections

## Resources

- **Your Toolkit:** `/Users/mihai/windowserver-fix/`
- **Documentation:** TEST_RESULTS.md, MONITORING_QUICKSTART.md
- **Logs:** `logs/` directory
- **Reddit Thread:** r/MacOS users reporting 6GB-42GB leaks (Nov 2025)
- **Your Repository:** github.com/chindris-mihai-alexandru/windowserver-fix

## Ready to Restart?

✓ LaunchAgent created
✓ Pre-restart baseline documented
✓ Automation ready
✓ Measurement plan defined
✓ Enhancement priorities identified

**You can safely restart your Mac now.**

The daemon will automatically:
- Start on login
- Monitor every 60 seconds
- Detect leaks at 2GB (warning) and 5GB (critical)
- Apply fixes automatically
- Send notifications
- Log all activity

**After restart, run:**
```bash
cd ~/windowserver-fix
./monitor.sh check
```

Then update the tracking table in TEST_RESULTS.md with your clean baseline.

---

**Good luck with your scientific measurements!**
