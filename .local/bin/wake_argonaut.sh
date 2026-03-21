#!/usr/bin/env bash
# Wake Argonaut desktop via WoL relay — set WOL_RELAY_HOST and WOL_RELAY_PATH in ~/.config/machine.env

ssh "${WOL_RELAY_HOST:?Set WOL_RELAY_HOST in ~/.config/machine.env}" \
    "cd ${WOL_RELAY_PATH:?Set WOL_RELAY_PATH in ~/.config/machine.env} && ./wake_argonaut.sh"
