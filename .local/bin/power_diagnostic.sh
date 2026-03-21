#!/usr/bin/env bash
# Power Management Diagnostic for AMD Ryzen 5700U
# This script identifies your current power scaling setup and available options
# Documentation: https://www.kernel.org/doc/html/latest/admin-guide/pm/amd-pstate.html

set -euo pipefail

# Colors for clear output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AMD Ryzen Power Management Diagnostic ===${NC}"
echo "Hardware: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)"
echo "Kernel: $(uname -r)"
echo ""

# Check AMD P-State status
echo -e "${BLUE}1. AMD P-State Driver Status:${NC}"
if [[ -f /sys/devices/system/cpu/amd_pstate/status ]]; then
    amd_pstate_status=$(cat /sys/devices/system/cpu/amd_pstate/status)
    echo "   Status: $amd_pstate_status"
    
    case "$amd_pstate_status" in
        "active")
            echo -e "${GREEN}   ✓ Hardware-managed frequency scaling (EPP mode)${NC}"
            echo "   → This is optimal for battery life and performance"
            echo "   → Traditional governors are replaced by EPP preferences"
            ;;
        "passive")
            echo -e "${YELLOW}   ⚠ Kernel-managed with hardware hints${NC}"
            echo "   → Traditional governors are available"
            ;;
        "disable")
            echo -e "${RED}   ✗ AMD P-State disabled, using fallback${NC}"
            echo "   → Check kernel parameters or BIOS settings"
            ;;
    esac
else
    echo -e "${RED}   ✗ AMD P-State interface not found${NC}"
    echo "   → May need 'amd_pstate=active' kernel parameter"
fi

echo ""

# Check current scaling driver
echo -e "${BLUE}2. CPU Frequency Scaling Driver:${NC}"
scaling_driver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo "Not available")
echo "   Driver: $scaling_driver"

case "$scaling_driver" in
    "amd_pstate_epp")
        echo -e "${GREEN}   ✓ Using AMD P-State EPP (Energy Performance Preference)${NC}"
        echo "   → Hardware manages frequencies automatically"
        ;;
    "amd_pstate")
        echo -e "${YELLOW}   ⚠ Using AMD P-State passive mode${NC}"
        echo "   → Kernel manages frequencies with hardware hints"
        ;;
    "acpi-cpufreq")
        echo -e "${YELLOW}   ⚠ Using legacy ACPI driver${NC}"
        echo "   → Consider enabling AMD P-State for better efficiency"
        ;;
    *)
        echo -e "${RED}   ✗ Unknown or unsupported driver${NC}"
        ;;
esac

echo ""

# Check available governors
echo -e "${BLUE}3. Available CPU Governors:${NC}"
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ]]; then
    available_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
    echo "   Available: $available_governors"
    
    current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "Unknown")
    echo "   Current: $current_governor"
    
    # Check if schedutil is available
    if echo "$available_governors" | grep -q "schedutil"; then
        echo -e "${GREEN}   ✓ schedutil governor is available${NC}"
    else
        echo -e "${YELLOW}   ⚠ schedutil governor is NOT available${NC}"
        echo "   → This explains your TLP error"
    fi
else
    echo -e "${YELLOW}   ⚠ Governor interface not available${NC}"
    echo "   → You might be using EPP mode (hardware-managed)"
fi

echo ""

# Check EPP preferences (if available)
echo -e "${BLUE}4. Energy Performance Preferences (EPP):${NC}"
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]]; then
    epp_current=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo "Unknown")
    echo "   Current EPP: $epp_current"
    
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences ]]; then
        epp_available=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences)
        echo "   Available EPP values: $epp_available"
        echo ""
        echo "   EPP Explanation:"
        echo "   • performance: Maximum CPU performance"
        echo "   • balance_performance: Balanced toward performance"  
        echo "   • balance_power: Balanced toward power saving"
        echo "   • power: Maximum power saving"
    fi
else
    echo "   EPP interface not available"
    echo "   → Normal if not using amd_pstate_epp driver"
fi

echo ""

# Check TLP configuration
echo -e "${BLUE}5. TLP Configuration Check:${NC}"
if command -v tlp-stat >/dev/null 2>&1; then
    echo "   TLP Status: $(systemctl is-active tlp.service 2>/dev/null || echo 'Not running')"
    
    # Look for governor configuration in TLP config
    if [[ -f /etc/tlp.conf ]]; then
        echo "   Checking TLP governor configuration..."
        
        # Extract governor settings from TLP config
        grep -E "^CPU_SCALING_GOVERNOR" /etc/tlp.conf 2>/dev/null | while read line; do
            echo "   $line"
        done || echo "   No governor configuration found in TLP"
    fi
else
    echo "   TLP not installed or not in PATH"
fi

echo ""

# Provide recommendations
echo -e "${BLUE}=== Recommendations ===${NC}"

if [[ "$scaling_driver" == "amd_pstate_epp" ]]; then
    echo -e "${GREEN}✓ Your system is optimally configured with AMD P-State EPP${NC}"
    echo ""
    echo "To fix the TLP error, you should:"
    echo "1. Remove governor settings from TLP (they're not needed with EPP)"
    echo "2. Configure EPP preferences instead of governors"
    echo "3. Let the hardware manage frequencies automatically"
    echo ""
    echo "EPP is superior to traditional governors because:"
    echo "• Hardware has microsecond response times vs kernel milliseconds"
    echo "• Better integration with CPU internal power management"
    echo "• More efficient battery usage"
    
elif [[ "$scaling_driver" == "amd_pstate" ]]; then
    echo -e "${YELLOW}⚠ Consider switching to EPP mode for better efficiency${NC}"
    echo "Add 'amd_pstate=active' to kernel parameters"
    
else
    echo -e "${RED}⚠ Consider enabling AMD P-State for your Ryzen processor${NC}"
    echo "Add 'amd_pstate=active' to kernel parameters"
fi

echo ""
echo "Next steps:"
echo "1. Run the TLP configuration fix script"
echo "2. Verify the configuration with 'tlp-stat -s'"
echo "3. Monitor power usage with 'battery-status'"
