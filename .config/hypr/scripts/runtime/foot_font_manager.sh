#!/usr/bin/env bash
# =============================================================================
# Foot Font Manager
# =============================================================================
# Dynamic font size switcher for Foot terminal based on monitor setup
# Automatically detects monitor resolution and switches between laptop and
# external monitor font configurations
#
# Version 2.1.0 Changes (2025-10-30):
# - Intelligent restart logic: automatically restarts if no terminals are open
# - Preserves terminals if any are active, notifies user to restart manually
# - Improved notifications with actionable instructions
# - Fixes issue where new terminals wouldn't get updated font without restart
#
# Version 2.0.0 Changes:
# - Preserves existing terminals during automatic monitor switches
# - Only new terminals use the updated font size
# - Optional force-restart commands available for immediate application
# - Adds desktop notifications when configuration changes
#
# Dependencies: foot, systemd, jq, hyprctl, notify-send (optional)
# =============================================================================

set -euo pipefail

########################################################################
#                           CONFIGURATION                              #
########################################################################

readonly SCRIPT_NAME="foot_font_manager"
readonly VERSION="2.1.0"

# Paths
readonly CONFIG_DIR="$HOME/.config/foot"
readonly BASE_CONFIG="$CONFIG_DIR/foot.ini"
readonly LAPTOP_CONFIG="$CONFIG_DIR/foot_laptop.ini"
readonly EXTERNAL_CONFIG="$CONFIG_DIR/foot_external.ini"
readonly STATE_FILE="/run/user/$(id -u)/foot_font_state"

# Font sizes (adjust these to your preference)
readonly LAPTOP_FONT_SIZE=8      # Smaller for 1080p 17" laptop screen
readonly EXTERNAL_FONT_SIZE=10   # Perfect for 1440p 27" external monitor

# Service name
readonly SERVICE_NAME="foot-server.service"

########################################################################
#                           LOGGING SYSTEM                             #
########################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    
    echo "[$timestamp] [$SCRIPT_NAME] [$level] $message" >&2
    
    # Log to systemd journal
    local priority
    case "$level" in
        "ERROR") priority="err" ;;
        "WARN")  priority="warning" ;;
        "INFO")  priority="info" ;;
        "DEBUG") priority="debug" ;;
        *) priority="info" ;;
    esac
    
    echo "$message" | systemd-cat -t "$SCRIPT_NAME" -p "$priority" 2>/dev/null || true
}

########################################################################
#                         UTILITY FUNCTIONS                            #
########################################################################

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in foot hyprctl jq systemctl; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Get current active monitor resolution
get_primary_resolution() {
    local monitor_info
    if ! monitor_info=$(hyprctl monitors -j 2>/dev/null); then
        log "ERROR" "Failed to get monitor information from Hyprland"
        return 1
    fi
    
    # Get the resolution of the first active monitor
    echo "$monitor_info" | jq -r '.[0].width' 2>/dev/null || echo "1920"
}

# Determine optimal font size based on monitor setup
determine_font_size() {
    local resolution
    resolution=$(get_primary_resolution)
    
    case "$resolution" in
        2560) echo "$EXTERNAL_FONT_SIZE" ;;  # 1440p external monitor
        1920) echo "$LAPTOP_FONT_SIZE" ;;    # 1080p laptop screen
        *) 
            log "WARN" "Unknown resolution: ${resolution}. Defaulting to laptop font size."
            echo "$LAPTOP_FONT_SIZE"
            ;;
    esac
}

########################################################################
#                    CONFIGURATION FILE MANAGEMENT                     #
########################################################################

# Create font-specific configuration files
create_config_variants() {
    if [[ ! -f "$BASE_CONFIG" ]]; then
        log "ERROR" "Base configuration file not found: $BASE_CONFIG"
        exit 1
    fi
    
    log "INFO" "Creating configuration variants..."
    
    # Create laptop configuration (smaller font)
    sed "s/size=[0-9]\+/size=$LAPTOP_FONT_SIZE/g" "$BASE_CONFIG" > "$LAPTOP_CONFIG"
    log "INFO" "Created laptop config with font size $LAPTOP_FONT_SIZE"
    
    # Create external monitor configuration (larger font)
    sed "s/size=[0-9]\+/size=$EXTERNAL_FONT_SIZE/g" "$BASE_CONFIG" > "$EXTERNAL_CONFIG"
    log "INFO" "Created external config with font size $EXTERNAL_FONT_SIZE"
}

