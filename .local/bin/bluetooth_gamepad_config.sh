#!/usr/bin/env bash
#==========================================================#
#                BLUETOOTH GAMEPAD CONFIGURATION          #
#==========================================================#
# File: bluetooth_gamepad_config.sh
# Purpose: Configure Bluetooth for Xbox One controller support
# Dependencies: bluez, bluez-utils
# Documentation: https://wiki.archlinux.org/title/Gamepad
# Last Updated: 2025-08-02
#==========================================================#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Backup existing configuration
backup_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        sudo cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up $config_file"
    fi
}

# Configure main Bluetooth settings
configure_main_bluetooth() {
    local main_conf="/etc/bluetooth/main.conf"
    backup_config "$main_conf"
    
    print_status "Configuring main Bluetooth settings..."
    
    # Create optimized configuration for gamepad support
    sudo tee "$main_conf" > /dev/null << 'EOF'
# /etc/bluetooth/main.conf
# Optimized for Xbox One controller support
# Documentation: https://wiki.archlinux.org/title/Bluetooth

[General]
# Default adapter name
Name = %h-bluetooth

# Default device class. Only the major and minor device class bits are considered.
Class = 0x000100

# How long to stay in discoverable mode before going back to non-discoverable
DiscoverableTimeout = 0

# Always pairable
PairableTimeout = 0

# Disable service authorization requirement
AutoEnable = true

# Enable name resolving after inquiry
NameResolveTimeout = 30

# Xbox controller support optimizations
FastConnectable = true

# Bluetooth Low Energy settings for modern Xbox controllers
[LE]
# Optimized connection parameters for Xbox Series X|S controllers
MinConnectionInterval = 7
MaxConnectionInterval = 9
ConnectionLatency = 0
ConnectionSupervisionTimeout = 42

# Policy settings
[Policy]
# Auto-connect for trusted devices (important for controllers)
AutoEnable = true
ReconnectAttempts = 7
ReconnectDelay = 15
EOF

    print_success "Main Bluetooth configuration updated"
}

# Configure input-specific settings  
configure_input_settings() {
    local input_conf="/etc/bluetooth/input.conf"
    backup_config "$input_conf"
    
    print_status "Configuring Bluetooth input settings..."
    
    sudo tee "$input_conf" > /dev/null << 'EOF'
# /etc/bluetooth/input.conf
# HID input device configuration

[General]
# Enable HID service
UserspaceHID = true

# Set idle timeout to 30 minutes (controllers auto-sleep)
IdleTimeout = 30

# Required for DualShock 3 (not needed for Xbox but doesn't hurt)
ClassicBondedOnly = false
EOF

    print_success "Input configuration updated"
}

# Add udev rules for controller permissions
configure_udev_rules() {
    local udev_rules="/etc/udev/rules.d/99-xbox-controller.rules"
    
    print_status "Creating udev rules for Xbox controller..."
    
    sudo tee "$udev_rules" > /dev/null << 'EOF'
# /etc/udev/rules.d/99-xbox-controller.rules
# Xbox One controller udev rules for proper permissions

# Xbox One controllers (all variants)
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02d1", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02dd", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02e0", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02e3", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b00", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b05", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b12", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b13", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b20", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b22", MODE="0666", TAG+="uaccess"

# Xbox Wireless Adapter
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02e6", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02fe", MODE="0666", TAG+="uaccess"

# Bluetooth HID devices should be accessible by users in input group
SUBSYSTEM=="input", GROUP="input", MODE="0664"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="045e", GROUP="input", MODE="0664"
EOF

    print_success "Udev rules created"
}

# Check and restart services
restart_services() {
    print_status "Restarting Bluetooth services..."
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    # Restart Bluetooth
    sudo systemctl restart bluetooth
    
    # Verify Bluetooth is running
    if systemctl is-active --quiet bluetooth; then
        print_success "Bluetooth service is running"
    else
        print_error "Bluetooth service failed to start"
        return 1
    fi
}

# Verify xpadneo is loaded
check_xpadneo() {
    print_status "Checking xpadneo driver status..."
    
    if lsmod | grep -q hid_xpadneo; then
        print_success "xpadneo driver is loaded"
    else
        print_warning "xpadneo driver not loaded - will load when controller connects"
    fi
    
    # Check if module is available
    if [[ -f "/usr/lib/modules/$(uname -r)/updates/dkms/hid-xpadneo.ko.zst" ]]; then
        print_success "xpadneo module is installed for current kernel"
    else
        print_error "xpadneo module not found - please install xpadneo first"
        return 1
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "    Xbox One Controller Bluetooth Setup"
    echo "=========================================="
    
    # Check if running as regular user
    if [[ $EUID -eq 0 ]]; then
        print_error "Please run this script as a regular user (it will use sudo when needed)"
        exit 1
    fi
    
    # Check prerequisites
    if ! command -v bluetoothctl >/dev/null; then
        print_error "bluetoothctl not found. Please install bluez-utils"
        exit 1
    fi
    
    # Perform configuration
    configure_main_bluetooth
    configure_input_settings
    configure_udev_rules
    restart_services
    check_xpadneo
    
    echo
    print_success "Bluetooth gamepad configuration complete!"
    echo
    echo "Next steps:"
    echo "1. Put your Xbox controller in pairing mode"
    echo "2. Run 'sudo bluetoothctl' to pair the controller"
    echo "3. Test with 'jstest /dev/input/js0' or 'evtest'"
    echo
    print_warning "If pairing fails, you may need to update controller firmware in Windows first"
}

main "$@"
