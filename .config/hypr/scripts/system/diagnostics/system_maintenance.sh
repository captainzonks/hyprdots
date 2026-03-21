#!/usr/bin/env bash
# =============================================================================
# System Maintenance and Stability
# =============================================================================
# Comprehensive system maintenance script for cleaning temp files, checking
# disk space, managing logs, and ensuring system health
#
# Dependencies: systemctl, journalctl
# =============================================================================

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_DIR="/home/$USER/.local/share/system_maintenance_logs"
readonly LOG_FILE="$LOG_DIR/maintenance_$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="/home/$USER/.config/system_backups"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}" | tee -a "$LOG_FILE"
}

# Helper function to safely get numeric value
get_numeric_value() {
    local input="$1"
    local default="${2:-0}"
    
    # Extract only numeric characters, take first line, default to 0
    local result=$(echo "$input" | head -1 | tr -d '\n' | grep -o '[0-9]*' | head -1 || echo "$default")
    
    # Ensure we have a valid number
    if [[ -z "$result" || ! "$result" =~ ^[0-9]+$ ]]; then
        result="$default"
    fi
    
    echo "$result"
}

# Helper function for safe arithmetic comparison
safe_compare() {
    local value1="$1"
    local operator="$2"
    local value2="$3"
    
    # Ensure both values are numeric
    value1=$(get_numeric_value "$value1" "0")
    value2=$(get_numeric_value "$value2" "0")
    
    case "$operator" in
        "-gt")
            [[ $value1 -gt $value2 ]]
            ;;
        "-lt")
            [[ $value1 -lt $value2 ]]
            ;;
        "-eq")
            [[ $value1 -eq $value2 ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check system health - ARITHMETIC FIXED
check_system_health() {
    print_status "$BLUE" "=== System Health Check ==="
    
    # Check for recent crashes
    local crash_count=$(journalctl --since="24 hours ago" -p err --no-pager 2>/dev/null | wc -l || echo "0")
    crash_count=$(get_numeric_value "$crash_count" "0")
    
    if safe_compare "$crash_count" "-gt" "10"; then
        print_status "$RED" "⚠ High error count in last 24h: $crash_count errors"
        log "Recent critical errors:"
        journalctl --since="24 hours ago" -p err --no-pager 2>/dev/null | tail -5 | while read -r line; do
            log "  $line"
        done || log "  Could not access recent error logs"
    else
        print_status "$GREEN" "✓ Error count normal: $crash_count errors in 24h"
    fi
    
    # Check USB controller status
    if journalctl --since="24 hours ago" --no-pager 2>/dev/null | grep -q "xHCI.*died"; then
        print_status "$RED" "⚠ USB controller issues detected in logs"
    else
        print_status "$GREEN" "✓ USB controllers appear stable"
    fi
    
    # Check AMD GPU status - FIXED arithmetic
    local gpu_errors_raw=$(journalctl --since="24 hours ago" --no-pager 2>/dev/null | grep "amdgpu.*ERROR" 2>/dev/null | wc -l || echo "0")
    local gpu_errors=$(get_numeric_value "$gpu_errors_raw" "0")
    
    if safe_compare "$gpu_errors" "-gt" "5"; then
        print_status "$YELLOW" "⚠ AMD GPU errors detected: $gpu_errors"
    else
        print_status "$GREEN" "✓ AMD GPU stable: $gpu_errors errors"
    fi
    
    # Check thermal status - FIXED arithmetic
    local cpu_temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    local cpu_temp=$(get_numeric_value "$cpu_temp_raw" "0")
    
    if [[ $cpu_temp -gt 0 ]]; then
        local temp_c=$((cpu_temp / 1000))
        if safe_compare "$temp_c" "-gt" "75"; then
            print_status "$YELLOW" "⚠ CPU temperature high: ${temp_c}°C"
        else
            print_status "$GREEN" "✓ CPU temperature normal: ${temp_c}°C"
        fi
    else
        print_status "$YELLOW" "⚠ CPU temperature unavailable"
    fi
    
    # Check memory usage - FIXED arithmetic
    local mem_usage_raw=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}' 2>/dev/null || echo "0")
    local mem_usage=$(get_numeric_value "$mem_usage_raw" "0")
    
    if safe_compare "$mem_usage" "-gt" "85"; then
        print_status "$YELLOW" "⚠ High memory usage: ${mem_usage}%"
    else
        print_status "$GREEN" "✓ Memory usage normal: ${mem_usage}%"
    fi
    
    # Check disk usage - FIXED arithmetic
    local disk_usage_raw=$(df / | awk 'NR==2 {print $5}' | sed 's/%//' || echo "0")
    local disk_usage=$(get_numeric_value "$disk_usage_raw" "0")
    
    if safe_compare "$disk_usage" "-gt" "90"; then
        print_status "$RED" "⚠ Root filesystem almost full: ${disk_usage}%"
    elif safe_compare "$disk_usage" "-gt" "80"; then
        print_status "$YELLOW" "⚠ Root filesystem getting full: ${disk_usage}%"
    else
        print_status "$GREEN" "✓ Disk usage normal: ${disk_usage}%"
    fi
}

# Function to clean up system - NO SUDO IN AUTO MODE
cleanup_system() {
    print_status "$BLUE" "=== System Cleanup ==="
    
    local auto_mode=${1:-false}
    
    if [[ "$auto_mode" == false ]]; then
        # Interactive mode
        print_status "$YELLOW" "Interactive mode: full system cleanup..."
        
        if command -v paccache >/dev/null 2>&1; then
            print_status "$YELLOW" "Cleaning package cache..."
            sudo paccache -r -k 3
            print_status "$GREEN" "✓ Package cache cleaned"
        fi
        
        local orphans=$(pacman -Qtdq 2>/dev/null || echo "")
        if [[ -n "$orphans" ]]; then
            print_status "$YELLOW" "Removing orphaned packages..."
            echo "$orphans" | sudo pacman -Rns --noconfirm -
            print_status "$GREEN" "✓ Orphaned packages removed"
        else
            print_status "$GREEN" "✓ No orphaned packages found"
        fi
    else
        # Automated mode - NO SUDO
        print_status "$YELLOW" "Automated mode: user-level cleanup only..."
        
        local orphans=$(pacman -Qtdq 2>/dev/null || echo "")
        if [[ -n "$orphans" ]]; then
            local orphan_count=$(echo "$orphans" | wc -l)
            orphan_count=$(get_numeric_value "$orphan_count" "0")
            print_status "$YELLOW" "⚠ Found $orphan_count orphaned packages (manual removal needed)"
            log "Orphaned packages found: $orphan_count"
        else
            print_status "$GREEN" "✓ No orphaned packages found"
        fi
    fi
    
    # User-level cleanup (always safe)
    print_status "$YELLOW" "Cleaning user caches..."
    
    if [[ -d "/home/$USER/.cache" ]]; then
        find "/home/$USER/.cache" -type f -atime +30 -delete 2>/dev/null || true
    fi
    
    for browser_cache in "/home/$USER/.cache/chromium" "/home/$USER/.cache/google-chrome" "/home/$USER/.cache/mozilla" "/home/$USER/.mozilla/firefox"; do
        if [[ -d "$browser_cache" ]]; then
            find "$browser_cache" -name "*.sqlite-wal" -delete 2>/dev/null || true
            find "$browser_cache" -name "*.sqlite-shm" -delete 2>/dev/null || true
            find "$browser_cache" -type f -atime +30 -delete 2>/dev/null || true
        fi
    done
    
    find /tmp -user "$USER" -type f -atime +7 -delete 2>/dev/null || true
    
    print_status "$GREEN" "✓ User caches cleaned"
}

# Function to check for updates - NO SUDO IN AUTO MODE
update_system() {
    print_status "$BLUE" "=== System Update Check ==="
    
    local auto_mode=${1:-false}
    
    if [[ "$auto_mode" == false ]]; then
        # Interactive mode
        print_status "$YELLOW" "Interactive mode: full update process..."
        local backup_date=$(date +%Y%m%d_%H%M%S)
        sudo rsync -av /etc/ "$BACKUP_DIR/etc_backup_$backup_date/" --exclude="shadow*" --exclude="passwd*" 2>/dev/null || true
        sudo pacman -Sy
        local updates=$(pacman -Qu | wc -l)
        updates=$(get_numeric_value "$updates" "0")
        
        if safe_compare "$updates" "-gt" "0"; then
            print_status "$YELLOW" "Available updates: $updates packages"
            sudo pacman -Su --noconfirm
            print_status "$GREEN" "✓ System updated successfully"
        else
            print_status "$GREEN" "✓ System is up to date"
        fi
    else
        # Automated mode - only check
        print_status "$YELLOW" "Automated mode: checking for available updates..."
        local updates=$(pacman -Qu 2>/dev/null | wc -l || echo "0")
        updates=$(get_numeric_value "$updates" "0")
        
        if safe_compare "$updates" "-gt" "0"; then
            print_status "$YELLOW" "⚠ $updates updates available (manual update recommended)"
            log "Updates available: $updates packages"
        else
            print_status "$GREEN" "✓ No updates available"
        fi
    fi
}

# Function to check configurations
check_configurations() {
    print_status "$BLUE" "=== Configuration Check ==="
    
    local auto_mode=${1:-false}
    
    local pacnew_files=$(find /etc -name "*.pacnew" 2>/dev/null || echo "")
    if [[ -n "$pacnew_files" ]]; then
        print_status "$YELLOW" "Found .pacnew files requiring attention:"
        echo "$pacnew_files" | while read -r file; do
            if [[ -n "$file" ]]; then
                log "  $file"
            fi
        done
        print_status "$YELLOW" "Use 'pacdiff' to merge configuration changes"
    else
        print_status "$GREEN" "✓ No .pacnew files found"
    fi
    
    if command -v tlp-stat >/dev/null 2>&1; then
        if [[ "$auto_mode" == false ]]; then
            if sudo tlp-stat -c >/dev/null 2>&1; then
                print_status "$GREEN" "✓ TLP configuration valid"
            else
                print_status "$YELLOW" "⚠ TLP configuration has warnings"
            fi
        else
            if systemctl is-active --quiet tlp.service 2>/dev/null; then
                print_status "$GREEN" "✓ TLP service is active"
            else
                print_status "$YELLOW" "⚠ TLP service is not active"
            fi
        fi
    fi
    
    local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l || echo "0")
    failed_services=$(get_numeric_value "$failed_services" "0")
    
    if safe_compare "$failed_services" "-gt" "0"; then
        print_status "$YELLOW" "⚠ Failed systemd services: $failed_services"
        systemctl --failed --no-legend 2>/dev/null | while read -r line; do
            if [[ -n "$line" ]]; then
                log "  Failed: $line"
            fi
        done || log "  Could not list failed services"
    else
        print_status "$GREEN" "✓ No failed systemd services"
    fi
}

