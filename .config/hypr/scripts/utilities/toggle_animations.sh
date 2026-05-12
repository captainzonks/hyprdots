#!/usr/bin/env bash
# Animation Toggle

set -euo pipefail

source "$HOME/.config/hypr/scripts/lib/cache.sh" || exit 1

if are_animations_disabled; then
    hyprctl keyword animations:enabled true
    set_animations_enabled
    notify-send "Animations Enabled" "Hyprland animations are now ON" -t 2000
else
    hyprctl keyword animations:enabled false
    set_animations_disabled
    notify-send "Animations Disabled" "Hyprland animations are now OFF" -t 2000
fi
