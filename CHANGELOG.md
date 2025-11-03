# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Menu bar app
- Better metrics visualization
- Automated testing
- Homebrew formula
- Additional mitigation strategies
- Machine learning to predict issues

### Reported Issues Being Investigated
- Memory leak detection
- Better external display detection
- USB-C hub compatibility
- Chrome/Electron app interaction
