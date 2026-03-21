#!/usr/bin/env bash
# =============================================================================
# Animation Toggle
# =============================================================================
# Quickly toggle Hyprland animations on/off for performance testing,
# gaming, or presentations
#
# Dependencies: hyprctl, notify-send
# =============================================================================

set -euo pipefail

# Source cache library
source "$HOME/.config/hypr/scripts/lib/cache.sh" || exit 1

# Check current state using cache library
if are_animations_disabled; then
    # Animations are currently disabled, enable them
    hyprctl keyword animations:enabled true
    set_animations_enabled
    notify-send "Animations Enabled" "Hyprland animations are now ON" -t 2000
else
    # Animations are currently enabled, disable them
    hyprctl keyword animations:enabled false
    set_animations_disabled
    notify-send "Animations Disabled" "Hyprland animations are now OFF (better performance)" -t 2000
fi
