#!/usr/bin/env bash
# Hyprsunset Filter Toggle

set -euo pipefail

source "$HOME/.config/hypr/scripts/lib/cache.sh" || exit 1

# Night look matches the 21:00 profile in hyprsunset.conf
NIGHT_TEMP=5500
NIGHT_GAMMA=80

# hyprsunset IPC has no reliable on/off query (temperature query ignores
# identity), so cache state is the source of truth. Default (no state) =
# enabled, matching the autostarted profile.
if is_hyprsunset_disabled; then
    hyprctl hyprsunset temperature "$NIGHT_TEMP"
    hyprctl hyprsunset gamma "$NIGHT_GAMMA"
    set_hyprsunset_enabled
    notify-send "Night Filter Enabled" "hyprsunset ${NIGHT_TEMP}K" -t 2000
else
    hyprctl hyprsunset identity
    hyprctl hyprsunset gamma 100
    set_hyprsunset_disabled
    notify-send "Night Filter Disabled" "hyprsunset identity" -t 2000
fi
