#!/usr/bin/env bash
#==========================================================#
#           WAYBAR WORKSPACE VISIBILITY TOGGLE            #
#==========================================================#
# File: waybar_workspace_toggle.sh
# Purpose: Hide waybar on workspace 10 (Moonlight gaming)
# Last Updated: 2025-11-26
# Documentation: https://wiki.hyprland.org/IPC/
#==========================================================#

# Function to handle workspace changes
handle_workspace_change() {
    # Get current workspace
    workspace=$(hyprctl activeworkspace -j | jq -r '.id')

    # Hide waybar on workspace 10, show it on all others
    if [ "$workspace" -eq 10 ]; then
        pkill -SIGUSR1 waybar  # Hide waybar
    else
        pkill -SIGUSR2 waybar  # Show waybar
    fi
}

# Listen to Hyprland events
socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    case "$line" in
        workspace*)
            handle_workspace_change
            ;;
    esac
done
