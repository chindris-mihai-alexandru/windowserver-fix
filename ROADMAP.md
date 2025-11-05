# WindowServer Fix - Roadmap

**Last Updated**: November 4, 2025  
**Current Version**: v2.1.0 (Beta)  
**Next Major Release**: v2.2.0 (Q1 2026) / v3.0.0 (Q2 2026)

---

## Executive Summary

This roadmap outlines improvements to the WindowServer Fix toolkit based on:
1. **Recent fixes**: Window repositioning bug (Dock restart removal) and notification disabling
2. **CI/CD implementation**: ShellCheck, smoke tests, CodeQL security scanning (completed Nov 4, 2025)
3. **GPU exploit research**: Insights from Asahi Linux GPU firmware vulnerability work (CVE-2022-32947)
4. **Memory leak patterns**: Understanding how WindowServer interacts with GPU memory subsystems
5. **macOS Sequoia leak**: The confirmed 5-200GB memory leak affecting macOS 15.x

---

## Recent Completed Work (November 2025)

### ✅ CI/CD Quality Gates (v2.1.0)
- [x] **ShellCheck Workflow** - Lints all `.sh` scripts, catches 80% of shell bugs
- [x] **Smoke Test Workflow** - Validates syntax, permissions, help flags
- [x] **CodeQL Advanced Security** - 170+ CWE security queries
- [x] **Branch Protection Rules** - Main branch requires all checks + 1 review
- [x] **Documentation** - README updated with CI/CD section and badges
- [x] **Bug Fixes** - Found and fixed 2 real issues in `fix.sh` and `health_check.sh`
- [x] **GitHub Actions** - All workflows passing on every push/PR

---

## Key Insights from GPU Research

### From Lina's GPU Exploit Work (3.5hr video):

1. **Virtual Memory & Page Tables**
   - macOS uses complex virtual memory management for GPU processes
   - WindowServer maintains separate GPU memory page tables
   - Memory leaks may occur at the page table level (not just heap allocation)

2. **GPU Firmware Vulnerabilities** (CVE-2022-32947)
   - GPU firmware bugs can cause memory to be allocated but never freed
   - WindowServer is particularly susceptible as the primary GPU client
   - Memory can leak in GPU-managed regions invisible to standard tools

3. **Memory Measurement Accuracy**
   - `top` command provides more accurate real-time memory readings than `ps aux`
   - `ps aux` can show stale/cached data
   - GPU memory usage often not reflected in standard process memory metrics

4. **GPU Process Interaction**
   - WindowServer spawns GPU helper processes that may leak independently
   - Memory allocated by GPU processes may not be attributed to WindowServer PID
   - Compositor memory (for window buffers) is a high-risk leak area

---

## Version Roadmap Overview

### v2.1.0 - Immediate Improvements (December 2025)
- Quick wins from recent bug fixes
- Enhanced logging and diagnostics
- Better user documentation

### v2.2.0 - GPU Memory Analysis (Q1 2026)
- GPU-specific memory tracking
- Page table monitoring
- Improved memory measurement accuracy

### v3.0.0 - Deep System Integration (Q2 2026)
- GPU firmware awareness
- Kernel-level monitoring (with user opt-in)
- Machine learning leak prediction
- GUI application

---

## v2.1.0 - Immediate Improvements (In Progress)

### ✅ Completed (November 4, 2025)
- [x] **Window Repositioning Bug** - Removed `killall Dock` from daemon auto-fixes (daemon.sh:226-228)
- [x] **Notification Spam** - Disabled all 4 notification types in daemon.sh
- [x] **CI/CD Quality Gates** - ShellCheck, smoke tests, CodeQL security scanning
- [x] **Branch Protection** - Main branch requires all checks to pass before merge
- [x] **Documentation** - README and ROADMAP updated with CI/CD details

### 🚧 Next Steps - CI/CD Hardening (Optional, 1-2 days)

#### CI/CD Enhancement Options
**Priority**: MEDIUM  
**Effort**: 1-2 days

**Option 1: Local Development Tools**
- Create `.shellcheckrc` config file for consistent local linting
- Add pre-commit hooks to run ShellCheck before commits
- Document local development workflow in CONTRIBUTING.md

**Option 2: Supply Chain Security**
- Pin ShellCheck action to SHA (currently uses semantic version `@v2.0.0`)
- Add Dependabot security updates for GitHub Actions
- Document security practices

