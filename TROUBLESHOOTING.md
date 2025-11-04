# Troubleshooting Guide (v2.0 - November 2025)

## 🚨 macOS Sequoia (15.x) Users - Read This First

If you're running macOS Sequoia and experiencing extreme memory usage (>5GB), you're likely hitting the confirmed Sequoia memory leak bug. See [Sequoia-Specific Issues](#sequoia-specific-issues-2025) below.

**Quick Sequoia Check:**
```bash
./fix.sh sequoia-check
```

## Quick Diagnostics

Run the enhanced diagnostic script (includes Sequoia leak detection):

```bash
./monitor.sh diagnostic
```

This will create a detailed report in `logs/diagnostic_*.txt` with Sequoia-specific analysis.

## Sequoia-Specific Issues (2025)

### 🔴 Issue: Extreme Memory Usage (5-200GB)

**Symptoms:**
- WindowServer using 5GB, 20GB, 50GB, or even 200GB RAM
- Memory grows ~1GB every time you open a new app window
- Memory is NOT released when you close apps
- System becomes unresponsive or crashes
- Issue persists even after clean macOS reinstall

**Diagnosis:**
```bash
./fix.sh status
# Look for "CRITICAL" or "EMERGENCY" severity
```

**Immediate Solutions:**

1. **Emergency Restart WindowServer (if >20GB)**
   ```bash
   ./fix.sh restart-windowserver
   ```
   ⚠️ This will log you out immediately!

2. **Kill iPhone Mirroring** (major leak trigger)
   ```bash
   pkill "iPhone Mirroring"
   # Or run: ./fix.sh sequoia-check
   ```

3. **Close All Unnecessary Apps**
   - Each app window = ~1GB leak
   - Use Activity Monitor to see which apps have most windows
   - Close browser tabs (each tab can trigger the leak)

4. **Enable Automatic Monitoring**
   ```bash
   ./daemon.sh start
   # Auto-restarts WindowServer if memory >20GB
   ```

**Long-term Solutions:**

1. **Update macOS** - Apple is actively working on fixes
   ```bash
   # Check for updates
   softwareupdate -l
   ```

2. **Disable iPhone Mirroring Permanently**
   - System Settings > General > AirDrop & Handoff
   - Turn off "iPhone Mirroring"

3. **Use Safari Instead of Firefox/Chrome**
   - Fullscreen video in Firefox/Chrome triggers leaks
   - Safari has fewer issues

4. **Consider Downgrading to Sonoma**
   - If leak is making Mac unusable
   - Backup first!

### 🔴 Issue: iPhone Mirroring Causes Immediate Leak

**Symptoms:**
- Open iPhone Mirroring → WindowServer RAM balloons
- Memory never reduces even after closing iPhone Mirroring
- Can consume 10-50GB within minutes

**Solution:**
```bash
# Terminate and disable
./fix.sh sequoia-check
# Follow prompts to kill process and get disable instructions
```

### 🔴 Issue: Ultra-wide Display (>5K) Triggers Severe Leak

**Symptoms:**
- Samsung Odyssey (7680x2160) or similar ultra-wide connected
- WindowServer immediately jumps to 5-10GB
- Continues growing with any window activity

**Solutions:**

1. **Use Default Resolution**
   - System Settings > Displays
   - Select "Default for display" (not Scaled)

2. **Reduce Resolution**
   - Lower to 5K or below temporarily
   - Test if leak stops

3. **Monitor Continuously**
   ```bash
   ./dashboard.sh
   # Watch memory in real-time
   ```

## Common Issues and Solutions

### 0. Understanding VM/RSS Discrepancy (v2.1.0+)

**What is it?**
macOS tracks two types of memory for every process:
- **VM (Virtual Memory)**: Total logical address space (what `top` shows)
- **RSS (Resident Set Size)**: Actual physical RAM used (what `ps aux` shows)

**Why the difference?**
From Apple's Memory Management docs, virtual memory includes:
1. **Active memory pages** in RAM
2. **Page tables** - kernel structures mapping virtual→physical addresses
3. **Memory-mapped files** - disk files mapped into address space
4. **Shared memory regions** - memory shared between processes
5. **Reserved but unused address space**

**For WindowServer specifically:**
- **Compositor buffers**: Offscreen rendering buffers for every window
- **GPU shared memory**: Memory-mapped GPU textures/buffers
- **Display framebuffers**: Memory for each connected display
- **Window backing stores**: Cached window content

**Normal ratios:**
- **Healthy**: VM is 2-5x RSS (e.g., 1.0GB VM / 200MB RSS = 500%)
- **Concerning**: VM is 5-10x RSS (e.g., 2.0GB VM / 200MB RSS = 1000%)
- **Critical leak**: VM is >10x RSS (e.g., 4.0GB VM / 200MB RSS = 2000%)

**Why high VM with low RSS indicates a leak:**
According to [Apple's Virtual Memory documentation](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/ManagingMemory/Articles/AboutMemory.html):
> "Wired data structures are also associated with the physical page and map tables used to store virtual-memory mapping information. Both of these entities scale with the amount of available physical memory."

When page table overhead grows beyond 1-2GB, it indicates:
- WindowServer is allocating/freeing memory repeatedly without cleanup
- Page table entries accumulate without being released
- Compositor buffers for closed windows remain mapped
- GPU memory mappings leak after display changes

**How this tool detects it:**
```bash
# Pattern 5: Page Table Leak
# Triggered when: (VM - RSS) > 1024MB
./fix.sh status
```

**Diagnosis:**
```bash
# Check current discrepancy
top -l 1 -pid $(pgrep WindowServer) | grep WindowServer
ps aux | grep WindowServer | grep -v grep

# View in dashboard (v2.1.0+)
./dashboard.sh
# Look for "Page Table" metric and "top_ps_discrepancy %"
```

**Solution:**
The only reliable fix is restarting WindowServer:
```bash
./fix.sh restart-windowserver  # Will log you out!
```

**Prevention:**
Enable daemon to auto-restart before reaching critical levels:
```bash
# In config.sh
EMERGENCY_RESTART_ENABLED=true
MEM_THRESHOLD_EMERGENCY=20480  # 20GB
```

---

### 1. High CPU Usage (> 60%)

**Symptoms:**
- WindowServer consistently using >60% CPU
- Mac running hot
- Fans spinning at high speed
- UI lag and stuttering

**Diagnosis:**
```bash
./monitor.sh check
```

**Solutions (in order):**

1. **Enable Reduce Transparency**
   ```bash
   ./fix.sh
   ```

2. **Check Display Resolution**
   - Go to System Settings > Displays
   - Use "Default" resolution instead of "Scaled"
   - For external 4K displays, avoid "Larger Text" scaled modes

3. **Disable Problematic Apps**
   - DisplayLink Manager
   - BetterDisplay
   - SwitchResX
   - Magnet/Rectangle (window management)
   
   Check which are running:
   ```bash
   ps aux | grep -E "DisplayLink|BetterDisplay|SwitchResX"
   ```

4. **Check for Chrome/Electron Apps**
   Many Electron apps can trigger WindowServer issues:
   ```bash
   ps aux | grep -i electron
   ```
   Try quitting Chrome/Electron apps temporarily

5. **Restart WindowServer** (will log you out!)
   ```bash
   sudo killall -HUP WindowServer
   ```

### 2. High Memory Usage (> 500MB)

**Symptoms:**
- WindowServer using 500MB+ RAM
- Gradual memory increase over time
- System becoming sluggish
- "Your system has run out of application memory"

**Note:** High VM with low RSS may not be visible in Activity Monitor. Use the dashboard or `./fix.sh status` to check for VM/RSS discrepancy (Pattern 5 leak).

**Diagnosis:**
```bash
./monitor.sh monitor
```
Let it run for 30 minutes to see if memory grows

**Solutions:**

1. **Memory Leak - Clear Pasteboard**
   ```bash
   pbcopy < /dev/null
   ```

2. **Clear WindowServer Cache**
   ```bash
   ./fix.sh clean
   ```

3. **Check for Memory Leaks in Apps**
   ```bash
   leaks WindowServer
   ```

4. **Purge System Memory**
   ```bash
   sudo purge
   ```

5. **Check Desktop Clutter**
   - Remove files from Desktop
   - Disable Desktop widgets
   - Close unused Spaces

### 2a. GPU Memory Leak (v2.1.0+)

**Symptoms:**
- WindowServer VM memory high (2-4GB+) but RSS memory low (<500MB)
- Page table overhead >1GB (shown in dashboard)
- Issue persists even after closing all apps
- Multiple display disconnects/reconnects trigger it
- Happens more with high-resolution displays (4K+, 5K+)

**Background:**
Based on GPU driver research (CVE-2022-32947), GPU firmware can leak page table entries when:
- Display modes change frequently
- Apps use GPU acceleration then exit without cleanup
- WindowServer maps/unmaps GPU buffers repeatedly
- Compositor buffers for closed windows stay mapped

**Diagnosis:**
```bash
# Check Pattern 5 detection
./fix.sh status
# Look for "LEAK_PATTERN_5: Page table leak"

# View real-time metrics
./dashboard.sh
# Look at "Page Table" row (should be <500MB normally)
```

**Solutions:**

1. **Immediate Fix** - Restart WindowServer (logs you out):
   ```bash
   ./fix.sh restart-windowserver
   ```

2. **Temporary Workaround** - Reduce display resolution:
   - System Settings > Displays
   - Use "Default" instead of "Scaled"
   - For external displays, avoid ultra-wide resolutions

3. **Automated Monitoring** - Let daemon handle it:
   ```bash
   # config.sh
   PAGE_TABLE_MONITORING_ENABLED=true
   MEM_THRESHOLD_EMERGENCY=20480  # Auto-restart at 20GB
   
   ./daemon.sh start
   ```

4. **Prevent GPU Leaks** - Disable hardware acceleration:
   - Chrome: Settings → System → Disable "Use hardware acceleration"
   - Firefox: Preferences → General → Performance → Uncheck hardware acceleration
   - Electron apps often cause this issue

**Why normal fixes don't work:**
- Clearing pasteboard: Only helps with clipboard leaks (Pattern 2)
- Purging memory: Doesn't reclaim page table overhead
- Restarting Dock: Unrelated to WindowServer page tables
- System cache clear: Page tables are kernel-managed

Only a full WindowServer restart releases leaked page tables.

### 3. Crashes on Wake from Sleep

**Symptoms:**
- WindowServer crashes when Mac wakes
- Black screen on wake
- Need to force restart
- Login screen appears unexpectedly

**Diagnosis:**
Check Console.app for crash reports:
```bash
ls -lt /Library/Logs/DiagnosticReports/ | grep WindowServer | head -5
```

**Solutions:**

1. **Disable Auto Sleep for Displays**
   ```bash
   sudo pmset -a displaysleep 0
   ```

2. **Reset Display Preferences**
   ```bash
   rm ~/Library/Preferences/ByHost/com.apple.windowserver.displays.*.plist
   ```
   Then logout/login

3. **Check Power Nap**
   - System Settings > Battery > Options
   - Disable "Power Nap"

4. **External Display Issue**
   - Try different cable
   - Try different port
   - Update display firmware

### 4. Multiple Display Issues

**Symptoms:**
- Problems only occur with external displays
- Works fine with lid closed (clamshell mode)
- Random disconnects
- Display flickering

**Solutions:**

1. **Check Connection Type**
   - USB-C → HDMI adapter issues are common
   - Try native DisplayPort if available
   - Avoid daisy-chaining adapters

2. **Set Display as Extended (not Main)**
   - System Settings > Displays
   - Arrange displays
   - Don't use "Mirror" mode if possible

3. **Disable Automatic Display Brightness**
   - System Settings > Displays
   - Turn off "Automatically adjust brightness"

4. **Check Hub/Dock**
   If using a USB-C hub:
   - Ensure it's Thunderbolt certified
   - Check power delivery is sufficient
   - Update hub firmware
   - Try connecting display directly

### 5. After macOS Update

**Symptoms:**
- Problem started immediately after OS update
- Was working fine before update

**Solutions:**

1. **Reset NVRAM** (M1/M2/M3 Macs)
   - Shut down Mac
   - Hold power button until "Loading startup options" appears
   - Release, then press and hold: Option + Command + P + R
   - Release after 20 seconds

2. **Safe Mode Boot**
   - M1/M2/M3: Shut down, hold power button, select disk, hold Shift, click "Continue in Safe Mode"
   - Check if problem persists in Safe Mode
   - If works in Safe Mode → third-party software issue

3. **Clean Install macOS** (last resort)
   - Backup everything
   - Boot to Recovery (Command + R on Intel, hold power on Apple Silicon)
   - Erase disk and reinstall macOS

### 6. Kernel Panics Related to WindowServer

**Symptoms:**
- Mac suddenly restarts
- "Your computer restarted because of a problem"
- WindowServer mentioned in crash report

**Diagnosis:**
```bash
log show --predicate 'eventMessage contains "panic"' --last 24h
```

**Solutions:**

1. **Hardware Diagnostics**
   - Restart and hold D key (Intel) or power button (Apple Silicon)
   - Run Apple Diagnostics
   - Check for GPU/display hardware issues

2. **Remove Third-Party Kernel Extensions**
   ```bash
   kextstat | grep -v com.apple
   ```
   Uninstall any third-party kexts

3. **Check GPU**
   If you have multiple GPUs, force integrated graphics:
   - System Settings > Battery > Options
   - Enable "Low Power Mode"

### 7. Fullscreen Video Issues

**Symptoms:**
- WindowServer crashes when playing fullscreen video
- YouTube/Netflix causes crashes
- Video player apps cause issues

**Solutions:**

1. **Disable Hardware Acceleration**
   - Chrome: Settings → System → Disable "Use hardware acceleration"
   - Firefox: Preferences → General → Performance → Uncheck "Use hardware acceleration"

2. **Use Different Video Player**
   - Try VLC instead of QuickTime
   - Use native YouTube app instead of browser

3. **Check Display Mirroring**
   - Issues often occur with mirrored displays
   - Use extended display mode instead

## Monitoring for Root Cause

If issue is intermittent, run continuous monitoring:

```bash
# Start monitoring in background
./monitor.sh monitor > ~/windowserver_debug.log 2>&1 &

# Let it run for a day, then analyze
grep WARNING ~/windowserver_debug.log
```

## Advanced Debugging

### Check for Memory Leaks

```bash
# Install heap if not present
# sudo leaks WindowServer

# Alternative: use Instruments.app
# /Applications/Xcode.app/Contents/Applications/Instruments.app
```

### Monitor with fs_usage

```bash
# Monitor file system activity by WindowServer
sudo fs_usage -w -f filesys $(pgrep WindowServer) | tee windowserver_fs.log
```

### Check Console Logs

```bash
# Real-time WindowServer logs
log stream --predicate 'process == "WindowServer"' --level debug
```

### Sample WindowServer Process

```bash
# Take sample when CPU is high
sudo sample WindowServer 10 -f ~/windowserver_sample.txt
```

## When to Contact Apple Support

Contact Apple if:
1. Issue persists after trying all solutions
2. Kernel panics continue
3. Hardware diagnostics show failures
4. Issue started with specific macOS update
5. Reproducible steps that trigger the problem

Provide them with:
- Diagnostic report: `./monitor.sh diagnostic`
- Console logs with WindowServer crashes
- sysdiagnose: Hold Shift+Option+Command+Control+. for 10 seconds

## Community Help

If none of these solutions work:

1. Post your diagnostic file to GitHub issues
2. Include:
   - macOS version
   - Mac model
   - Display configuration
   - When issue started
   - What triggers it
   - What you've tried

## Rollback Changes

If fixes made things worse:

```bash
./fix.sh restore
```

This restores settings from the most recent backup.

## Prevention

Once you find a stable configuration:

1. **Create a backup**
   ```bash
   ./fix.sh backup
   ```

2. **Document your setup**
   - Display resolution and arrangement
   - Apps running at startup
   - System settings that work

3. **Use daemon for monitoring**
   ```bash
   ./daemon.sh start
   ```

4. **Before macOS updates**
   - Create Time Machine backup
   - Note current settings
   - Wait a few days for bug reports

---

## v2.1.0 Leak Detection Patterns

The tool now detects 6 distinct leak patterns:

### Pattern 1: High Memory with Few Apps
- **Trigger**: >2GB memory with <5 apps running
- **Cause**: Memory not released after apps close
- **Fix**: Clear pasteboard, purge caches

### Pattern 2: Pasteboard Leak
- **Trigger**: Large clipboard content (images, videos)
- **Cause**: WindowServer holds clipboard data
- **Fix**: `pbcopy < /dev/null`

### Pattern 3: Display Resolution Leak
- **Trigger**: High memory with scaled/non-standard resolutions
- **Cause**: Compositor buffers for non-native resolution
- **Fix**: Use default display resolution

### Pattern 4: GPU Memory Leak (NEW in v2.1.0)
- **Trigger**: GPU VRAM >1GB while RSS stable
- **Cause**: GPU firmware not releasing VRAM
- **Detection**: `gpu_vram_mb` in CSV metrics
- **Fix**: Restart WindowServer

### Pattern 5: Page Table Leak (NEW in v2.1.0)
- **Trigger**: (VM - RSS) >1GB
- **Cause**: Page table entries accumulating without release
- **Detection**: `page_table_mb` and `top_ps_discrepancy` metrics
- **Fix**: Restart WindowServer (only solution)
- **Research**: Based on CVE-2022-32947 GPU exploit analysis
- **Your system**: Currently experiencing this pattern!

### Pattern 6: Compositor Leak (NEW in v2.1.0)
- **Trigger**: Window buffer memory >2GB
- **Cause**: Offscreen buffers not freed for closed windows
- **Detection**: `compositor_mb` in CSV metrics
- **Fix**: Close spaces, reduce transparency, restart WindowServer

### Viewing Detected Patterns

```bash
# In dashboard (real-time)
./dashboard.sh
# Shows "Leak Patterns (last 100)" section

# In CSV logs (historical)
tail -20 logs/metrics.csv | awk -F, '{print $1,$15,$16}'
# Columns: timestamp, severity, leak_pattern

# Check current pattern
./fix.sh status
# Displays active leak patterns
```

### Configuration

Customize thresholds in `config.sh`:
```bash
# Pattern 5: Page Table Leak
PAGE_TABLE_LEAK_THRESHOLD=1024  # MB of VM overhead

# Pattern 4: GPU Memory Leak
GPU_LEAK_THRESHOLD=1024  # MB of GPU VRAM

# Pattern 6: Compositor Leak  
COMPOSITOR_LEAK_THRESHOLD=2048  # MB of window buffers
```

