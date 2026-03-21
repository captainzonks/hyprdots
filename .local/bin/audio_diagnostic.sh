#!/usr/bin/env bash
# ~/.local/bin/audio-hardware-diagnostic
# Comprehensive audio hardware detection and enumeration diagnostic
# Specifically targets "no sound cards available" issues in pwvucontrol

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Command line options
AUTO_FIX=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix|-f)
            AUTO_FIX=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: audio-hardware-diagnostic [--fix] [--verbose]"
            echo "  --fix: Automatically apply common fixes"
            echo "  --verbose: Show detailed technical output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "Audio Hardware Detection Diagnostic"
echo "System: Lenovo ThinkPad E15 Gen 3 (AMD Ryzen 5700U)"
echo "Date: $(date)"
echo ""

# Step 1: Kernel-level hardware detection
print_header "Step 1: Kernel Hardware Detection"

echo "PCI Audio Devices:"
if lspci | grep -i audio; then
    print_ok "Audio hardware detected at PCI level"
    if [[ "$VERBOSE" == true ]]; then
        echo "Detailed PCI info:"
        lspci -v | grep -A 10 -i audio
    fi
else
    print_error "No audio hardware detected at PCI level"
    echo "This indicates a serious hardware or driver issue"
fi

echo ""
echo "Loaded audio kernel modules:"
if lsmod | grep -E "(snd|audio)" | head -10; then
    print_ok "Audio kernel modules are loaded"
else
    print_error "No audio kernel modules loaded"
    if [[ "$AUTO_FIX" == true ]]; then
        echo "Attempting to load audio modules..."
        sudo modprobe snd_hda_intel || echo "Failed to load snd_hda_intel"
        sudo modprobe snd_hda_codec_realtek || echo "Failed to load realtek codec"
    fi
fi

# Step 2: ALSA (low-level audio) detection
print_header "Step 2: ALSA Hardware Detection"

echo "ALSA sound cards:"
if aplay -l 2>/dev/null; then
    print_ok "ALSA detects audio hardware"
else
    print_error "ALSA cannot detect any audio hardware"
    echo "This is the root cause - audio hardware isn't being enumerated"
    
    if [[ "$AUTO_FIX" == true ]]; then
        echo "Attempting ALSA fixes..."
        echo "Forcing audio driver reload..."
        sudo modprobe -r snd_hda_intel 2>/dev/null || true
        sleep 2
        sudo modprobe snd_hda_intel
        sleep 3
        
        echo "Checking again after reload..."
        if aplay -l 2>/dev/null; then
            print_ok "ALSA hardware detected after driver reload"
        else
            print_error "ALSA still cannot detect hardware after reload"
        fi
    fi
fi

echo ""
echo "ALSA controls (if available):"
if amixer scontrols 2>/dev/null | head -5; then
    print_ok "ALSA mixer controls are available"
else
    print_warning "No ALSA mixer controls available"
fi

# Step 3: Check for hardware muting/power issues
print_header "Step 3: Hardware State Analysis"

echo "Checking for muted/disabled hardware..."
if command -v amixer >/dev/null 2>&1; then
    # Check if Master volume exists and is muted
    if amixer get Master 2>/dev/null | grep -q "off"; then
        print_warning "Master volume is muted"
        if [[ "$AUTO_FIX" == true ]]; then
            echo "Unmuting Master volume..."
            amixer set Master unmute 2>/dev/null || echo "Could not unmute"
        fi
    fi
    
    # Check for PCM muting
    if amixer get PCM 2>/dev/null | grep -q "off"; then
        print_warning "PCM is muted"
        if [[ "$AUTO_FIX" == true ]]; then
            echo "Unmuting PCM..."
            amixer set PCM unmute 2>/dev/null || echo "Could not unmute PCM"
        fi
    fi
else
    print_warning "amixer not available for hardware state checks"
fi

# Check power management
echo ""
echo "Audio device power management:"
for device in /sys/class/sound/card*/device/power/control; do
    if [[ -f "$device" ]]; then
        control=$(cat "$device" 2>/dev/null || echo "unknown")
        echo "  $(dirname "$device" | cut -d/ -f5): power control = $control"
        
        if [[ "$control" == "auto" ]] && [[ "$AUTO_FIX" == true ]]; then
            echo "  Setting power control to 'on' for better detection..."
            echo "on" | sudo tee "$device" >/dev/null 2>&1 || echo "  Failed to modify power control"
        fi
    fi
done

# Step 4: PipeWire/WirePlumber enumeration
print_header "Step 4: PipeWire Audio Node Detection"

echo "PipeWire core status:"
if pw-cli info 0 2>/dev/null | head -10; then
    print_ok "PipeWire core is responding"
else
    print_error "PipeWire core is not responding"
fi

echo ""
echo "WirePlumber device enumeration:"
if wpctl status 2>/dev/null; then
    print_ok "WirePlumber is enumerating devices"
    
    # Check if there are actually audio devices
    if wpctl status | grep -i "audio" | grep -q "sink\|source"; then
        print_ok "Audio sinks/sources detected by WirePlumber"
    else
        print_warning "WirePlumber running but no audio devices detected"
        echo "This suggests the issue is in hardware->WirePlumber communication"
    fi
else
    print_error "WirePlumber is not responding or has no devices"
fi

echo ""
echo "Raw PipeWire node list:"
if pw-cli list-objects 2>/dev/null | grep -A 5 -B 5 -i "node.name.*alsa" | head -20; then
    print_ok "ALSA nodes detected in PipeWire"
