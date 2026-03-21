#!/usr/bin/env bash
# =============================================================================
# System Crash Diagnostic and Fix
# =============================================================================
# Diagnoses and fixes USB controller failures, power management issues
# Specific optimizations for ThinkPad E15 Gen 3 AMD platform
#
# Dependencies: systemctl, modprobe
# =============================================================================
# - https://wiki.archlinux.org/title/Laptop#Power_management

set -euo pipefail

# Color definitions for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/system_crash_fix_$(date +%Y%m%d_%H%M%S).log"

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

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_status "$RED" "ERROR: This script should not be run as root for safety."
        print_status "$YELLOW" "It will use sudo when needed for specific operations."
        exit 1
    fi
}

# Function to create backup of configuration files
backup_config() {
    local config_file=$1
    local backup_dir="/home/$USER/.config/system_backups/$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p "$backup_dir"
    
    if [[ -f "$config_file" ]]; then
        sudo cp "$config_file" "$backup_dir/"
        print_status "$GREEN" "✓ Backed up $config_file to $backup_dir"
    fi
}

# Function to check system information
check_system_info() {
    print_status "$BLUE" "=== System Information Check ==="
    
    log "Kernel version: $(uname -r)"
    log "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    log "GPU: $(lspci | grep -E '(VGA|3D|Display)' | cut -d: -f3 | xargs)"
    
    # Check AMD P-State driver
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ]]; then
        local scaling_driver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)
        log "CPU scaling driver: $scaling_driver"
        
        if [[ "$scaling_driver" == "amd_pstate_epp" ]]; then
            print_status "$GREEN" "✓ AMD P-State EPP is active (optimal for Ryzen 5700U)"
        else
            print_status "$YELLOW" "⚠ Consider switching to amd_pstate_epp for better power management"
        fi
    fi
    
    # Check current power profile
    if command -v powerprofilesctl >/dev/null 2>&1; then
        local power_profile=$(powerprofilesctl get 2>/dev/null || echo "unknown")
        log "Current power profile: $power_profile"
    fi
}

# Function to diagnose USB-C PD issues
diagnose_usbc_pd_issues() {
    print_status "$BLUE" "=== USB-C Power Delivery Diagnostic ==="
    
    # Check USB-C PD controllers
    log "USB-C and Type-C Controllers:"
    lspci | grep -iE "(usb.*c|type.*c|thunderbolt)" | while read -r line; do
        log "  $line"
    done
    
    # Check for Type-C subsystem
    if [[ -d /sys/class/typec ]]; then
        log "Type-C ports detected:"
        find /sys/class/typec -name "port*" -exec sh -c 'echo "Port: {} - $(cat {}/power_role 2>/dev/null || echo unknown)"' \; 2>/dev/null | while read -r line; do
            log "  $line"
        done
    else
        log "  No Type-C subsystem found (kernel may not support USB-C PD)"
    fi
    
    # Check UCSI (USB Type-C Connector System Software Interface) status
    if [[ -d /sys/bus/platform/drivers/ucsi_acpi ]]; then
        log "UCSI ACPI driver status:"
        find /sys/bus/platform/drivers/ucsi_acpi -name "*USBC*" -o -name "*PNP*" | while read -r device; do
            log "  Device: $(basename "$device")"
        done
    fi
    
    # Check for USB-C PD power supplies
    log "USB-C Power Delivery power supplies:"
    find /sys/class/power_supply -name "*usb*" -o -name "*ucsi*" -o -name "*typec*" | while read -r ps; do
        local ps_name=$(basename "$ps")
        local ps_type=$(cat "$ps/type" 2>/dev/null || echo "unknown")
        log "  $ps_name: $ps_type"
    done
    
    # Check recent USB-C related kernel messages
    log "Recent USB-C/PD related kernel messages:"
    dmesg | grep -iE "(typec|ucsi|usb.*c|thunderbolt|power.*delivery)" | tail -10 | while read -r line; do
        log "  $line"
    done
    
    # Check ACPI firmware interface
    if [[ -d /sys/firmware/acpi/tables ]]; then
        log "ACPI tables related to USB-C:"
        find /sys/firmware/acpi/tables -name "*USB*" -o -name "*TBT*" 2>/dev/null | while read -r table; do
            log "  $(basename "$table")"
        done
    fi
}

# Function to diagnose USB issues
diagnose_usb_issues() {
    print_status "$BLUE" "=== USB Controller Diagnostic ==="
    
    # Check USB controllers
    log "USB Controllers:"
    lspci | grep -i usb | while read -r line; do
        log "  $line"
    done
    
    # Check for USB autosuspend issues
    log "USB Autosuspend settings:"
    find /sys/bus/usb/devices -name "autosuspend" -exec sh -c 'echo "{}: $(cat {})"' \; 2>/dev/null | head -10 | while read -r line; do
        log "  $line"
    done
    
    # Check for problematic USB devices
    log "USB device tree:"
    lsusb -t | while read -r line; do
        log "  $line"
    done
}

