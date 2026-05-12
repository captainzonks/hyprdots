#!/usr/bin/env bash
set -euo pipefail

# Detect capslock state for waybar custom module
# Use a specific LED path to avoid glob issues with multiple inputs
capslock="0"
for f in /sys/class/leds/input*::capslock/brightness; do
    if [[ -r "$f" ]]; then
        capslock=$(<"$f")
        break
    fi
done

if [[ "$capslock" == "1" ]]; then
    echo '{"class": "locked", "text": "󰌎"}'
else
    echo '{"class": "unlocked", "text": ""}'
fi