else
    print_warning "No ALSA nodes found in PipeWire object list"
fi

# Step 5: Service and permission checks
print_header "Step 5: Service and Permission Analysis"

echo "Audio group membership:"
if groups | grep -q audio; then
    print_ok "User is in audio group"
else
    print_warning "User is not in audio group"
    if [[ "$AUTO_FIX" == true ]]; then
        echo "Adding user to audio group..."
        sudo usermod -a -G audio "$(whoami)"
        echo "You'll need to log out and back in for this to take effect"
    fi
fi

echo ""
echo "Device file permissions:"
for device in /dev/snd/*; do
    if [[ -e "$device" ]]; then
        ls -la "$device" | head -5
        break
    fi
done

if [[ ! -d "/dev/snd" ]]; then
    print_error "/dev/snd directory does not exist - no audio devices available"
fi

echo ""
echo "Service status:"
for service in pipewire.service pipewire-pulse.service wireplumber.service; do
    if systemctl --user is-active "$service" >/dev/null 2>&1; then
        print_ok "$service is running"
    else
        print_error "$service is not running"
    fi
done

# Step 6: Check for conflicts and blockers
print_header "Step 6: Conflict and Blocker Detection"

echo "Checking for conflicting audio systems..."
if pgrep -x pulseaudio >/dev/null 2>&1; then
    print_warning "PulseAudio is running (may conflict with PipeWire)"
    if [[ "$AUTO_FIX" == true ]]; then
        echo "Stopping PulseAudio..."
        pkill pulseaudio || true
        systemctl --user disable pulseaudio.service || true
        systemctl --user mask pulseaudio.service || true
    fi
fi

if pgrep -x jackd >/dev/null 2>&1; then
    print_warning "JACK is running (may conflict with PipeWire)"
fi

echo ""
echo "Checking for audio device reservations..."
if lsof /dev/snd/* 2>/dev/null; then
    print_info "Audio devices are in use by above processes"
else
    print_warning "No processes are using audio devices (this might be the problem)"
fi

# Step 7: Configuration analysis
print_header "Step 7: Configuration Analysis"

echo "WirePlumber configuration directories:"
for dir in /usr/share/wireplumber ~/.config/wireplumber; do
    if [[ -d "$dir" ]]; then
        print_ok "$dir exists"
        if [[ "$VERBOSE" == true ]]; then
            echo "  Contents:"
            find "$dir" -name "*.conf" -o -name "*.lua" | head -10 | sed 's/^/    /'
        fi
    else
        print_info "$dir does not exist"
    fi
done

echo ""
echo "Checking for custom WirePlumber rules that might block enumeration..."
if [[ -f "$HOME/.config/wireplumber/wireplumber.conf.d/51-disable-suspension.conf" ]]; then
    print_info "Custom WirePlumber configuration found"
    if grep -q "disabled.*true" "$HOME/.config/wireplumber/wireplumber.conf.d/51-disable-suspension.conf" 2>/dev/null; then
        print_warning "Configuration may be disabling devices"
    fi
fi

# Step 8: Recommended fixes
print_header "Step 8: Recommended Fixes"

echo "Based on the diagnostic results:"
echo ""

if ! aplay -l >/dev/null 2>&1; then
    echo "🔧 CRITICAL: ALSA cannot detect hardware"
    echo "   Try: sudo modprobe -r snd_hda_intel && sudo modprobe snd_hda_intel"
    echo "   Or:  Reboot to reset audio subsystem"
    echo ""
fi

if ! groups | grep -q audio; then
    echo "🔧 PERMISSION: Add user to audio group"
    echo "   Run: sudo usermod -a -G audio $(whoami)"
    echo "   Then: Log out and back in"
    echo ""
fi

if ! wpctl status | grep -q "Audio"; then
    echo "🔧 ENUMERATION: WirePlumber not detecting devices"
    echo "   Try: systemctl --user restart wireplumber.service"
    echo "   Or:  Check WirePlumber configuration"
    echo ""
fi

echo "🔧 MANUAL TESTS:"
echo "   Test ALSA: speaker-test -t sine -f 1000 -l 1"
echo "   List devices: aplay -l && arecord -l"
echo "   Check mixing: amixer scontrols"
echo ""

echo "🔧 MONITORING:"
echo "   Watch logs: journalctl --user -f -u wireplumber -u pipewire"
echo "   Monitor nodes: watch 'wpctl status'"
echo ""

# Step 9: Automatic fixes summary
if [[ "$AUTO_FIX" == true ]]; then
    print_header "Step 9: Applied Automatic Fixes"
    echo "The following fixes were attempted:"
    echo "• Audio driver reload"
    echo "• Hardware unmuting"
    echo "• Power management adjustment"
    echo "• PulseAudio conflict resolution"
    echo "• Audio group membership"
    echo ""
    echo "Some changes may require logout/reboot to take effect."
    echo ""
    echo "Re-run this diagnostic to verify fixes:"
    echo "  audio-hardware-diagnostic --verbose"
fi

print_header "Diagnostic Complete"
echo ""
echo "Next steps if pwvucontrol still shows no devices:"
echo "1. Run: speaker-test -t sine -f 1000 -l 1"
echo "2. Check: aplay -l (should show hardware)"
echo "3. Verify: wpctl status (should show audio nodes)"
echo "4. If still failing: reboot and run diagnostic again"