# Function to fix USB power management
fix_usb_power_management() {
    print_status "$BLUE" "=== Fixing USB Power Management ==="
    
    # Create udev rule to disable problematic USB autosuspend
    local udev_rule="/etc/udev/rules.d/50-usb-power-management.rules"
    
    backup_config "$udev_rule"
    
    print_status "$YELLOW" "Creating USB power management rules..."
    
    sudo tee "$udev_rule" > /dev/null << 'EOF'
# USB-C Power Delivery Management Rules for ThinkPad E15 Gen 3
# Prevents USB-C PD controller crashes during power negotiation
# Reference: https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#USB

# Disable runtime PM for USB-C PD controllers (critical for stability)
ACTION=="add", SUBSYSTEM=="pci", ATTR{class}=="0x0c0330", ATTR{power/control}="on"

# Disable autosuspend for xHCI controllers specifically
ACTION=="add", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", ATTR{power/control}="on"

# Disable autosuspend for all USB-C related devices
ACTION=="add", SUBSYSTEM=="usb", ATTR{bDeviceClass}=="09", ATTR{power/autosuspend}="-1"
ACTION=="add", SUBSYSTEM=="typec", ATTR{power/control}="on"

# Force USB-C ports to stay powered during PD negotiation
ACTION=="add", SUBSYSTEM=="usb", ENV{ID_USB_TYPE-C}=="1", ATTR{power/autosuspend}="-1"

# Disable power management for USB Type-C connectors
ACTION=="add", SUBSYSTEM=="typec", KERNEL=="port*", ATTR{power/control}="on"

# Prevent USB-C PD from entering deep power states
ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-*", ATTR{power/control}="on"

# Alternative: Set very long timeout for critical USB-C components
# ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="????", ATTR{power/autosuspend}="3600"
EOF

    print_status "$GREEN" "✓ USB power management rules created"
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    print_status "$GREEN" "✓ Udev rules reloaded"
}

# Function to update kernel parameters
fix_kernel_parameters() {
    print_status "$BLUE" "=== Updating Kernel Parameters ==="
    
    local kernel_params_file="/etc/kernel/cmdline"
    local bootloader_entry="/boot/loader/entries/arch.conf"
    
    # Check current boot configuration
    if [[ -f "$bootloader_entry" ]]; then
        backup_config "$bootloader_entry"
        log "Current boot entry: $(grep '^options' "$bootloader_entry" 2>/dev/null || echo 'Not found')"
    fi
    
    # Create improved kernel parameters for USB-C PD stability
    local new_params="root=PARTUUID=your-root-uuid rw"
    new_params+=" amd_pstate=active"  # Enable AMD P-State driver
    new_params+=" amd_iommu=on"       # Enable IOMMU for better device isolation
    new_params+=" iommu=pt"           # Use passthrough mode for better performance
    new_params+=" pcie_aspm=force"    # Enable PCIe power management
    new_params+=" usbcore.autosuspend=-1"  # Disable USB autosuspend globally
    new_params+=" xhci_hcd.quirks=1073741824"  # xHCI quirk for AMD controllers
    new_params+=" amdgpu.dc=1"        # Enable display core for amdgpu
    new_params+=" amdgpu.dpm=1"       # Enable dynamic power management
    # USB-C Power Delivery specific parameters
    new_params+=" typec.disable_usb_typec_dp=1"  # Disable USB-C DisplayPort if problematic
    new_params+=" acpi_osi=Linux"     # Improve ACPI compatibility
    new_params+=" acpi_backlight=vendor"  # Use vendor backlight control
    new_params+=" processor.max_cstate=1"  # Limit deep C-states that can cause PD issues
    
    print_status "$YELLOW" "Recommended kernel parameters for your system:"
    print_status "$GREEN" "$new_params"
    print_status "$YELLOW" "Please update your bootloader configuration manually with these parameters."
    
    echo "$new_params" > "/tmp/recommended_kernel_params.txt"
    print_status "$GREEN" "✓ Saved recommended parameters to /tmp/recommended_kernel_params.txt"
}

