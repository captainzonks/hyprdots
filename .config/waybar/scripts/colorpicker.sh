#!/usr/bin/env bash
# ~/.config/waybar/scripts/colorpicker.sh
# UWSM-integrated colorpicker with proper systemd management
# Documentation: https://github.com/hyprwm/hyprpicker

set -euo pipefail

# Configuration
readonly CACHE_DIR="$HOME/.cache/colorpicker"
readonly COLOR_FILE="$CACHE_DIR/colors"
readonly MAX_COLORS=10
readonly WALLPAPER="${HOME}/Pictures/wallpapers/gruvbox/dark-side-of-the-gruvbox_2560x1440.png"

# Ensure cache directory exists
[[ -d "$CACHE_DIR" ]] || mkdir -p "$CACHE_DIR"
[[ -f "$COLOR_FILE" ]] || touch "$COLOR_FILE"

# Function to check if command exists
check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        notify-send "Error" "$1 is not installed" -u critical
        exit 1
    }
}

# Function to display color list in JSON format for waybar
display_json() {
    local current_color
    current_color="$(head -n 1 "$COLOR_FILE" 2>/dev/null || echo "#fabd2f")"
    
    local tooltip="<b>🎨 COLOR PICKER</b>\\n\\n"
    tooltip+="Current: <b>$current_color</b> <span color='$current_color'>████</span>\\n"
    tooltip+="Click to pick new color\\n\\n"
    
    # Add recent colors to tooltip
    if [[ -s "$COLOR_FILE" ]]; then
        tooltip+="<b>Recent Colors:</b>\\n"
        while IFS= read -r color && [[ -n "$color" ]]; do
            tooltip+="<b>$color</b> <span color='$color'>████</span>\\n"
        done < <(tail -n +2 "$COLOR_FILE" | head -n $((MAX_COLORS - 1)))
    fi
    
    cat <<EOF
{"text":"<span color='$current_color'>🎨</span>", "tooltip":"$tooltip"}
EOF
}

# Function to pick a new color
pick_color() {
    check_command hyprpicker
    check_command wl-copy
    
    # Kill any existing hyprpicker instances
    pkill -f hyprpicker 2>/dev/null || true
    
    # Pick color with hyprpicker
    local new_color
    if new_color=$(hyprpicker 2>/dev/null); then
        # Copy to clipboard
        echo "$new_color" | tr -d '\n' | wl-copy
        
        # Update color history
        {
            echo "$new_color"
            if [[ -f "$COLOR_FILE" ]]; then
                head -n $((MAX_COLORS - 1)) "$COLOR_FILE"
            fi
        } > "$COLOR_FILE.tmp" && mv "$COLOR_FILE.tmp" "$COLOR_FILE"
        
        # Remove empty lines
        sed -i '/^$/d' "$COLOR_FILE"
        
        # Send notification
        notify-send "Color Picker" \
            "Selected: $new_color\\nCopied to clipboard" \
            -i "${WALLPAPER}" \
            --urgency=normal
        
        # Signal waybar to update
        pkill -RTMIN+1 waybar 2>/dev/null || true
    else
        notify-send "Color Picker" "Color picking cancelled" -u low
    fi
}

# Main function
main() {
    case "${1:-}" in
        -j|--json)
            display_json
            ;;
        -l|--list)
            cat "$COLOR_FILE" 2>/dev/null || echo "No colors saved yet"
            ;;
        -h|--help)
            cat <<EOF
Color Picker Script for Waybar + UWSM

Usage: $0 [OPTIONS]

OPTIONS:
    -j, --json      Output JSON format for waybar
    -l, --list      List saved colors
    -h, --help      Show this help
    (no args)       Pick a new color

Integration:
    This script is designed to work with:
    - UWSM session management
    - Waybar custom modules
    - Systemd user services
    - Gruvbox color scheme

Dependencies:
    - hyprpicker: Color picker tool
    - wl-copy: Wayland clipboard utility
    - notify-send: Desktop notifications
EOF
            ;;
        *)
            pick_color
            ;;
    esac
}

main "$@"