**Option 3: Intel Mac Testing**
- Add macOS runner workflow (Intel Mac testing)
- Current smoke tests run on Ubuntu (Linux bash, not macOS)
- Note: GitHub Actions only provides macOS runners (no Intel-specific option in 2025)

**Decision Required:** Should we complete CI/CD hardening or move to v2.1.0 feature work?

---

### 🎯 Short-term Improvements (Next 2-4 Weeks)

#### 1. Memory Measurement Accuracy
**Priority**: HIGH  
**Effort**: 2 days  
**Based on**: GPU exploit video insights about `top` vs `ps aux`

**Changes:**
- Switch from `ps` to `top -l 1` for WindowServer memory readings
- Add GPU memory tracking via `system_profiler SPDisplaysDataType`
- Implement dual measurement (RSS + GPU VRAM) for accurate leak detection
- Add validation checks to compare `top` vs `ps` output

**Files to modify:**
- `monitor.sh` - Update `get_windowserver_memory()` function
- `daemon.sh` - Update memory collection logic
- `dashboard.sh` - Display both RSS and GPU memory

**Acceptance criteria:**
- Memory readings match Activity Monitor within 5%
- GPU VRAM usage tracked separately
- Historical comparison shows measurement method differences

---

#### 2. Enhanced Leak Pattern Detection
**Priority**: HIGH  
**Effort**: 3 days  
**Based on**: Page table leak patterns from GPU research

**New detection patterns:**

**Pattern 4: GPU Memory Leak**
```bash
# GPU VRAM growing while RSS stays constant
if gpu_memory_growth > 500MB AND rss_growth < 100MB:
    → GPU_LEAK_DETECTED
```

**Pattern 5: Page Table Leak**
```bash
# Total memory growth exceeds sum of tracked allocations
if total_memory > (rss + gpu_vram + swap) + 1GB:
    → PAGE_TABLE_LEAK_SUSPECTED
```

**Pattern 6: Compositor Leak**
```bash
# Memory correlates with window count but doesn't decrease
if memory_per_window > 1GB AND windows_closed > 5 AND memory_unchanged:
    → COMPOSITOR_LEAK_DETECTED
```

**Files to modify:**
- `monitor.sh` - Add new leak pattern detection functions
- `daemon.sh` - Implement pattern-specific auto-fixes
- `TROUBLESHOOTING.md` - Document new leak types

---

#### 3. Daemon Improvements
**Priority**: MEDIUM  
**Effort**: 2 days

**Changes:**
- Add configurable check intervals (default: 5 min)
- Separate "monitoring mode" (logs only) from "auto-fix mode"
- Add dry-run mode for testing detection without fixes
- Improve cooldown logic (per-fix-type instead of global)

**Configuration file**: `~/.windowserver-fix/config.sh`
```bash
# User-configurable settings
CHECK_INTERVAL=300           # seconds (5 min default)
AUTO_FIX_ENABLED=true        # or false for monitoring only
DRY_RUN=false                # test mode
DOCK_RESTART_ENABLED=false   # keep disabled by default
NOTIFICATIONS_ENABLED=false  # keep disabled by default
```

**Files to create/modify:**
- `config.sh` (new) - User configuration
- `daemon.sh` - Load config, implement modes
- `README.md` - Document configuration options

---

#### 4. Documentation Updates
**Priority**: MEDIUM  
**Effort**: 1 day

**Changes:**
- Update TROUBLESHOOTING.md with Dock restart bug explanation
- Add "Known Issues" section with window repositioning workaround
- Document notification disabling
- Create FAQ.md with common questions
- Add GPU memory concepts section to README

**Files to modify:**
- `TROUBLESHOOTING.md`
- `README.md`
- `FAQ.md` (new)
- `V2_RELEASE_NOTES.md`

---

## v2.2.0 - GPU Memory Analysis (Q1 2026)

### Major Features

#### 1. GPU Memory Tracking
**Priority**: HIGH  
**Effort**: 1 week  
**Based on**: GPU firmware research and page table monitoring

**Implementation:**

**New script**: `gpu_monitor.sh`
```bash
#!/bin/bash
# GPU-specific memory monitoring

# Track GPU VRAM allocation
get_gpu_memory() {
    # Use IOKit framework to query GPU memory
    ioreg -l -w0 | grep -i "vram" | awk '{print $3}'
}

# Track GPU processes
get_gpu_processes() {
    # Find processes using GPU (Metal, OpenGL, etc.)
    ps aux | grep -E "(WindowServer|Metal|OpenGL)" | grep -v grep
}

# Track compositor memory
get_compositor_memory() {
    # Estimate window buffer memory: width * height * 4 bytes * buffer_count
    # Query all window sizes and calculate total
}

# Detect GPU page table leaks
detect_page_table_leak() {
    # Compare allocated vs tracked memory
    # Alert if >1GB discrepancy
}
```

