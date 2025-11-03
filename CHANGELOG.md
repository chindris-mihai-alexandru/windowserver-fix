# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-03

### 🚨 Major Update: macOS Sequoia (15.x) Memory Leak Support

This release adds comprehensive detection and mitigation for the critical macOS Sequoia memory leak bug affecting WindowServer.

### Added - Sequoia-Specific Features
- **Leak Pattern Detection** - Identifies the Sequoia ~1GB/window memory leak pattern
- **iPhone Mirroring Detection** - Auto-detects and offers to terminate this major leak trigger
- **ProMotion Display Checks** - Monitors 120Hz display compatibility issues
- **Ultra-wide Display Detection** - Warns about >5K resolution leak triggers (e.g., Samsung Odyssey 7680x2160)
- **Browser Compatibility Checks** - Detects Firefox/Chrome fullscreen video (known leak trigger)
- **Emergency Auto-Restart** - Prevents system crash when WindowServer exceeds 20GB RAM
- **Memory Severity Levels**:
  - NORMAL: <500MB
  - WARNING: >2GB (potential leak)
  - CRITICAL: >5GB (confirmed Sequoia leak)
  - EMERGENCY: >20GB (system crash imminent)

### Enhanced - Monitoring (`monitor.sh`)
- macOS version detection and Sequoia-specific thresholds
- Memory growth rate tracking (detects >500MB growth pattern)
- App window counting (correlates with ~1GB/window leak)
- History file for leak pattern analysis
- Enhanced diagnostic capture with Sequoia-specific data
- Updated CSV format with iPhone Mirroring status, app count, severity

### Enhanced - Fix Script (`fix.sh`)
- Sequoia leak checks on every run
- `./fix.sh sequoia-check` - Run only Sequoia-specific diagnostics
- `./fix.sh restart-windowserver` - Emergency WindowServer restart
- iPhone Mirroring termination with user confirmation
- ProMotion display warnings and recommendations
- Ultra-wide display detection and mitigation advice
- Browser compatibility warnings (Safari recommended for video)
- Color-coded severity status (normal/warning/critical/emergency)

### Enhanced - Daemon (`daemon.sh`)
- Sequoia leak pattern detection in automatic mode
- Auto-terminate iPhone Mirroring when leak detected
- Emergency WindowServer restart at >20GB (1 hour cooldown)
- Memory growth tracking for leak prediction
- Enhanced logging with app count and leak status
- Different notification sounds for severity levels
- Top memory app tracking when issues detected

### Updated Documentation
- README.md - Added Sequoia leak section with 2025 data
- All scripts show version 2.0 and November 2025 date
- Added troubleshooting for Sequoia-specific issues
- Documented 2025 research findings (32% buggy apps, ~1GB/window leak)

### Technical Details
- New thresholds: WARNING (2GB), CRITICAL (5GB), EMERGENCY (20GB)
- Memory history tracking (last 100 samples)
- iPhone Mirroring process detection via `pgrep`
- ProMotion detection via system_profiler (120 Hz check)
- Ultra-wide detection via resolution parsing (>=5120 width)
- Leak pattern: >2GB memory with <10 windows = confirmed leak

## [1.0.0] - 2024-11-03

### Added
- Initial release of WindowServer Fix toolkit
- `monitor.sh` - Monitor WindowServer CPU and memory usage
  - Single check mode
  - Continuous monitoring mode
  - Full diagnostic capture
  - CSV metrics export
- `fix.sh` - Apply mitigation strategies
  - Reduce transparency
  - Optimize Dock animations
  - Disable Space rearrangement
  - Clean WindowServer cache
  - Display configuration recommendations
  - Settings backup and restore
- `daemon.sh` - Background monitoring daemon
  - Automatic detection of high usage
  - Safe automatic fixes
  - Cooldown to prevent fix loops
- `dashboard.sh` - Real-time monitoring dashboard
  - Visual CPU/memory bars
  - System information display
  - Settings status check
  - 5-second refresh rate
- `install.sh` - Quick installation script
- Comprehensive documentation
  - README.md - Main documentation
  - TROUBLESHOOTING.md - Common issues and solutions
  - CONTRIBUTING.md - Contribution guidelines
- Support for macOS Monterey, Ventura, Sonoma, Sequoia
- Support for Intel and Apple Silicon Macs

### Features
- Non-invasive fixes (no SIP disable required)
- Settings backup before any changes
- Rollback capability
- Detailed logging
- Multiple display configuration support
- CSV metrics for long-term analysis

### Known Issues
- Cannot restart WindowServer without logging out (macOS limitation)
- Some fixes require logout to take full effect
- Daemon has limited automatic fix capabilities (safety first)

## [Unreleased]

### Planned Features
- GUI application
- Menu bar app with real-time Sequoia leak alerts
- Better metrics visualization (charts for memory growth)
- Automated testing
- Homebrew formula
- Additional Sequoia-specific mitigation strategies
- Integration with Activity Monitor
- Auto-update mechanism when Apple releases leak fixes

### Reported Issues Being Investigated
- Better correlation between specific apps and Sequoia leak
- USB-C hub compatibility with ultra-wide displays
- Chrome/Electron app interaction on Sequoia
- Downgrade path from Sequoia to Sonoma documentation
- Integration with third-party display management tools (BetterDisplay, etc.)
