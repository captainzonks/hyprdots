#!/usr/bin/env bash
# Gamemode Toggle - disable animations/blur for gaming

set -euo pipefail

source "$HOME/.config/hypr/scripts/lib/cache.sh" || exit 1

if is_gamemode_enabled; then
    echo ":: Disabling gamemode..."
    hyprctl reload
    disable_gamemode
    notify-send "Gamemode OFF" "Animations and effects restored" -i applications-games -t 2000
else
    echo ":: Enabling gamemode..."
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
    enable_gamemode
    notify-send "Gamemode ON" "Performance mode enabled" -i applications-games -t 2000
fi
