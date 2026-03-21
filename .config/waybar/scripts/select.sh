#!/usr/bin/env bash
# ~/.config/waybar/scripts/select.sh
# UWSM-integrated waybar theme selector with systemd management

set -euo pipefail

# Configuration
readonly WAYBAR_DIR="$HOME/.config/waybar"
readonly STYLE_CSS="$WAYBAR_DIR/style.css"
readonly CONFIG_JSON="$WAYBAR_DIR/config"
readonly THEMES_DIR="$WAYBAR_DIR/themes"
readonly ASSETS_DIR="$WAYBAR_DIR/assets"
readonly SERVICE_NAME="waybar.service"

# Ensure directories exist
[[ -d "$THEMES_DIR" ]] || {
    echo "Error: Themes directory not found: $THEMES_DIR" >&2
    exit 1
}

# Logging function
log_message() {
    local level="$1"
    shift
    echo "[waybar-select] [$level] $*" >&2
    logger -t "waybar-select" "[$level] $*" 2>/dev/null || true
}

# Function to backup current configuration
backup_config() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$WAYBAR_DIR/backups"
    
    mkdir -p "$backup_dir"
    
    if [[ -f "$STYLE_CSS" ]]; then
        cp "$STYLE_CSS" "$backup_dir/style_${timestamp}.css"
    fi
    
    if [[ -f "$CONFIG_JSON" ]]; then
        cp "$CONFIG_JSON" "$backup_dir/config_${timestamp}.json"
    fi
    
    log_message "INFO" "Configuration backed up to $backup_dir"
}

# Function to apply theme
apply_theme() {
    local theme_name="$1"
    local theme_dir="$THEMES_DIR/$theme_name"
    local style_file="$theme_dir/style-${theme_name}.css"
    local config_file="$theme_dir/config-${theme_name}"
    
    # Validate theme files exist
    if [[ ! -f "$style_file" ]]; then
        log_message "ERROR" "Style file not found: $style_file"
        notify-send "Waybar Theme Error" "Style file not found for theme: $theme_name" -u critical
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log_message "ERROR" "Config file not found: $config_file"
        notify-send "Waybar Theme Error" "Config file not found for theme: $theme_name" -u critical
        return 1
    fi
    
    # Backup current configuration
    backup_config
    
    # Apply new theme
    log_message "INFO" "Applying theme: $theme_name"
    
    if cp "$style_file" "$STYLE_CSS" && cp "$config_file" "$CONFIG_JSON"; then
        log_message "INFO" "Theme files copied successfully"
        
        # Restart waybar service
        if systemctl --user restart "$SERVICE_NAME"; then
            log_message "INFO" "Waybar service restarted with new theme"
            notify-send "Waybar Theme" \
                "Applied theme: $theme_name\\nService restarted successfully" \
                -u low
        else
            log_message "ERROR" "Failed to restart waybar service"
            notify-send "Waybar Theme Error" \
                "Theme applied but service restart failed" \
                -u critical
            return 1
        fi
    else
        log_message "ERROR" "Failed to copy theme files"
        notify-send "Waybar Theme Error" "Failed to apply theme: $theme_name" -u critical
        return 1
    fi
}

# Function to generate menu options
generate_menu() {
    # Find theme preview images
    if [[ -d "$ASSETS_DIR" ]]; then
        find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) \
            | while read -r image; do
                echo "img:$image"
            done
    fi
    
    # Also list available themes by directory
    if [[ -d "$THEMES_DIR" ]]; then
        find "$THEMES_DIR" -maxdepth 1 -type d ! -path "$THEMES_DIR" \
            | while read -r theme_dir; do
                local theme_name
                theme_name="$(basename "$theme_dir")"
                echo "theme:$theme_name"
            done
    fi
}

# Function to show theme selector
show_selector() {
    local choice
    
    # Use rofi for theme selection with UWSM integration
    choice=$(generate_menu | uwsm app -- rofi -dmenu \
        -p "🎨 Select Waybar Theme" \
        -theme-str 'window {width: 600px;} listview {lines: 8;}' \
        -i -markup-rows)
    
    if [[ -z "$choice" ]]; then
        log_message "INFO" "Theme selection cancelled"
        return 0
    fi
    
    # Parse selection
    local selection_type="${choice%%:*}"
    local selection_value="${choice#*:}"
    
    case "$selection_type" in
        "img")
            # Map image to theme name
            local image_name
            image_name="$(basename "$selection_value" | sed 's/\.[^.]*$//')"
            
            case "$image_name" in
                "experimental")
                    apply_theme "experimental"
                    ;;
                "main"|"default")
                    apply_theme "default"
                    ;;
                "line")
                    apply_theme "line"
                    ;;
                "zen")
                    apply_theme "zen"
                    ;;
                *)
                    log_message "WARNING" "Unknown image mapping: $image_name"
                    notify-send "Waybar Theme" "Unknown theme for image: $image_name" -u normal
                    ;;
            esac
            ;;
        "theme")
            apply_theme "$selection_value"
            ;;
        *)
            log_message "ERROR" "Unknown selection type: $selection_type"
            ;;
    esac
}

# Function to list available themes
list_themes() {
    echo "Available Waybar Themes:"
    echo "======================="
    
    if [[ ! -d "$THEMES_DIR" ]]; then
        echo "No themes directory found: $THEMES_DIR"
        return 1
    fi
    
    find "$THEMES_DIR" -maxdepth 1 -type d ! -path "$THEMES_DIR" | while read -r theme_dir; do
        local theme_name
        theme_name="$(basename "$theme_dir")"
        local style_file="$theme_dir/style-${theme_name}.css"
        local config_file="$theme_dir/config-${theme_name}"
        
        printf "%-15s " "$theme_name"
        
        if [[ -f "$style_file" && -f "$config_file" ]]; then
            echo "✓ Complete"
        else
            echo "✗ Incomplete (missing files)"
        fi
    done
}

# Main function
main() {
    case "${1:-select}" in
        select|--select|-s)
            show_selector
            ;;
        list|--list|-l)
            list_themes
            ;;
        apply|--apply|-a)
            if [[ -n "${2:-}" ]]; then
                apply_theme "$2"
            else
                echo "Error: Theme name required" >&2
                echo "Usage: $0 apply <theme_name>" >&2
                exit 1
            fi
            ;;
        --help|-h)
            cat <<EOF
Waybar Theme Selector - UWSM Integrated

Usage: $0 [COMMAND] [THEME_NAME]

COMMANDS:
    select      Show interactive theme selector (default)
    list        List available themes
    apply       Apply specific theme by name
    --help      Show this help

Features:
    - Interactive theme selection with rofi
    - Automatic configuration backup
    - Proper systemd service management
    - UWSM session integration
    - Error handling and notifications

Theme Structure:
    Themes should be in: $THEMES_DIR/THEME_NAME/
    Required files:
        - style-THEME_NAME.css
        - config-THEME_NAME

Examples:
    $0 select           # Show interactive selector
    $0 list             # List all themes
    $0 apply default    # Apply default theme directly
EOF
            ;;
        *)
            log_message "ERROR" "Unknown command: $1"
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
}

main "$@"