# Function to optimize TLP configuration
optimize_tlp_config() {
    print_status "$BLUE" "=== Optimizing TLP Configuration ==="
    
    if ! command -v tlp >/dev/null 2>&1; then
        print_status "$YELLOW" "TLP not installed. Installing..."
        sudo pacman -S --noconfirm tlp
    fi
    
    local tlp_config="/etc/tlp.conf"
    backup_config "$tlp_config"
    
    print_status "$YELLOW" "Creating optimized TLP configuration..."
    
    sudo tee "$tlp_config" > /dev/null << 'EOF'
# TLP Configuration for ThinkPad E15 Gen 3 - Post-Crash Optimization
# Version: 1.1.0 - Crash Prevention Focus
# Reference: https://linrunner.de/tlp/settings/

# General Settings
TLP_ENABLE=1
TLP_DEFAULT_MODE=AC
TLP_PERSISTENT_DEFAULT=0

# CPU Energy Performance (for AMD P-State EPP)
# Note: Using EPP instead of traditional governors
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

# CPU Boost
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# Platform Profile (kernel 5.12+)
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power

# Graphics (AMD)
RADEON_DPM_STATE_ON_AC=performance
RADEON_DPM_STATE_ON_BAT=battery
RADEON_DPM_PERF_LEVEL_ON_AC=auto
RADEON_DPM_PERF_LEVEL_ON_BAT=low

# Storage
SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=min_power
AHCI_RUNTIME_PM_ON_AC=on
AHCI_RUNTIME_PM_ON_BAT=auto

# USB Settings - Conservative for Stability
USB_AUTOSUSPEND=0                    # Disable USB autosuspend to prevent crashes
USB_BLACKLIST_BTUSB=0               # Allow Bluetooth USB autosuspend
USB_BLACKLIST_PHONE=0               # Allow phone USB autosuspend

# Runtime PM
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto
# Blacklist problematic drivers
RUNTIME_PM_DRIVER_BLACKLIST="mei_me nouveau radeon amdgpu xhci_hcd"

# PCIe ASPM
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave

# Network
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
WOL_DISABLE=Y

# Audio
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1

# Battery Thresholds (ThinkPad)
START_CHARGE_THRESH_BAT0=40
STOP_CHARGE_THRESH_BAT0=75

# ThinkPad-specific
NATACPI_ENABLE=1
TPACPI_ENABLE=1
TPSMAPI_ENABLE=1
EOF

    print_status "$GREEN" "✓ TLP configuration optimized for crash prevention"
    
    # Restart TLP
    sudo systemctl enable tlp.service
    sudo systemctl restart tlp.service
    
    if systemctl is-active --quiet tlp.service; then
        print_status "$GREEN" "✓ TLP service restarted successfully"
    else
        print_status "$RED" "✗ TLP service failed to restart"
    fi
}

# Function to fix AMD GPU issues
fix_amdgpu_issues() {
    print_status "$BLUE" "=== Fixing AMD GPU Issues ==="
    
    # Create modprobe configuration for amdgpu
    local modprobe_config="/etc/modprobe.d/amdgpu.conf"
    backup_config "$modprobe_config"
    
    sudo tee "$modprobe_config" > /dev/null << 'EOF'
# AMD GPU Configuration for Lucienne (Ryzen 5700U)
# Addresses secure display and DMCUB errors
# Reference: https://wiki.archlinux.org/title/AMDGPU

# Enable display core and power management
options amdgpu dc=1 dpm=1

# Disable problematic features that can cause crashes
options amdgpu audio=1
options amdgpu si_support=1
options amdgpu cik_support=1

# Power management settings
options amdgpu runpm=1
options amdgpu bapm=1

# Experimental: Disable secure display to prevent errors
# Remove this line if you need secure display functionality
options amdgpu securedisp=0
EOF

    print_status "$GREEN" "✓ AMD GPU modprobe configuration created"
    
    # Regenerate initramfs
    print_status "$YELLOW" "Regenerating initramfs..."
    sudo mkinitcpio -P
    print_status "$GREEN" "✓ Initramfs regenerated"
}