**Features:**
- Real-time GPU VRAM usage tracking
- Per-process GPU memory attribution
- Compositor memory estimation based on window sizes
- Page table leak detection (allocated vs tracked memory)
- GPU helper process monitoring

**Integration:**
- Add GPU metrics to `metrics.csv`
- Display GPU memory in `dashboard.sh`
- Include GPU data in diagnostic reports
- Add GPU-specific thresholds

---

#### 2. Page Table Monitoring
**Priority**: MEDIUM  
**Effort**: 1 week  
**Based on**: Virtual memory research from GPU exploit video

**Concept:**
```bash
# Monitor virtual memory page tables for WindowServer
# Detect when page tables grow without corresponding RSS increase

get_page_table_size() {
    # Use vm_stat to track page table overhead
    vm_stat | grep "Pages wired down" | awk '{print $4}'
}

detect_orphaned_pages() {
    # Find memory pages allocated but not tracked
    # Compare vmmap output with RSS + GPU memory
    vmmap -w -summary $WINDOWSERVER_PID | grep "MALLOC\|STACK\|GPU"
}
```

**Features:**
- Track page table size growth
- Detect orphaned memory pages
- Alert on page table fragmentation
- Correlate with WindowServer operations

---

#### 3. Improved Accuracy Tools
**Priority**: HIGH  
**Effort**: 3 days

**Changes:**
- Implement dual measurement system (top + ps comparison)
- Add memory measurement validation
- Track measurement discrepancies over time
- Auto-switch to most accurate method

**New function**: `get_accurate_memory()`
```bash
get_accurate_memory() {
    # Method 1: top (real-time)
    local top_mem=$(top -l 1 -pid $PID | tail -1 | awk '{print $8}')
    
    # Method 2: ps (historical)
    local ps_mem=$(ps -p $PID -o rss= | awk '{print $1/1024}')
    
    # Method 3: Activity Monitor API
    local am_mem=$(ioreg -l | grep -A 20 WindowServer | grep Memory)
    
    # Return most accurate measurement
    # Prefer: top > Activity Monitor > ps
    echo "$top_mem"
}
```

---

#### 4. Display Profile Analysis
**Priority**: MEDIUM  
**Effort**: 4 days

**Features:**
- Detect display configuration changes (resolution, refresh rate, scaling)
- Correlate display changes with memory spikes
- Build display compatibility database
- Recommend optimal display settings per configuration

**Implementation:**
```bash
# Track display configuration changes
monitor_display_changes() {
    # Baseline display config
    local current_config=$(system_profiler SPDisplaysDataType)
    
    # Detect changes
    while true; do
        local new_config=$(system_profiler SPDisplaysDataType)
        if [ "$new_config" != "$current_config" ]; then
            log "DISPLAY_CHANGE_DETECTED"
            check_memory_spike
        fi
        sleep 60
    done
}
```

---

## v3.0.0 - Deep System Integration (Q2 2026)

### Major Features

#### 1. GUI Application
**Priority**: HIGH  
**Effort**: 3 weeks  
**Technology**: SwiftUI + AppKit

**Features:**
- Menu bar icon with real-time memory display
- Click to see detailed dashboard
- Visual memory graphs (last 24 hours)
- GPU memory visualization
- One-click fixes
- Notification preferences
- Display configuration recommendations
- Export diagnostic reports

**Screens:**
1. **Menu Bar**: WindowServer memory + status indicator
2. **Main Dashboard**: Real-time graphs, current status
3. **Diagnostics**: Full system analysis
4. **Settings**: Configure thresholds, auto-fixes, notifications
5. **History**: Long-term memory trends

---

#### 2. GPU Firmware Awareness
**Priority**: MEDIUM  
**Effort**: 2 weeks

**Features:**
- Detect GPU firmware version
- Cross-reference with known leak-prone firmware versions
- Alert users to GPU firmware issues
- Recommend firmware updates when available
- Track GPU firmware CVEs (like CVE-2022-32947)

**Database**: `gpu_firmware_issues.json`
```json
{
  "apple_m1_gpu": {
    "firmware_versions": {
      "1.0.0": {
        "leak_risk": "high",
        "cves": ["CVE-2022-32947"],
        "recommendation": "Update to macOS 13.2+"
      }
    }
  }
}
```