# Switch to specified configuration
switch_config() {
    local target_config="$1"
    local config_name="$2"
    
    if [[ ! -f "$target_config" ]]; then
        log "ERROR" "Configuration file not found: $target_config"
        return 1
    fi
    
    # Backup current config if it's not a symlink
    if [[ -f "$BASE_CONFIG" && ! -L "$BASE_CONFIG" ]]; then
        cp "$BASE_CONFIG" "${BASE_CONFIG}.backup"
    fi
    
    # Remove existing config and create symlink
    rm -f "$BASE_CONFIG"
    ln -sf "$target_config" "$BASE_CONFIG"
    
    log "INFO" "Switched to $config_name configuration"
    
    # Update state file
    echo "$config_name" > "$STATE_FILE"
    
    return 0
}

# Check if there are active foot terminals
count_active_terminals() {
    if command_exists hyprctl; then
        hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "foot") | .class' 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# Send notification about configuration change
notify_config_change() {
    local config_type="$1"
    local font_size="$2"
    local restarted="$3"

    # Only send notification if notify-send is available
    if command_exists notify-send; then
        if [[ "$restarted" == "true" ]]; then
            notify-send \
                -i utilities-terminal \
                "Foot Terminal Config" \
                "Switched to ${config_type} config (size ${font_size})\nServer restarted - all terminals using new font" \
                --expire-time=3000 2>/dev/null || true
        else
            notify-send \
                -i utilities-terminal -u critical \
                "Foot Terminal Config" \
                "Config updated but terminals preserved\nRestart server to apply: SUPER+SHIFT+T" \
                --expire-time=8000 2>/dev/null || true
        fi
    fi
}

# Restart foot server to apply new configuration
# NOTE: This is only used if explicitly requested, NOT during automatic monitor switches
restart_foot_server() {
    log "INFO" "Restarting foot server to apply new configuration..."

    if systemctl --user is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        if systemctl --user restart "$SERVICE_NAME"; then
            log "INFO" "Successfully restarted foot server"

            # Brief wait for service to stabilize
            sleep 1

            # Verify service is running
            if systemctl --user is-active "$SERVICE_NAME" >/dev/null 2>&1; then
                log "INFO" "Foot server is running successfully"
                return 0
            else
                log "ERROR" "Foot server failed to start after restart"
                return 1
            fi
        else
            log "ERROR" "Failed to restart foot server"
            return 1
        fi
    else
        log "WARN" "Foot server was not running, starting it..."
        if systemctl --user start "$SERVICE_NAME"; then
            log "INFO" "Successfully started foot server"
            return 0
        else
            log "ERROR" "Failed to start foot server"
            return 1
        fi
    fi
}

########################################################################
#                           MAIN FUNCTIONS                             #
########################################################################

# Switch to laptop configuration
switch_to_laptop() {
    local force_restart="${1:-false}"

    log "INFO" "Switching to laptop configuration..."
    if switch_config "$LAPTOP_CONFIG" "laptop"; then
        local active_terminals
        active_terminals=$(count_active_terminals)

        if [[ "$force_restart" == "true" ]]; then
            log "INFO" "Force restart requested, restarting foot server..."
            restart_foot_server
            notify_config_change "laptop" "$LAPTOP_FONT_SIZE" "true"
        elif [[ "$active_terminals" -eq 0 ]]; then
            log "INFO" "No active terminals detected, safe to restart server"
            restart_foot_server
            notify_config_change "laptop" "$LAPTOP_FONT_SIZE" "true"
        else
            log "INFO" "Configuration switched. ${active_terminals} terminal(s) preserved."
            log "WARN" "Foot server NOT restarted - new terminals will still use old config until server restart"
            notify_config_change "laptop" "$LAPTOP_FONT_SIZE" "false"
        fi
    fi
}

# Switch to external monitor configuration
switch_to_external() {
    local force_restart="${1:-false}"

    log "INFO" "Switching to external monitor configuration..."
    if switch_config "$EXTERNAL_CONFIG" "external"; then
        local active_terminals
        active_terminals=$(count_active_terminals)

        if [[ "$force_restart" == "true" ]]; then
            log "INFO" "Force restart requested, restarting foot server..."
            restart_foot_server
            notify_config_change "external" "$EXTERNAL_FONT_SIZE" "true"
        elif [[ "$active_terminals" -eq 0 ]]; then
            log "INFO" "No active terminals detected, safe to restart server"
            restart_foot_server
            notify_config_change "external" "$EXTERNAL_FONT_SIZE" "true"
        else
            log "INFO" "Configuration switched. ${active_terminals} terminal(s) preserved."
            log "WARN" "Foot server NOT restarted - new terminals will still use old config until server restart"
            notify_config_change "external" "$EXTERNAL_FONT_SIZE" "false"
        fi
    fi
}

