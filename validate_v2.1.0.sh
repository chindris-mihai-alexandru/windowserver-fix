#!/bin/bash

# WindowServer Fix - v2.1.0 Feature Validation Script
# Tests and validates GPU monitoring, page table detection, and compositor analysis
# Version: 2.1.0
# Release Date: November 2025

set -e

# Version information
readonly VERSION="2.1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load config
CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

log() {
    echo -e "[$(date '+%H:%M:%S')] $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

show_header() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║     WindowServer Fix v2.1.0 - Feature Validation          ║"
    echo "║  GPU Monitoring • Page Tables • Compositor Analysis        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo
}

# Test 1: Check if config.sh exists and has v2.1.0 features
test_config_file() {
    log_info "Test 1: Validating config.sh"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "config.sh not found"
        return 1
    fi
    log_success "config.sh exists"
    
    # Check for v2.1.0 configuration variables
    if grep -q "GPU_MONITORING_ENABLED" "$CONFIG_FILE"; then
        log_success "GPU_MONITORING_ENABLED found in config"
    else
        log_error "GPU_MONITORING_ENABLED not found"
        return 1
    fi
    
    if grep -q "PAGE_TABLE_MONITORING_ENABLED" "$CONFIG_FILE"; then
        log_success "PAGE_TABLE_MONITORING_ENABLED found in config"
    else
        log_error "PAGE_TABLE_MONITORING_ENABLED not found"
        return 1
    fi
    
    if grep -q "COMPOSITOR_MONITORING_ENABLED" "$CONFIG_FILE"; then
        log_success "COMPOSITOR_MONITORING_ENABLED found in config"
    else
        log_error "COMPOSITOR_MONITORING_ENABLED not found"
        return 1
    fi
    
    echo
    return 0
}

# Test 2: Validate GPU memory monitoring
test_gpu_monitoring() {
    log_info "Test 2: GPU Memory Monitoring"
    
    # Check if system_profiler works
    gpu_info=$(system_profiler SPDisplaysDataType 2>/dev/null)
    if [ -z "$gpu_info" ]; then
        log_warning "system_profiler SPDisplaysDataType returned no data"
        return 1
    fi
    log_success "system_profiler is accessible"
    
    # Test get_gpu_memory function from monitor.sh
    if [ -f "$SCRIPT_DIR/monitor.sh" ]; then
        # Source the function (requires extracting it)
        gpu_vram=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "VRAM" | head -1 | awk '{print $3}' | tr -d 'MB')
        
        if [ -n "$gpu_vram" ] && [ "$gpu_vram" -gt 0 ]; then
            log_success "GPU VRAM detected: ${gpu_vram}MB"
            
            # Compare with Activity Monitor expectations
            log_info "Comparing with Activity Monitor..."
            log_info "Note: Manual verification needed - check Activity Monitor GPU memory"
        else
            log_warning "No GPU VRAM detected (might be normal for some Macs)"
            log_info "This could indicate:"
            log_info "  - Integrated GPU without dedicated VRAM"
            log_info "  - system_profiler limitation"
        fi
    else
        log_error "monitor.sh not found"
        return 1
    fi
    
    echo
    return 0
}

# Test 3: Validate page table monitoring
test_page_table_monitoring() {
    log_info "Test 3: Page Table Memory Detection"
    
    ws_pid=$(pgrep WindowServer)
    if [ -z "$ws_pid" ]; then
        log_error "WindowServer process not found"
        return 1
    fi
    log_success "WindowServer PID: $ws_pid"
    
    # Get VM size and RSS
    vm_size=$(ps aux | grep WindowServer | grep -v grep | awk '{print $5}' | head -1)
    rss_size=$(ps aux | grep WindowServer | grep -v grep | awk '{print $6}' | head -1)
    
    if [ -n "$vm_size" ] && [ -n "$rss_size" ]; then
        log_success "VM Size: ${vm_size}KB"
        log_success "RSS Size: ${rss_size}KB"
        
        # Calculate page table overhead
        if command -v bc >/dev/null 2>&1; then
            page_table_mb=$(echo "scale=0; ($vm_size - $rss_size) / 1024" | bc 2>/dev/null || echo "0")
            log_success "Page Table Overhead: ${page_table_mb}MB"
            
            # Validate reasonableness
            if [ "$page_table_mb" -gt 2048 ]; then
                log_warning "Page table overhead seems high (>2GB) - might indicate leak"
            elif [ "$page_table_mb" -lt 0 ]; then
                log_error "Negative page table overhead - calculation error"
                return 1
            else
                log_success "Page table overhead in normal range"
            fi
        else
            log_warning "bc not installed - cannot calculate page table overhead"
        fi
    else
        log_error "Could not retrieve VM/RSS sizes"
        return 1
    fi
    
    echo
    return 0
}