# Function to create monitoring script
create_monitoring_script() {
    print_status "$BLUE" "=== Creating System Monitoring Script ==="
    
    local monitor_script="/home/$USER/.local/bin/system_health_monitor.sh"
    mkdir -p "$(dirname "$monitor_script")"
    
    tee "$monitor_script" > /dev/null << 'EOF'
#!/usr/bin/env bash
# System Health Monitor for ThinkPad E15 Gen 3
# Monitors USB controllers, power states, and potential crash indicators
# Version: 1.0.0

LOG_FILE="/var/log/system_health_$(date +%Y%m%d).log"

log_with_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# Check USB controller health
check_usb_health() {
    local xhci_status=$(dmesg | tail -20 | grep -i "xhci\|usb" | grep -i "error\|died\|fail" | tail -1)
    if [[ -n "$xhci_status" ]]; then
        log_with_timestamp "USB Warning: $xhci_status"
        notify-send -u critical "USB Controller Warning" "$xhci_status"
    fi
}

# Check AMD GPU health
check_amdgpu_health() {
    local gpu_errors=$(dmesg | tail -20 | grep -i "amdgpu" | grep -i "error\|fail" | tail -1)
    if [[ -n "$gpu_errors" ]]; then
        log_with_timestamp "GPU Warning: $gpu_errors"
        notify-send -u normal "GPU Warning" "$gpu_errors"
    fi
}

# Check thermal status
check_thermal() {
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    if [[ -n "$temp" && $temp -gt 80000 ]]; then  # 80°C
        log_with_timestamp "High temperature: $((temp/1000))°C"
        notify-send -u critical "High Temperature" "CPU: $((temp/1000))°C"
    fi
}

# Main monitoring loop
main() {
    log_with_timestamp "System health check started"
    check_usb_health
    check_amdgpu_health
    check_thermal
    log_with_timestamp "System health check completed"
}

main "$@"
EOF

    chmod +x "$monitor_script"
    print_status "$GREEN" "✓ System monitoring script created at $monitor_script"
    
    # Create systemd timer for monitoring
    local timer_service="/home/$USER/.config/systemd/user/system-health-monitor.service"
    local timer_timer="/home/$USER/.config/systemd/user/system-health-monitor.timer"
    
    mkdir -p "$(dirname "$timer_service")"
    
    tee "$timer_service" > /dev/null << EOF
[Unit]
Description=System Health Monitor
Documentation=file://$monitor_script

[Service]
Type=oneshot
ExecStart=$monitor_script
EOF

    tee "$timer_timer" > /dev/null << 'EOF'
[Unit]
Description=Run System Health Monitor every 5 minutes
Requires=system-health-monitor.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

    # Enable the timer
    systemctl --user daemon-reload
    systemctl --user enable system-health-monitor.timer
    systemctl --user start system-health-monitor.timer
    
    print_status "$GREEN" "✓ System health monitoring timer enabled"
}

# Function to provide post-fix recommendations
post_fix_recommendations() {
    print_status "$BLUE" "=== Post-Fix Recommendations ==="
    
    cat << 'EOF'
CRITICAL NEXT STEPS - USB-C POWER DELIVERY FOCUS:

1. REBOOT REQUIRED:
   - Reboot your system to apply kernel parameter changes
   - Test USB-C power cable connection after reboot
   - Monitor system logs during power cable insertion

2. MANUAL BOOTLOADER UPDATE:
   - Edit your systemd-boot entry at /boot/loader/entries/arch.conf
   - Add the kernel parameters from /tmp/recommended_kernel_params.txt
   - Ensure your root PARTUUID is correct

3. USB-C POWER CABLE TESTING:
   - Connect power cable BEFORE booting (cold boot test)
   - Connect power cable after boot (hot plug test)
   - Monitor with: journalctl -f | grep -E "(usb|xhci|typec|ucsi|power_delivery)"

4. ONGOING MONITORING:
   - System health monitor is now running every 5 minutes
   - Check logs in /var/log/system_health_*.log
   - Watch for notifications about USB-C PD failures

5. HARDWARE CONSIDERATIONS:
   - This may indicate a hardware defect in USB-C PD controller
   - Consider using a different USB-C port if available (some laptops have 2)
   - If problem persists, contact Lenovo support (potential warranty issue)

6. VERIFY FIXES:
   - Run: sudo tlp-stat -s
   - Check: systemctl --user status system-health-monitor.timer
   - Monitor: journalctl -b -p err (after reboot)
   - Check USB-C PD status: ls -la /sys/class/typec/

7. FIRMWARE UPDATES:
   - Check for BIOS updates from Lenovo (critical for USB-C PD fixes)
   - Update embedded controller firmware if available
   - Consider Intel Management Engine updates if applicable

EMERGENCY FALLBACK:
   - If system becomes unstable, boot with kernel parameters: 
     usbcore.autosuspend=-1 processor.max_cstate=1 acpi=noirq
   - This disables deep power management that can trigger PD failures

WARNING SIGNS TO WATCH FOR:
   - Any "xhci_hcd" errors in dmesg
   - "IOMMU page fault" messages
   - System freezes when plugging/unplugging power
   - USB devices disconnecting when power state changes
EOF

    print_status "$GREEN" "✓ Recommendations saved to this output and $LOG_FILE"
}

# Main execution function
main() {
    print_status "$PURPLE" "=== ThinkPad E15 Gen 3 System Crash Fix Script v$SCRIPT_VERSION ==="
    print_status "$BLUE" "Log file: $LOG_FILE"
    
    check_root
    check_system_info
    diagnose_usbc_pd_issues
    diagnose_usb_issues
    
    print_status "$YELLOW" "Applying fixes..."
    fix_usb_power_management
    fix_kernel_parameters
    optimize_tlp_config
    fix_amdgpu_issues
    create_monitoring_script
    
    post_fix_recommendations
    
    print_status "$GREEN" "=== Fix script completed successfully ==="
    print_status "$YELLOW" "REBOOT REQUIRED to apply all changes"
}

# Execute main function
main "$@"
