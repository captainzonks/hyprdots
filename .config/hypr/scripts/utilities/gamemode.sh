#!/usr/bin/env bash
# =============================================================================
# Gamemode Toggle
# =============================================================================
# Toggles performance mode for gaming and high-performance tasks
# Disables animations, blur, shadows, gaps, and rounding
# Manages wallpaper automation state
#
# Dependencies: hyprctl, notify-send
# =============================================================================

set -euo pipefail

# Source cache library
source "$HOME/.config/hypr/scripts/lib/cache.sh" || exit 1

# Check current state using cache library
if is_gamemode_enabled; then
    # Gamemode is ON, disable it
    echo ":: Disabling gamemode..."

    # Restore normal settings
    hyprctl reload

    # Remove gamemode state
    disable_gamemode

    # Restore wallpaper automation if it was paused
    if has_state "wallpaper_automation_paused"; then
        delete_state "wallpaper_automation_paused"
        echo ":: Wallpaper automation restored"
    fi

    notify-send "Gamemode OFF" "Animations and effects restored" -i applications-games -t 2000
    echo ":: Gamemode disabled"
else
    # Gamemode is OFF, enable it
    echo ":: Enabling gamemode..."

    # Pause wallpaper automation
    write_state "wallpaper_automation_paused" "1"
    echo ":: Wallpaper automation paused"

    # Apply performance settings
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"

    # Enable gamemode state
    enable_gamemode

    notify-send "Gamemode ON" "Performance mode enabled" -i applications-games -t 2000
    echo ":: Gamemode enabled"
fi
