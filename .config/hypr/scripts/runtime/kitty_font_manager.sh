#!/usr/bin/env bash
# =============================================================================
# Kitty Font Manager
# =============================================================================
# Dynamic font size switcher for Kitty terminal based on monitor setup
# Mirrors the functionality of foot_font_manager.sh
#
# Version 1.0.0 (2026-02-06)
# Based on foot_font_manager.sh v2.1.0 architecture
#
# Dependencies: kitty, hyprctl, jq, notify-send (optional)
# =============================================================================

set -euo pipefail

########################################################################
#                           CONFIGURATION                              #
########################################################################

readonly SCRIPT_NAME="kitty_font_manager"
readonly VERSION="1.0.0"

# Paths
readonly CONFIG_DIR="$HOME/.config/kitty"
readonly BASE_CONFIG="$CONFIG_DIR/kitty.conf"
readonly LAPTOP_CONFIG="$CONFIG_DIR/kitty_laptop.conf"
readonly EXTERNAL_CONFIG="$CONFIG_DIR/kitty_external.conf"
readonly STATE_FILE="/run/user/$(id -u)/kitty_font_state"

# Font sizes (adjusted for Kitty's typical sizing vs Foot)
readonly LAPTOP_FONT_SIZE="10.0"      # Readable on 1080p 17" laptop
readonly EXTERNAL_FONT_SIZE="12.0"    # Perfect for 1440p 27" external

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

    for cmd in kitty hyprctl jq; do
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
    sed "s/^font_size[[:space:]]\+[0-9.]\+/font_size $LAPTOP_FONT_SIZE/" "$BASE_CONFIG" > "$LAPTOP_CONFIG"
    log "INFO" "Created laptop config with font size $LAPTOP_FONT_SIZE"

    # Create external monitor configuration (larger font)
    sed "s/^font_size[[:space:]]\+[0-9.]\+/font_size $EXTERNAL_FONT_SIZE/" "$BASE_CONFIG" > "$EXTERNAL_CONFIG"
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

# Check if there are active Kitty terminals
count_active_terminals() {
    if command_exists hyprctl; then
        hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "kitty") | .class' 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# Send notification about configuration change
notify_config_change() {
    local config_type="$1"
    local font_size="$2"
    local applied="$3"

    # Only send notification if notify-send is available
    if command_exists notify-send; then
        if [[ "$applied" == "true" ]]; then
            notify-send \
                -i utilities-terminal \
                "Kitty Terminal Config" \
                "Switched to ${config_type} config (size ${font_size})\nApplied to running terminals" \
                --expire-time=3000 2>/dev/null || true
        else
            notify-send \
                -i utilities-terminal -u critical \
                "Kitty Terminal Config" \
                "Config updated (size ${font_size})\nRestart Kitty or open new windows to apply" \
                --expire-time=8000 2>/dev/null || true
        fi
    fi
}

# Apply configuration to running Kitty instances using remote control
apply_to_running_instances() {
    local font_size="$1"

    # Check if any Kitty instances are running
    local running_instances
    running_instances=$(count_active_terminals)

    if [[ "$running_instances" -eq 0 ]]; then
        log "DEBUG" "No running Kitty instances to update"
        return 0
    fi

    log "INFO" "Attempting to apply font size to $running_instances running instance(s)..."

    # Try to apply to all running instances
    # Note: This requires allow_remote_control to be enabled in kitty.conf
    if kitty @ --to unix:@mykitty set-font-size "$font_size" 2>/dev/null; then
        log "INFO" "Successfully applied font size to running instances"
        return 0
    else
        log "WARN" "Failed to apply to running instances (remote control may not be enabled)"
        return 1
    fi
}

########################################################################
#                           MAIN FUNCTIONS                             #
########################################################################

# Switch to laptop configuration
switch_to_laptop() {
    local try_apply="${1:-true}"

    log "INFO" "Switching to laptop configuration..."
    if switch_config "$LAPTOP_CONFIG" "laptop"; then
        local applied="false"

        if [[ "$try_apply" == "true" ]]; then
            if apply_to_running_instances "$LAPTOP_FONT_SIZE"; then
                applied="true"
            fi
        fi

        notify_config_change "laptop" "$LAPTOP_FONT_SIZE" "$applied"
    fi
}

# Switch to external monitor configuration
switch_to_external() {
    local try_apply="${1:-true}"

    log "INFO" "Switching to external monitor configuration..."
    if switch_config "$EXTERNAL_CONFIG" "external"; then
        local applied="false"

        if [[ "$try_apply" == "true" ]]; then
            if apply_to_running_instances "$EXTERNAL_FONT_SIZE"; then
                applied="true"
            fi
        fi

        notify_config_change "external" "$EXTERNAL_FONT_SIZE" "$applied"
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
    log "INFO" "Initializing Kitty configuration variants..."

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
    echo "=== Kitty Font Manager Status ==="
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
    local running_instances
    running_instances=$(count_active_terminals)
    echo "Running Kitty instances: $running_instances"

    if [[ -L "$BASE_CONFIG" ]]; then
        local link_target
        link_target=$(readlink "$BASE_CONFIG")
        echo "Config symlink points to: $link_target"
    else
        echo "Warning: Base config is not a symlink"
    fi
}

# Display usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND]

Dynamic Kitty Terminal Font Size Manager v$VERSION

COMMANDS:
    auto            Auto-detect monitor and switch configuration (default)
    laptop          Switch to laptop configuration (font size $LAPTOP_FONT_SIZE)
    external        Switch to external monitor configuration (font size $EXTERNAL_FONT_SIZE)
    init            Initialize configuration files
    status          Show current status
    help            Show this help message

BEHAVIOR:
    Configuration changes are applied to running Kitty instances if remote
    control is enabled. New Kitty windows will always use the updated config.

    To enable remote control, add to your kitty.conf:
        allow_remote_control yes
        listen_on unix:@mykitty

EXAMPLES:
    $0              # Auto-detect and switch
    $0 auto         # Same as above
    $0 laptop       # Switch to laptop config
    $0 external     # Switch to external config
    $0 status       # Show current status

CONFIGURATION:
    Base config: $BASE_CONFIG
    Laptop config: $LAPTOP_CONFIG (font size $LAPTOP_FONT_SIZE)
    External config: $EXTERNAL_CONFIG (font size $EXTERNAL_FONT_SIZE)

For more information, see: https://sw.kovidgoyal.net/kitty/
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
            switch_to_laptop
            ;;
        "external")
            init_configs
            switch_to_external
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