---

#### 3. Kernel-Level Monitoring (Optional)
**Priority**: LOW  
**Effort**: 2 weeks  
**Note**: Requires user to disable SIP (opt-in only)

**Features:**
- Kernel extension for deep memory tracking
- Track kernel-level GPU allocations
- Monitor GPU driver memory usage
- Detect firmware-level leaks

**Warning**: Only for advanced users willing to disable SIP

**Implementation:**
- SwiftUI app with SIP status check
- Clear warnings about SIP disable risks
- Auto-detect if SIP disabled
- Enable kernel monitoring only with explicit user consent

---

#### 4. Machine Learning Leak Prediction
**Priority**: MEDIUM  
**Effort**: 3 weeks

**Features:**
- Train ML model on historical leak patterns
- Predict when leaks will occur (before they happen)
- Recommend preventive actions
- Learn user-specific patterns

**Data collected:**
- Memory usage over time
- App launch/quit events
- Display configuration changes
- Time of day patterns
- User activity levels

**Model outputs:**
- Leak probability score (0-100%)
- Time to predicted leak
- Recommended preventive actions
- High-risk app/display configurations

**Privacy:**
- All ML training done locally
- No data sent to servers
- User can opt-out
- Clear data at any time

---

## Research & Investigation Tasks

### Ongoing Research Needed

#### 1. GPU Memory Leak Root Cause Analysis
**Timeline**: Continuous  
**Resources needed**: 
- Access to GPU debugging tools
- Collaboration with macOS GPU driver developers
- Testing on multiple macOS versions

**Questions to answer:**
- What specific GPU operations trigger leaks?
- Is it a Metal framework bug or GPU firmware?
- Does it affect all M-series chips equally?
- Are there specific window manager operations that leak?

---

#### 2. Display Configuration Database
**Timeline**: Ongoing (crowdsourced)  
**Goal**: Build comprehensive database of display configs and leak patterns

**Data to collect:**
- Display model, resolution, refresh rate
- macOS version
- Mac model (M1/M2/M3, Intel)
- Connection type (USB-C, HDMI, DisplayPort, Thunderbolt)
- Hub/dock model (if used)
- Leak frequency and severity

**Community contribution:**
- Users submit their configurations
- Automated collection via diagnostic reports
- Build compatibility matrix
- Publish results on GitHub

---

#### 3. Browser Memory Leak Investigation
**Timeline**: Q1 2026  
**Focus**: Firefox/Chrome fullscreen video + PiP leaks

**Investigation:**
- Which browser features trigger leaks?
- Is it related to hardware video decode?
- Does Safari avoid the leak? Why?
- Can browsers implement workarounds?

**Outcome:**
- Document browser-specific issues
- Recommend workarounds
- Contact browser vendors with findings

---

#### 4. iPhone Mirroring Memory Analysis
**Timeline**: Q1 2026  
**Focus**: Why does iPhone Mirroring cause immediate RAM balloon?

**Investigation:**
- What is iPhone Mirroring's GPU usage?
- How does it interact with WindowServer?
- Why isn't memory released when closed?
- Can we force memory release without restart?

**Tools:**
- Instruments.app (Allocations, VM Tracker)
- fs_usage for filesystem activity
- dtrace for system calls
- GPU frame capture

---

## Community Contributions

### How Others Can Help

#### Beta Testing
- Test on different Mac models
- Test on different macOS versions
- Test with different display configurations
- Report results via GitHub Issues

#### Development
- Implement new features from roadmap
- Add support for additional macOS versions
- Improve detection algorithms
- Contribute GPU monitoring tools

#### Research
- Share leak triggers you've discovered
- Submit diagnostic reports from severe leaks
- Test proposed fixes
- Contribute to display compatibility database

#### Documentation
- Improve existing docs
- Translate to other languages
- Create video tutorials
- Write blog posts about findings

---

## Success Metrics

### v2.1.0 Goals
- [x] ✅ Implement CI/CD quality gates (ShellCheck, smoke tests, CodeQL)
- [x] ✅ Reduce false positives by fixing Dock restart bug
- [x] ✅ Zero reports of unwanted Dock restarts
- [ ] 🚧 Improve memory measurement accuracy to within 5% of Activity Monitor
- [ ] 🚧 User-configurable operation (monitoring vs auto-fix modes)
- [ ] 🚧 Track GPU memory separately from RSS

### v2.2.0 Goals
- [ ] Track GPU memory separately from RSS
- [ ] Detect GPU-specific leaks (not just general memory growth)
- [ ] Build display compatibility database with 100+ configurations
- [ ] Identify at least 3 new leak patterns

