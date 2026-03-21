#!/usr/bin/env bash
# =============================================================================
# USB-C Power Delivery Monitor
# =============================================================================
# Monitors USB-C PD negotiation and detects potential hardware failures
# Diagnostics tool for USB Type-C connections and power delivery
#
# Dependencies: udevadm, sysfs
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
readonly LOG_FILE="/var/log/usbc_pd_monitor_$(date +%Y%m%d_%H%M%S).log"
readonly MONITOR_INTERVAL=5

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}" | tee -a "$LOG_FILE"
}

# Function to check USB-C PD hardware
check_usbc_hardware() {
    print_status "$BLUE" "=== USB-C Hardware Detection ==="
    
    # Check for Type-C subsystem support
    if [[ -d /sys/class/typec ]]; then
        print_status "$GREEN" "✓ USB Type-C subsystem detected"
        
        # List Type-C ports
        local port_count=0
        for port in /sys/class/typec/port*; do
            if [[ -d "$port" ]]; then
                port_count=$((port_count + 1))
                local port_name=$(basename "$port")
                log "Port $port_count: $port_name"
                
                # Check port capabilities
                if [[ -f "$port/power_role" ]]; then
                    local power_role=$(cat "$port/power_role" 2>/dev/null || echo "unknown")
                    log "  Power role: $power_role"
                fi
                
                if [[ -f "$port/data_role" ]]; then
                    local data_role=$(cat "$port/data_role" 2>/dev/null || echo "unknown")
                    log "  Data role: $data_role"
                fi
                
                if [[ -f "$port/preferred_role" ]]; then
                    local preferred_role=$(cat "$port/preferred_role" 2>/dev/null || echo "unknown")
                    log "  Preferred role: $preferred_role"
                fi
                
                # Check for connected partners
                if [[ -d "$port"/port*-partner ]]; then
                    log "  Partner connected"
                    for partner in "$port"/port*-partner; do
                        if [[ -f "$partner/identity" ]]; then
                            local identity=$(cat "$partner/identity" 2>/dev/null || echo "unknown")
                            log "    Partner identity: $identity"
                        fi
                    done
                fi
            fi
        done
        
        if [[ $port_count -eq 0 ]]; then
            print_status "$YELLOW" "⚠ No USB-C ports detected in kernel"
        else
            print_status "$GREEN" "✓ Found $port_count USB-C port(s)"
        fi
    else
        print_status "$YELLOW" "⚠ USB Type-C subsystem not available"
        log "This may indicate:"
        log "  - Kernel compiled without USB Type-C support"
        log "  - No USB-C controllers detected"
        log "  - Driver not loaded"
    fi
    
    # Check for UCSI (USB Type-C Connector System Software Interface)
    if [[ -d /sys/bus/platform/drivers/ucsi_acpi ]]; then
        print_status "$GREEN" "✓ UCSI ACPI interface detected"
        
        # List UCSI devices
        for device in /sys/bus/platform/drivers/ucsi_acpi/*; do
            if [[ -d "$device" && ! "$device" =~ (bind|unbind|uevent|new_id|remove_id)$ ]]; then
                local device_name=$(basename "$device")
                log "UCSI device: $device_name"
            fi
        done
    else
        print_status "$YELLOW" "⚠ UCSI ACPI interface not found"
        log "This may indicate older firmware or non-UCSI USB-C implementation"
    fi
    
    # Check for USB-C power supplies
    print_status "$BLUE" "USB-C Power Delivery power supplies:"
    local pd_supplies=0
    for ps in /sys/class/power_supply/*; do
        if [[ -f "$ps/type" ]]; then
            local ps_type=$(cat "$ps/type" 2>/dev/null || echo "unknown")
            local ps_name=$(basename "$ps")
            
            # Look for USB-C related power supplies
            if [[ "$ps_name" =~ (usb|ucsi|typec|ADP1) ]] || [[ "$ps_type" == "USB" ]]; then
                pd_supplies=$((pd_supplies + 1))
                log "  $ps_name: $ps_type"
                
                # Get additional info
                if [[ -f "$ps/online" ]]; then
                    local online=$(cat "$ps/online" 2>/dev/null || echo "unknown")
                    log "    Online: $online"
                fi
                
                if [[ -f "$ps/voltage_now" ]]; then
                    local voltage=$(cat "$ps/voltage_now" 2>/dev/null || echo "0")
                    if [[ "$voltage" != "0" ]]; then
                        voltage=$((voltage / 1000000))
                        log "    Voltage: ${voltage}V"
                    fi
                fi
                
                if [[ -f "$ps/current_now" ]]; then
                    local current=$(cat "$ps/current_now" 2>/dev/null || echo "0")
                    if [[ "$current" != "0" ]]; then
                        current=$((current / 1000000))
                        log "    Current: ${current}A"
                    fi
                fi
            fi
        fi
    done
    
    if [[ $pd_supplies -eq 0 ]]; then
        print_status "$YELLOW" "⚠ No USB-C power supplies detected"
    else
        print_status "$GREEN" "✓ Found $pd_supplies USB-C power supply/supplies"
    fi
}

# Function to monitor USB-C PD events
monitor_usbc_events() {
    print_status "$BLUE" "=== USB-C Event Monitoring ==="
    print_status "$YELLOW" "Monitoring USB-C events... (Press Ctrl+C to stop)"
    
    # Create a temporary file for dmesg baseline
    local dmesg_baseline="/tmp/dmesg_baseline_$(date +%s)"
    dmesg > "$dmesg_baseline"
    
    # Monitor loop
    local iteration=0
    while true; do
        iteration=$((iteration + 1))
        
        # Check for new kernel messages
        local new_messages=$(mktemp)
        dmesg | diff "$dmesg_baseline" - | grep "^>" | sed 's/^> //' > "$new_messages" || true
        
        if [[ -s "$new_messages" ]]; then
            # Look for USB-C/PD related messages
            if grep -iE "(typec|ucsi|usb.*c|xhci|power.*delivery|pd)" "$new_messages" >/dev/null 2>&1; then
                print_status "$YELLOW" "New USB-C related kernel messages:"
                grep -iE "(typec|ucsi|usb.*c|xhci|power.*delivery|pd)" "$new_messages" | while read -r line; do
                    log "  $line"
                    # Check for error conditions
                    if echo "$line" | grep -iE "(error|fail|died|fault|timeout)" >/dev/null; then
                        print_status "$RED" "⚠ ERROR detected: $line"
                        notify-send -u critical "USB-C Error" "$line" 2>/dev/null || true
                    fi
                done
            fi
            
            # Update baseline
            dmesg > "$dmesg_baseline"
        fi
        
        # Check USB-C port status changes
        if [[ -d /sys/class/typec ]]; then
            for port in /sys/class/typec/port*; do
                if [[ -d "$port" ]]; then
                    local port_name=$(basename "$port")
                    
                    # Check for partner changes
                    local partner_status="disconnected"
                    if [[ -d "$port"/port*-partner ]]; then
                        partner_status="connected"
                    fi
                    
                    # Store/compare previous state (simplified for this example)
                    local state_file="/tmp/usbc_${port_name}_state"
                    if [[ -f "$state_file" ]]; then
                        local prev_state=$(cat "$state_file")
                        if [[ "$prev_state" != "$partner_status" ]]; then
                            log "Port $port_name: $prev_state -> $partner_status"
                            if [[ "$partner_status" == "connected" ]]; then
                                print_status "$GREEN" "✓ USB-C device connected to $port_name"
                            else
                                print_status "$YELLOW" "⚠ USB-C device disconnected from $port_name"
                            fi
                        fi
                    fi
                    echo "$partner_status" > "$state_file"
                fi
            done
        fi
        
        # Check system health indicators
        if [[ $((iteration % 12)) -eq 0 ]]; then  # Every minute
            local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
            if [[ $temp -gt 80000 ]]; then  # 80°C
                print_status "$YELLOW" "⚠ High temperature: $((temp/1000))°C"
            fi
            
            # Check for USB controller status
            if dmesg | tail -20 | grep -i "xhci.*died" >/dev/null 2>&1; then
                print_status "$RED" "⚠ USB controller failure detected!"
                break
            fi
        fi
        
        rm -f "$new_messages"
        sleep $MONITOR_INTERVAL
    done
    
    rm -f "$dmesg_baseline"
}

# Function to run diagnostics
run_diagnostics() {
    print_status "$BLUE" "=== USB-C Power Delivery Diagnostics ==="
    
    # Check kernel support
    log "Kernel version: $(uname -r)"
    log "Kernel command line:"
    cat /proc/cmdline | tr ' ' '\n' | while read -r param; do
        if [[ "$param" =~ (usb|typec|acpi|iommu|amd) ]]; then
            log "  $param"
        fi
    done
    
    # Check loaded modules
    log "USB-C related loaded modules:"
    lsmod | grep -iE "(typec|ucsi|usb|xhci)" | while read -r line; do
        log "  $line"
    done
    
    # Check PCI devices
    log "PCI USB controllers:"
    lspci | grep -iE "(usb|thunderbolt)" | while read -r line; do
        log "  $line"
    done
    
    # Check recent errors
    log "Recent USB-C related errors in kernel log:"
    dmesg | grep -iE "(typec|ucsi|xhci).*error" | tail -5 | while read -r line; do
        log "  $line"
    done
    
    # Check ACPI devices
    if [[ -d /sys/bus/acpi/devices ]]; then
        log "ACPI devices related to USB-C:"
        find /sys/bus/acpi/devices -name "*USB*" -o -name "*TBT*" -o -name "*UCSI*" 2>/dev/null | while read -r device; do
            local device_name=$(basename "$device")
            log "  $device_name"
        done
    fi
}

# Function to test USB-C PD functionality
test_pd_functionality() {
    print_status "$BLUE" "=== USB-C PD Functionality Test ==="
    
    if [[ ! -d /sys/class/typec ]]; then
        print_status "$YELLOW" "⚠ USB Type-C subsystem not available - cannot test PD"
        return 1
    fi
    
    print_status "$YELLOW" "Testing USB-C power delivery..."
    print_status "$BLUE" "Please connect/disconnect your USB-C power cable now"
    print_status "$BLUE" "Monitoring for 30 seconds..."
    
    local test_start=$(date +%s)
    local test_duration=30
    local events_detected=0
    
    # Monitor for PD events during test
    while [[ $(($(date +%s) - test_start)) -lt $test_duration ]]; do
        # Check for new kernel messages
        if dmesg | tail -5 | grep -iE "(typec|ucsi|power.*delivery)" >/dev/null 2>&1; then
            events_detected=$((events_detected + 1))
            print_status "$GREEN" "✓ USB-C event detected"
        fi
        
        # Check for errors
        if dmesg | tail -5 | grep -iE "(xhci.*error|xhci.*died|iommu.*fault)" >/dev/null 2>&1; then
            print_status "$RED" "✗ USB controller error detected during test!"
            log "Error details:"
            dmesg | tail -5 | grep -iE "(error|died|fault)" | while read -r line; do
                log "  $line"
            done
            return 1
        fi
        
        sleep 1
    done
    
    if [[ $events_detected -gt 0 ]]; then
        print_status "$GREEN" "✓ USB-C PD appears functional ($events_detected events detected)"
    else
        print_status "$YELLOW" "⚠ No USB-C events detected - may indicate hardware issue"
    fi
    
    return 0
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTION]

USB-C Power Delivery Monitor and Diagnostic Tool

OPTIONS:
    --monitor       Start continuous monitoring mode
    --test          Run USB-C PD functionality test
    --diagnose      Run comprehensive diagnostics
    --hardware      Check USB-C hardware detection
    --help          Show this help message

EXAMPLES:
    $SCRIPT_NAME --hardware     # Check hardware detection
    $SCRIPT_NAME --diagnose     # Run full diagnostics
    $SCRIPT_NAME --monitor      # Start continuous monitoring
    $SCRIPT_NAME --test         # Test PD functionality

LOG FILE:
    $LOG_FILE
EOF
}

# Main function
main() {
    print_status "$PURPLE" "=== USB-C Power Delivery Monitor v1.0.0 ==="
    print_status "$BLUE" "Log file: $LOG_FILE"
    
    # Parse command line arguments
    case "${1:---hardware}" in
        --monitor)
            run_diagnostics
            check_usbc_hardware
            monitor_usbc_events
            ;;
        --test)
            run_diagnostics
            check_usbc_hardware
            test_pd_functionality
            ;;
        --diagnose)
            run_diagnostics
            check_usbc_hardware
            ;;
        --hardware)
            check_usbc_hardware
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
    
    print_status "$GREEN" "=== USB-C PD monitoring completed ==="
    print_status "$YELLOW" "Check $LOG_FILE for detailed logs"
}

# Execute main function
main "$@"