# Auto-detect and switch configuration
auto_switch() {
    local optimal_size
    optimal_size=$(determine_font_size)
    
    local current_state=""
    if [[ -f "$STATE_FILE" ]]; then
        current_state=$(cat "$STATE_FILE" 2>/dev/null || echo "")
    fi
    
    if [[ "$optimal_size" == "$EXTERNAL_FONT_SIZE" ]]; then
        if [[ "$current_state" != "external" ]]; then
            log "INFO" "Detected external monitor, switching configuration..."
            switch_to_external
        else
            log "DEBUG" "Already using external monitor configuration"
        fi
    else
        if [[ "$current_state" != "laptop" ]]; then
            log "INFO" "Detected laptop display, switching configuration..."
            switch_to_laptop
        else
            log "DEBUG" "Already using laptop configuration"
        fi
    fi
}

# Initialize configuration files if they don't exist
init_configs() {
    log "INFO" "Initializing foot configuration variants..."
    
    # Ensure config directory exists
    mkdir -p "$CONFIG_DIR"
    
    # Create variants if they don't exist
    if [[ ! -f "$LAPTOP_CONFIG" || ! -f "$EXTERNAL_CONFIG" ]]; then
        create_config_variants
    fi
    
    # If base config is not a symlink, make it point to auto-detected config
    if [[ ! -L "$BASE_CONFIG" ]]; then
        log "INFO" "Setting up initial configuration..."
        auto_switch
    fi
}

# Show current status
show_status() {
    echo "=== Foot Font Manager Status ==="
    echo "Version: $VERSION"
    echo
    
    local current_resolution
    current_resolution=$(get_primary_resolution)
    echo "Current monitor resolution: ${current_resolution}px"
    
    local optimal_size
    optimal_size=$(determine_font_size)
    echo "Optimal font size: $optimal_size"
    
    if [[ -f "$STATE_FILE" ]]; then
        local current_state
        current_state=$(cat "$STATE_FILE")
        echo "Current configuration: $current_state"
    else
        echo "Current configuration: unknown"
    fi
    
    echo
    echo "Available configurations:"
    echo "  laptop: font size $LAPTOP_FONT_SIZE (for 1080p laptop screen)"
    echo "  external: font size $EXTERNAL_FONT_SIZE (for 1440p external monitor)"
    
    echo
    echo "Service status:"
    if systemctl --user is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        echo "  foot-server: running"
    else
        echo "  foot-server: not running"
    fi
}

# Display usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND]

Dynamic Foot Terminal Font Size Manager v$VERSION

COMMANDS:
    auto            Auto-detect monitor and switch configuration (default)
    laptop          Switch to laptop configuration (font size $LAPTOP_FONT_SIZE)
    external        Switch to external monitor configuration (font size $EXTERNAL_FONT_SIZE)
    laptop-restart  Switch to laptop config and restart all terminals
    external-restart Switch to external config and restart all terminals
    init            Initialize configuration files
    status          Show current status
    help            Show this help message

BEHAVIOR:
    By default, configuration changes preserve existing terminals.
    Only new terminals opened after the switch will use the new font size.
    Use the *-restart commands to close all terminals and apply immediately.

EXAMPLES:
    $0              # Auto-detect and switch (preserves terminals)
    $0 auto         # Same as above
    $0 laptop       # Switch to laptop config (preserves terminals)
    $0 external     # Switch to external config (preserves terminals)
    $0 laptop-restart   # Switch to laptop and restart all terminals
    $0 external-restart # Switch to external and restart all terminals
    $0 status       # Show current status

CONFIGURATION:
    Base config: $BASE_CONFIG
    Laptop config: $LAPTOP_CONFIG
    External config: $EXTERNAL_CONFIG

For more information, see: https://codeberg.org/dnkl/foot/wiki
EOF
}

########################################################################
#                              MAIN                                    #
########################################################################

main() {
    local command="${1:-auto}"

    # Check dependencies first
    check_dependencies

    case "$command" in
        "auto"|"")
            init_configs
            auto_switch
            ;;
        "laptop")
            init_configs
            switch_to_laptop false
            ;;
        "external")
            init_configs
            switch_to_external false
            ;;
        "laptop-restart")
            init_configs
            switch_to_laptop true
            ;;
        "external-restart")
            init_configs
            switch_to_external true
            ;;
        "init")
            init_configs
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            usage
            ;;
        *)
            log "ERROR" "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