### v3.0.0 Goals
- [ ] Release GUI app to Mac App Store (or GitHub releases)
- [ ] 1000+ active users
- [ ] ML model with >80% leak prediction accuracy
- [ ] Comprehensive GPU firmware issue database
- [ ] Recognition from Apple/macOS community

---

## Release Timeline

| Version | Target Date | Status | Key Features |
|---------|-------------|--------|--------------|
| v2.0.0 | Nov 3, 2025 | ✅ Released | Sequoia leak detection |
| v2.0.1 | Nov 4, 2025 | ✅ Released | Bug fixes (Dock restart, notifications) |
| v2.1.0 | Dec 15, 2025 | 🚧 In Progress | **CI/CD complete**, GPU memory tracking, accuracy improvements |
| v2.2.0 | Feb 28, 2026 | 📋 Planned | Page table monitoring, ML leak prediction |
| v3.0.0 | May 31, 2026 | 💡 Proposed | GUI app, kernel monitoring, comprehensive ML |

---

## Breaking Changes Warning

### v2.1.0
- Configuration file format change (migration path provided)
- CSV metrics format updated (new GPU columns)

### v2.2.0
- Minimum macOS version: 12.0 (Monterey) for GPU APIs

### v3.0.0
- GUI app may replace command-line scripts as primary interface
- Legacy scripts maintained for backward compatibility

---

## Dependencies & Requirements

### Current (v2.0)
- macOS 10.15+ (Catalina or later)
- bash 3.2+
- Standard macOS command-line tools

### v2.2.0 Additions
- macOS 12.0+ (for GPU monitoring APIs)
- Xcode Command Line Tools (for ioreg enhanced features)
- Python 3.9+ (optional, for ML features)

### v3.0.0 Additions
- macOS 13.0+ (Ventura or later, for SwiftUI 4)
- Swift 5.7+
- Xcode 14+ (for building GUI app)

---

## Funding & Resources

### Current Status
- Open source project
- No external funding
- Volunteer development

### Future Needs
- Hosting for community database ($10/month)
- Apple Developer Account for app distribution ($99/year)
- Testing hardware (different Mac models, displays)
- Time for research and development

### Potential Funding Sources
- GitHub Sponsors
- Patreon
- One-time donations
- Mac App Store revenue (if/when GUI app released)

---

## Known Limitations

### Technical Constraints
- Cannot fix underlying macOS bugs (only mitigation)
- SIP prevents deep system modifications (by design)
- GPU memory tracking limited by API availability
- No kernel-level access without SIP disable

### Project Constraints
- Volunteer development (limited time)
- Testing hardware access
- No direct Apple contact/feedback
- Dependent on macOS updates for root cause fix

---

## Call to Action

### Immediate (This Week)
1. Test v2.0.1 with Dock restart disabled
2. Verify no window repositioning issues
3. Confirm notifications are disabled
4. Report any remaining issues

### Short-term (This Month)
1. Contribute to display compatibility database
2. Test GPU memory tracking (when v2.1.0 released)
3. Share findings on Reddit/Apple Communities
4. Star the GitHub repo to show support

### Long-term (2026)
1. Beta test GUI app
2. Contribute code/documentation
3. Spread the word about the project
4. Help with ML model training data

---

## Contact & Feedback

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: General questions, research findings
- **Reddit**: r/MacOS (tag as WindowServer Fix)
- **Email**: (To be added when available)

---

## Acknowledgments

This roadmap is based on:
- **GPU Exploit Research**: Asahi Linux developer Lina's work on CVE-2022-32947
- **Community Reports**: 1000s of macOS users experiencing WindowServer issues
- **User Feedback**: Your report of the Dock restart bug
- **Personal Testing**: M1 Max MacBook Pro with macOS Sequoia 15.7.2

---

## Conclusion

This roadmap transforms the WindowServer Fix from a reactive tool (fixes issues after they occur) to a **predictive, preventive system** that:

1. **Understands** GPU memory at a deep level
2. **Predicts** when leaks will occur
3. **Prevents** issues before they impact users
4. **Educates** users about their specific configuration risks

The insights from GPU firmware research provide a foundation for much more accurate leak detection and targeted fixes.

**Next immediate action**: Implement v2.1.0 GPU memory tracking within 2 weeks.

---

**Version**: 1.0.0  
**Last Updated**: November 4, 2025  
**Maintained by**: WindowServer Fix Community  
**License**: MIT
