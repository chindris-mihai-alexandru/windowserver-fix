#!/bin/bash

# WindowServer Fix - User Configuration
# v2.1.0 - November 2025
# 
# This file allows you to customize the behavior of the WindowServer Fix toolkit.
# All settings have sensible defaults and can be modified as needed.

#============================================================================
# MONITORING SETTINGS
#============================================================================

# Check interval in seconds (daemon.sh)
# Default: 300 (5 minutes)
# Recommended range: 60-600
CHECK_INTERVAL=300

# Enable detailed logging (verbose mode)
# Default: false
# Set to 'true' for debugging issues
VERBOSE_LOGGING=false

#============================================================================
# AUTO-FIX SETTINGS
#============================================================================

# Enable automatic fixes when issues detected
# Default: true
# Set to 'false' for monitoring-only mode (no automatic actions)
AUTO_FIX_ENABLED=true

# Dry-run mode (test detection without applying fixes)
# Default: false
# Set to 'true' to test leak detection without making changes
DRY_RUN=false

# Enable Dock restart as auto-fix
# Default: false (disabled due to window repositioning bug)
# Only enable if you don't mind windows being moved occasionally
DOCK_RESTART_ENABLED=false

# Enable WindowServer restart for emergency situations (>20GB memory)
# Default: true
# Automatically restarts WindowServer when memory exceeds emergency threshold
EMERGENCY_RESTART_ENABLED=true

#============================================================================
# NOTIFICATION SETTINGS
#============================================================================

# Enable system notifications
# Default: false (disabled per user request)
# Set to 'true' if you want popup notifications for WindowServer issues
NOTIFICATIONS_ENABLED=false

# Notification sound
# Options: Basso, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink
# Default: Funk
NOTIFICATION_SOUND="Funk"

#============================================================================
# THRESHOLD SETTINGS (Memory in MB)
#============================================================================

# Normal memory threshold
# Default: 500MB
# WindowServer using less than this is considered normal
MEM_THRESHOLD_NORMAL=500

# Warning threshold
# Default: 2048MB (2GB)
# Triggers warning but no automatic action
MEM_THRESHOLD_WARNING=2048

# Critical threshold
# Default: 5120MB (5GB)
# Triggers automatic fixes if AUTO_FIX_ENABLED=true
MEM_THRESHOLD_CRITICAL=5120

# Emergency threshold
# Default: 20480MB (20GB)
# Triggers emergency WindowServer restart if EMERGENCY_RESTART_ENABLED=true
MEM_THRESHOLD_EMERGENCY=20480

# CPU threshold
# Default: 50.0%
# Triggers warning when WindowServer CPU exceeds this value
CPU_THRESHOLD=50.0

# Memory growth rate threshold (MB per check interval)
# Default: 500MB
# Detects rapid memory leaks if memory grows faster than this
MEMORY_GROWTH_THRESHOLD=500

#============================================================================
# GPU MONITORING SETTINGS (v2.1.0 NEW)
#============================================================================

# Enable GPU memory tracking
# Default: true
# Tracks GPU VRAM usage separately from system RAM
GPU_MONITORING_ENABLED=true

# Enable page table leak detection
# Default: true
# Detects memory leaks at virtual memory page table level
PAGE_TABLE_MONITORING_ENABLED=true

# Enable compositor memory tracking
# Default: true
# Estimates window buffer memory usage
COMPOSITOR_MONITORING_ENABLED=true

# GPU memory leak threshold (MB)
# Default: 1024MB (1GB)
# Triggers warning if GPU memory grows beyond this without RSS growth
GPU_LEAK_THRESHOLD=1024

#============================================================================
# COOLDOWN SETTINGS
#============================================================================

# Cooldown period between automatic fixes (seconds)
# Default: 3600 (1 hour)
# Prevents fix loop by waiting this long between auto-fixes
COOLDOWN_PERIOD=3600

