#!/usr/bin/env bash
# =============================================================================
# WiFi Toggle
# =============================================================================
# Toggles WiFi radio on/off using both rfkill and NetworkManager
# to ensure full synchronization between hardware switch, system state,
# and UI indicators (waybar, nm-applet).
#
# Dependencies: rfkill, nmcli, notify-send
# =============================================================================

set -euo pipefail

LOG_FILE="$HOME/.local/state/wifi-toggle.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

# Get current wifi state from NetworkManager
wifi_enabled=$(nmcli radio wifi)

if [[ "$wifi_enabled" == "enabled" ]]; then
    # WiFi is on, turn it off
    log "Disabling WiFi..."

    # Use rfkill to block wifi (hardware level)
    rfkill block wifi

    # Also disable via NetworkManager for UI sync
    nmcli radio wifi off

    # Verify state
    sleep 0.5
    if [[ "$(nmcli radio wifi)" == "disabled" ]]; then
        log "WiFi disabled successfully"
        notify-send "WiFi Disabled" "WiFi radio is now OFF" -i network-wireless-disabled -t 2000
    else
        log "WARNING: WiFi may not be fully disabled"
        notify-send "WiFi Toggle" "WiFi state unclear - check manually" -u critical -t 3000
    fi
else
    # WiFi is off, turn it on
    log "Enabling WiFi..."

    # Use rfkill to unblock wifi (hardware level)
    rfkill unblock wifi

    # Enable via NetworkManager
    nmcli radio wifi on

    # Verify state and wait for connection
    sleep 1
    if [[ "$(nmcli radio wifi)" == "enabled" ]]; then
        log "WiFi enabled successfully"

        # Check if we're connecting to a network
        sleep 2
        connection_status=$(nmcli -t -f STATE general)

        if [[ "$connection_status" == "connected" ]]; then
            ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
            log "Connected to: $ssid"
            notify-send "WiFi Enabled" "Connected to: $ssid" -i network-wireless -t 3000
        else
            log "WiFi enabled but not connected yet"
            notify-send "WiFi Enabled" "Scanning for networks..." -i network-wireless -t 2000
        fi
    else
        log "WARNING: WiFi may not be fully enabled"
        notify-send "WiFi Toggle" "WiFi state unclear - check manually" -u critical -t 3000
    fi
fi