# Function to create summary
create_summary() {
    print_status "$BLUE" "=== Maintenance Summary ==="
    
    local auto_mode=${1:-false}
    local summary_file="/home/$USER/.local/share/maintenance_summary.txt"
    mkdir -p "$(dirname "$summary_file")"
    
    local system_hostname=$(cat /etc/hostname 2>/dev/null || echo "unknown")
    
    {
        echo "System Maintenance Summary - $(date)"
        echo "=========================================="
        echo ""
        echo "Maintenance Mode: $(if [[ "$auto_mode" == true ]]; then echo "Automated (limited privileges)"; else echo "Interactive (full privileges)"; fi)"
        echo ""
        echo "System Information:"
        echo "  Hostname: $system_hostname"
        echo "  Kernel: $(uname -r)"
        echo "  Uptime: $(uptime -p 2>/dev/null || echo "unknown")"
        echo "  Load Average: $(uptime 2>/dev/null | awk -F'load average:' '{print $2}' || echo "unknown")"
        echo ""
        echo "Disk Usage:"
        df -h 2>/dev/null | grep -E "^/dev" || echo "  Disk usage unavailable"
        echo ""
        echo "Memory Usage:"
        free -h 2>/dev/null || echo "  Memory info unavailable"
        echo ""
        if [[ "$auto_mode" == true ]]; then
            echo "Automated Mode Limitations:"
            echo "  - System updates: checked only, not installed"
            echo "  - Package cleanup: user-level only"
            echo "  - System optimization: status check only"
            echo "  - Manual maintenance recommended for full cleanup"
            echo ""
        fi
        echo "Recent Errors (last 24h):"
        journalctl --since="24 hours ago" -p err --no-pager 2>/dev/null | tail -5 || echo "  Error log unavailable"
        echo ""
        echo "Next Maintenance Recommended: $(date -d '+1 week' 2>/dev/null || echo "1 week from now")"
    } > "$summary_file"
    
    print_status "$GREEN" "✓ Maintenance summary saved to $summary_file"
}

# Main function
main() {
    print_status "$PURPLE" "=== ThinkPad System Maintenance Script - ARITHMETIC FIXED ==="
    print_status "$BLUE" "Log file: $LOG_FILE"
    
    local auto_mode=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                auto_mode=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--auto] [--help]"
                echo "  --auto    Run in automated mode (no prompts, no sudo)"
                echo "  --help    Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_system_health
    
    if [[ "$auto_mode" == false ]]; then
        read -p "Proceed with system cleanup? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            cleanup_system false
        fi
        
        read -p "Proceed with system update check? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            update_system false
        fi
    else
        print_status "$YELLOW" "Running in automated mode - performing safe maintenance tasks only"
        cleanup_system true
        update_system true
    fi
    
    check_configurations "$auto_mode"
    create_summary "$auto_mode"
    
    print_status "$GREEN" "=== Maintenance completed successfully ==="
    print_status "$YELLOW" "Check /home/$USER/.local/share/maintenance_summary.txt for detailed summary"
}

main "$@"