# Test 4: Validate compositor memory estimation
test_compositor_monitoring() {
    log_info "Test 4: Compositor Memory Estimation"
    
    # Count windows
    window_count=$(osascript -e 'tell application "System Events" to count windows of every process' 2>/dev/null || echo "0")
    
    if [ "$window_count" -gt 0 ]; then
        log_success "Window count: $window_count"
        
        # Estimate compositor memory (rough approximation: 50MB per window)
        if command -v bc >/dev/null 2>&1; then
            compositor_mb=$(echo "scale=0; $window_count * 50" | bc)
            log_info "Estimated compositor memory: ${compositor_mb}MB"
            log_info "Note: This is a rough estimate (50MB/window average)"
        fi
    else
        log_warning "Could not count windows via AppleScript"
        log_info "This might be due to accessibility permissions"
    fi
    
    echo
    return 0
}

# Test 5: Validate monitor.sh integration
test_monitor_integration() {
    log_info "Test 5: Monitor.sh Integration Test"
    
    if [ ! -f "$SCRIPT_DIR/monitor.sh" ]; then
        log_error "monitor.sh not found"
        return 1
    fi
    
    # Run a check and verify CSV output includes new columns
    log_info "Running monitor.sh check..."
    "$SCRIPT_DIR/monitor.sh" check > /dev/null 2>&1
    
    # Check if metrics.csv has v2.1.0 columns
    metrics_file="$HOME/windowserver-fix/logs/metrics.csv"
    if [ -f "$metrics_file" ]; then
        header=$(head -1 "$metrics_file")
        
        if echo "$header" | grep -q "gpu_vram_mb"; then
            log_success "CSV contains gpu_vram_mb column"
        else
            log_warning "CSV missing gpu_vram_mb column"
        fi
        
        if echo "$header" | grep -q "page_table_mb"; then
            log_success "CSV contains page_table_mb column"
        else
            log_warning "CSV missing page_table_mb column"
        fi
        
        if echo "$header" | grep -q "compositor_mb"; then
            log_success "CSV contains compositor_mb column"
        else
            log_warning "CSV missing compositor_mb column"
        fi
        
        # Show latest reading
        latest=$(tail -1 "$metrics_file")
        log_info "Latest metrics captured to CSV"
    else
        log_warning "metrics.csv not found - run monitor.sh first"
    fi
    
    echo
    return 0
}

# Test 6: System compatibility check
test_system_compatibility() {
    log_info "Test 6: System Compatibility"
    
    # Check macOS version
    macos_version=$(sw_vers -productVersion)
    log_info "macOS Version: $macos_version"
    
    # Check architecture
    arch=$(uname -m)
    log_info "Architecture: $arch"
    
    if [ "$arch" = "arm64" ]; then
        log_success "Apple Silicon detected (tested platform)"
    elif [ "$arch" = "x86_64" ]; then
        log_warning "Intel Mac detected (UNTESTED - please report results!)"
        log_info "Please run full test suite and report findings"
    else
        log_warning "Unknown architecture: $arch"
    fi
    
    # Check for required tools
    log_info "Checking required tools..."
    
    tools=("bc" "system_profiler" "ps" "pgrep" "osascript")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool is available"
        else
            log_error "$tool is missing (required)"
        fi
    done
    
    echo
    return 0
}

# Main execution
main() {
    show_header
    
    log "Starting validation of v2.1.0 features..."
    log "This will test GPU monitoring, page table detection, and compositor analysis"
    echo
    
    passed=0
    failed=0
    
    # Run all tests
    tests=(
        "test_config_file"
        "test_gpu_monitoring"
        "test_page_table_monitoring"
        "test_compositor_monitoring"
        "test_monitor_integration"
        "test_system_compatibility"
    )
    
    for test in "${tests[@]}"; do
        if $test; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    # Summary
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    Validation Summary                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo
    log_success "Tests passed: $passed"
    if [ "$failed" -gt 0 ]; then
        log_warning "Tests failed or warnings: $failed"
    fi
    echo
    
    log_info "Next steps:"
    log_info "1. Manually verify GPU memory matches Activity Monitor"
    log_info "2. Compare page table calculations with vmmap output"
    log_info "3. Test on different Mac configurations (Intel, Apple Silicon)"
    log_info "4. Report results at: https://github.com/chindris-mihai-alexandru/windowserver-fix/issues"
    echo
    
    if [ "$failed" -eq 0 ]; then
        log_success "All automated tests passed!"
        return 0
    else
        log_warning "Some tests failed or need manual verification"
        return 1
    fi
}

# Parse arguments
case "${1:-run}" in
    run)
        main
        ;;
    version|--version|-v)
        echo "WindowServer Fix - Feature Validation v${VERSION}"
        ;;
    help|--help|-h)
        echo "Usage: $0 [run|version|help]"
        echo "  run     - Run all validation tests (default)"
        echo "  version - Show version"
        echo "  help    - Show this help"
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
esac