# Per-fix-type cooldowns (seconds)
# Different cooldown periods for different fix types
COOLDOWN_DOCK_RESTART=7200          # 2 hours
COOLDOWN_WINDOWSERVER_RESTART=3600  # 1 hour
COOLDOWN_IPHONE_MIRROR_KILL=1800    # 30 minutes
COOLDOWN_CACHE_CLEAR=1800           # 30 minutes

#============================================================================
# DATA RETENTION
#============================================================================

# Number of days to keep log files
# Default: 30
# Older logs will be automatically cleaned
LOG_RETENTION_DAYS=30

# Number of memory history samples to keep
# Default: 100
# Used for leak pattern detection
MEMORY_HISTORY_SIZE=100

# Number of diagnostic reports to keep
# Default: 10
# Older diagnostic files will be deleted
DIAGNOSTIC_RETENTION_COUNT=10

#============================================================================
# FEATURE FLAGS (Experimental)
#============================================================================

# Enable machine learning leak prediction
# Default: false (not yet implemented)
# Will be enabled in v3.0.0
ML_PREDICTION_ENABLED=false

# Enable kernel-level monitoring
# Default: false (requires SIP disable - not recommended)
# Only for advanced users
KERNEL_MONITORING_ENABLED=false

#============================================================================
# DISPLAY CONFIGURATION
#============================================================================

# Warn about ultra-wide displays (>5120px width)
# Default: true
ULTRAWIDE_WARNINGS_ENABLED=true

# Warn about ProMotion displays (120Hz)
# Default: true
PROMOTION_WARNINGS_ENABLED=true

# Warn about scaled resolutions
# Default: true
SCALED_RESOLUTION_WARNINGS_ENABLED=true

#============================================================================
# ADVANCED SETTINGS
#============================================================================

# Use Activity Monitor API for memory measurement
# Default: false (uses 'top' command)
# Experimental: May be more accurate but slower
USE_ACTIVITY_MONITOR_API=false

# Enable dual measurement validation (top + ps comparison)
# Default: true
# Compares 'top' and 'ps' output to detect measurement discrepancies
DUAL_MEASUREMENT_VALIDATION=true

# Maximum measurement discrepancy tolerance (percentage)
# Default: 20
# Log warning if 'top' and 'ps' differ by more than this percentage
MEASUREMENT_DISCREPANCY_THRESHOLD=20

#============================================================================
# END OF CONFIGURATION
#============================================================================

# DO NOT EDIT BELOW THIS LINE
export CHECK_INTERVAL
export VERBOSE_LOGGING
export AUTO_FIX_ENABLED
export DRY_RUN
export DOCK_RESTART_ENABLED
export EMERGENCY_RESTART_ENABLED
export NOTIFICATIONS_ENABLED
export NOTIFICATION_SOUND
export MEM_THRESHOLD_NORMAL
export MEM_THRESHOLD_WARNING
export MEM_THRESHOLD_CRITICAL
export MEM_THRESHOLD_EMERGENCY
export CPU_THRESHOLD
export MEMORY_GROWTH_THRESHOLD
export GPU_MONITORING_ENABLED
export PAGE_TABLE_MONITORING_ENABLED
export COMPOSITOR_MONITORING_ENABLED
export GPU_LEAK_THRESHOLD
export COOLDOWN_PERIOD
export COOLDOWN_DOCK_RESTART
export COOLDOWN_WINDOWSERVER_RESTART
export COOLDOWN_IPHONE_MIRROR_KILL
export COOLDOWN_CACHE_CLEAR
export LOG_RETENTION_DAYS
export MEMORY_HISTORY_SIZE
export DIAGNOSTIC_RETENTION_COUNT
export ML_PREDICTION_ENABLED
export KERNEL_MONITORING_ENABLED
export ULTRAWIDE_WARNINGS_ENABLED
export PROMOTION_WARNINGS_ENABLED
export SCALED_RESOLUTION_WARNINGS_ENABLED
export USE_ACTIVITY_MONITOR_API
export DUAL_MEASUREMENT_VALIDATION
export MEASUREMENT_DISCREPANCY_THRESHOLD
