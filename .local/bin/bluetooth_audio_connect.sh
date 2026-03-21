#!/usr/bin/env bash
# Enhanced Bluetooth audio connection helper for Sony WX-1000XM4
# Handles authentication and connection issues properly
# Compatible with BlueZ 5.x and WirePlumber 0.5.x

set -euo pipefail

# Sony WH-1000XM4 MAC address — set SONY_BT_MAC in ~/.config/machine.env
SONY_MAC="${SONY_BT_MAC:?Set SONY_BT_MAC in ~/.config/machine.env}"
DEVICE_NAME="Sony WH-1000XM4"

# Enhanced connection function
connect_a2dp() {
    local mac="$1"
    
    echo "Connecting to $DEVICE_NAME ($mac) with A2DP priority..."
    
    # Ensure bluetooth is powered and discoverable
    bluetoothctl power on
    bluetoothctl discoverable on
    sleep 1
    
    # Check if device is paired
    if ! bluetoothctl paired-devices | grep -q "$mac"; then
        echo "Device not paired. Please pair it first:"
        echo "  bluetoothctl pair $mac"
        exit 1
    fi
    
    # Ensure device is trusted
    bluetoothctl trust "$mac"
    
    # Remove any existing connection to reset state
    echo "Resetting connection state..."
    bluetoothctl disconnect "$mac" 2>/dev/null || true
    sleep 3
    
    # Connect device with retries
    echo "Establishing connection..."
    local retry_count=0
    local max_retries=5
    
    while [[ $retry_count -lt $max_retries ]]; do
        if bluetoothctl connect "$mac"; then
            echo "Connection attempt $((retry_count + 1)) successful"
            break
        else
            echo "Connection attempt $((retry_count + 1)) failed, retrying..."
            ((retry_count++))
            sleep 2
        fi
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        echo "Failed to connect after $max_retries attempts"
        exit 1
    fi
    
    sleep 5
    
    # Wait for A2DP profile to be available
    echo "Waiting for A2DP profile..."
    local profile_wait=0
    while [[ $profile_wait -lt 10 ]]; do
        if wpctl status | grep -q "Sony\|$mac"; then
            echo "✓ A2DP profile detected in WirePlumber"
            break
        fi
        sleep 1
        ((profile_wait++))
    done
    
    # Set as default audio sink if A2DP is available
    local sink_id=$(wpctl status | grep -i "sony\|wh-1000xm4" | grep -o '^\s*[0-9]*' | tr -d ' ' | head -1)
    if [[ -n "$sink_id" ]]; then
        wpctl set-default "$sink_id"
        echo "✓ Set Sony headphones as default audio sink"
        
        # Set a reasonable volume
        wpctl set-volume "$sink_id" 60%
        echo "✓ Set volume to 60%"
    else
        echo "⚠ A2DP sink not found in WirePlumber"
    fi
    
    # Verify final connection status
    if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
        echo "✓ Successfully connected with A2DP!"
        echo ""
        echo "Device info:"
        bluetoothctl info "$mac" | grep -E "(Alias|Connected|UUID)"
    else
        echo "✗ Connection verification failed"
        exit 1
    fi
}

# Pairing helper function
pair_device() {
    local mac="$1"
    echo "Pairing with $DEVICE_NAME ($mac)..."
    
    bluetoothctl power on
    bluetoothctl agent on
    bluetoothctl default-agent
    bluetoothctl discoverable on
    bluetoothctl pairable on
    
    echo "Put your headphones in pairing mode and press Enter..."
    read -r
    
    bluetoothctl scan on &
    scan_pid=$!
    sleep 5
    kill $scan_pid 2>/dev/null || true
    
    bluetoothctl pair "$mac"
    bluetoothctl trust "$mac"
    bluetoothctl connect "$mac"
}

# Usage function
usage() {
    echo "Usage: $0 [connect|disconnect|pair|status|info]"
    echo "  connect    - Connect Sony headphones with A2DP"
    echo "  disconnect - Disconnect Sony headphones"
    echo "  pair       - Pair Sony headphones (first time setup)"
    echo "  status     - Show audio device status"
    echo "  info       - Show detailed device information"
}

# Main execution
case "${1:-connect}" in
    "connect")
        connect_a2dp "$SONY_MAC"
        ;;
    "disconnect")
        bluetoothctl disconnect "$SONY_MAC"
        echo "Disconnected from $DEVICE_NAME"
        ;;
    "pair")
        pair_device "$SONY_MAC"
        ;;
    "status")
        echo "Bluetooth adapter status:"
        bluetoothctl show
        echo ""
        echo "Device status:"
        bluetoothctl info "$SONY_MAC" 2>/dev/null || echo "Device not found"
        echo ""
        echo "Audio status:"
        wpctl status | grep -A 5 -B 5 -i "sony\|wh-1000xm4" || echo "Device not found in audio system"
        ;;
    "info")
        bluetoothctl info "$SONY_MAC"
        ;;
    "help"|"-h"|"--help")
        usage
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
esac
