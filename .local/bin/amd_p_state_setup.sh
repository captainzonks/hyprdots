#!/usr/bin/env bash
# AMD P-State Configuration for Unified Kernel Images
# This script properly configures AMD P-State for UKI setups
# Reference: https://wiki.archlinux.org/title/Unified_kernel_image
# Documentation: https://www.kernel.org/doc/html/latest/admin-guide/pm/amd-pstate.html

set -euo pipefail

echo "=== Configuring AMD P-State for Unified Kernel Images ==="

# Colors for clear feedback
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration files we'll be working with
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
CMDLINE_FILE="/etc/kernel/cmdline"

echo -e "${BLUE}Understanding your current setup:${NC}"
echo "Your system uses Unified Kernel Images (UKI), which is excellent for security."
echo "Kernel parameters must be embedded into the UKI at build time."
echo ""

# Check current kernel command line (what's currently embedded)
echo -e "${BLUE}Current kernel command line (embedded in UKI):${NC}"
if [[ -f /proc/cmdline ]]; then
    cat /proc/cmdline
    echo ""
else
    echo "Unable to read current kernel command line"
fi

# Step 1: Create kernel command line file
echo -e "${BLUE}Step 1: Setting up kernel command line file${NC}"

# Create kernel directory if it doesn't exist
sudo mkdir -p /etc/kernel

# Get current command line parameters from running system
# We'll use this as base and add AMD P-State parameter
if [[ -f /proc/cmdline ]]; then
    current_cmdline=$(cat /proc/cmdline)
    echo "Current parameters: $current_cmdline"
    
    # Check if amd_pstate is already present
    if echo "$current_cmdline" | grep -q "amd_pstate"; then
        echo -e "${YELLOW}AMD P-State parameter already present in kernel command line${NC}"
        echo "Current setting: $(echo "$current_cmdline" | grep -o 'amd_pstate=[^ ]*')"
        read -p "Do you want to update it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Keeping existing configuration"
            exit 0
        fi
        # Remove existing amd_pstate parameter
        current_cmdline=$(echo "$current_cmdline" | sed 's/amd_pstate=[^ ]* *//')
    fi
    
    # Add AMD P-State active parameter
    new_cmdline="$current_cmdline amd_pstate=active"
    
    # Clean up any double spaces
    new_cmdline=$(echo "$new_cmdline" | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
    
else
    echo -e "${RED}Cannot read current kernel command line from /proc/cmdline${NC}"
    echo "Please provide your root partition UUID manually"
    echo "You can find it with: lsblk -f"
    exit 1
fi

# Write the new command line to the kernel cmdline file
echo "Writing new kernel command line to $CMDLINE_FILE"
echo "$new_cmdline" | sudo tee "$CMDLINE_FILE" > /dev/null

echo -e "${GREEN}✓ Kernel command line updated:${NC}"
echo "$new_cmdline"
echo ""

# Step 2: Verify mkinitcpio is configured for UKI
echo -e "${BLUE}Step 2: Verifying mkinitcpio UKI configuration${NC}"

# Check if mkinitcpio.conf has UKI support enabled
if grep -q "^default_uki=" /etc/mkinitcpio.d/linux.preset 2>/dev/null; then
    echo -e "${GREEN}✓ UKI configuration found in preset${NC}"
else
    echo -e "${RED}✗ UKI configuration not found${NC}"
    echo "This should not happen with your preset file. Please check your setup."
    exit 1
fi

# Step 3: Rebuild the unified kernel images
echo -e "${BLUE}Step 3: Rebuilding Unified Kernel Images${NC}"
echo "This will embed the new kernel parameters into your boot images..."

# Create backup of current UKI files
echo "Creating backup of current UKI files..."
sudo mkdir -p /boot/EFI/Linux/backup
timestamp=$(date +%Y%m%d_%H%M%S)

if [[ -f /boot/EFI/Linux/arch-linux.efi ]]; then
    sudo cp /boot/EFI/Linux/arch-linux.efi "/boot/EFI/Linux/backup/arch-linux_${timestamp}.efi"
    echo "✓ Backed up arch-linux.efi"
fi

if [[ -f /boot/EFI/Linux/arch-linux-fallback.efi ]]; then
    sudo cp /boot/EFI/Linux/arch-linux-fallback.efi "/boot/EFI/Linux/backup/arch-linux-fallback_${timestamp}.efi"
    echo "✓ Backed up arch-linux-fallback.efi"
fi

# Rebuild the images
echo "Rebuilding UKI images with new kernel parameters..."
sudo mkinitcpio -P

# Verify the rebuild was successful
if [[ -f /boot/EFI/Linux/arch-linux.efi ]]; then
    echo -e "${GREEN}✓ Primary UKI rebuilt successfully${NC}"
    ls -lh /boot/EFI/Linux/arch-linux.efi
else
    echo -e "${RED}✗ Primary UKI rebuild failed${NC}"
    exit 1
fi

if [[ -f /boot/EFI/Linux/arch-linux-fallback.efi ]]; then
    echo -e "${GREEN}✓ Fallback UKI rebuilt successfully${NC}"
    ls -lh /boot/EFI/Linux/arch-linux-fallback.efi
else
    echo -e "${RED}✗ Fallback UKI rebuild failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "✓ Kernel command line updated with amd_pstate=active"
echo "✓ Unified Kernel Images rebuilt with new parameters"
echo "✓ Backup of original UKI files created in /boot/EFI/Linux/backup/"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Reboot your system"
echo "2. Run: power_diagnostic.sh to verify P-State status and EPP settings"
echo "3. Confirm TLP picks up the active-mode driver: sudo tlp-stat -p"
