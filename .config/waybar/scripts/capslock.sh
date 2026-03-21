#!/usr/bin/env bash
# For waybar to detect capslock
# (keyboard-state doesn't appear to work correctly)

capslock=$(cat /sys/class/leds/input*::capslock/brightness | head -c 1)

if [[ "${capslock}" == "1" ]]; then
  echo '{"class": "locked", "text": "󰌎"}'
else
  echo '{"class": "unlocked", "text": ""}'
fi
