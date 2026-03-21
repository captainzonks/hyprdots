#!/usr/bin/env bash
# =============================================================================
# Systemd Integration for UWSM + Hyprland
# =============================================================================
# Enhanced systemd integration with proper service dependency resolution
# Handles XDG desktop portals and Wayland session services
#
# Dependencies: systemctl, uwsm
# =============================================================================

set -euo pipefail

# Handle termination signals gracefully
cleanup() {
    log "Systemd integration script received termination signal, cleaning up..."
    # Kill any remaining portal processes we might have started
    pkill -f "xdg-desktop-portal" 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# Configuration
SERVICE_DIR="$HOME/.config/systemd/user"
LOG_FILE="$HOME/.local/state/systemd-integration.log"
PORTAL_CONFIG_DIR="$HOME/.config/xdg-desktop-portal"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$PORTAL_CONFIG_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log "Starting enhanced systemd integration for Hyprland session"

# Function to safely manage service states
manage_service() {
    local action="$1"
    local service="$2"
    local wait_time="${3:-0}"
    
    if systemctl --user list-unit-files "$service" >/dev/null 2>&1; then
        log "Attempting to $action service: $service"
        if systemctl --user "$action" "$service" 2>/dev/null; then
            log "Successfully ${action}ed $service"
            if [[ "$wait_time" -gt 0 ]]; then
                sleep "$wait_time"
            fi
        else
            log "Warning: Failed to $action $service"
        fi
    else
        log "Service $service not found, skipping"
    fi
}

# Function to verify portal configuration exists
verify_portal_config() {
    local config_file="$PORTAL_CONFIG_DIR/hyprland-portals.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log "Creating desktop portal configuration at $config_file"
        cat > "$config_file" << 'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Screencast=hyprland
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.OpenURI=gtk
EOF
        log "Portal configuration created"
    else
        log "Portal configuration already exists"
    fi
}

# Function to verify browser defaults are set
verify_browser_defaults() {
    local mimeapps_file="$HOME/.config/mimeapps.list"
    
    # Check if browser defaults are configured
    if [[ -f "$mimeapps_file" ]]; then
        if grep -q "x-scheme-handler/http" "$mimeapps_file" && grep -q "x-scheme-handler/https" "$mimeapps_file"; then
            log "Browser defaults are configured"
            return 0
        fi
    fi
    
    log "Browser defaults not found, will create basic configuration"
    
    # Find Firefox desktop file
    local firefox_desktop=""
    for desktop_file in firefox.desktop firefox-esr.desktop; do
        if find /usr/share/applications ~/.local/share/applications -name "$desktop_file" 2>/dev/null | grep -q .; then
            firefox_desktop="$desktop_file"
            break
        fi
    done
    
    if [[ -n "$firefox_desktop" ]]; then
        log "Configuring $firefox_desktop as default browser"
        
        # Create/update mimeapps.list
        mkdir -p "$(dirname "$mimeapps_file")"
        
        # Remove existing entries
        sed -i '/^text\/html=/d; /^x-scheme-handler\/http=/d; /^x-scheme-handler\/https=/d' "$mimeapps_file" 2>/dev/null || true
        
        # Add Default Applications section if it doesn't exist
        if ! grep -q "^\[Default Applications\]" "$mimeapps_file" 2>/dev/null; then
            echo "[Default Applications]" >> "$mimeapps_file"
        fi
        
        # Add browser associations
        {
            echo "text/html=$firefox_desktop"
            echo "x-scheme-handler/http=$firefox_desktop"
            echo "x-scheme-handler/https=$firefox_desktop"
            echo "x-scheme-handler/ftp=$firefox_desktop"
        } >> "$mimeapps_file"
        
        log "Browser defaults configured with $firefox_desktop"
    else
        log "Warning: No Firefox desktop file found for browser defaults"
    fi
}

# Simplified portal restart using systemd dependencies
restart_portals_simplified() {
    log "Simplified portal restart sequence initiated"
    
    # Verify configurations first
    verify_portal_config
    verify_browser_defaults
    
    # Update D-Bus environment - essential for portal communication
    log "Updating D-Bus environment for link handling"
    dbus-update-activation-environment --systemd --all 2>/dev/null || true
    
    # Import critical environment variables
    systemctl --user import-environment XDG_CURRENT_DESKTOP WAYLAND_DISPLAY XDG_SESSION_TYPE 2>/dev/null || true
    
    # Use systemd dependencies instead of manual service management
    log "Restarting portal services using systemd dependencies"
    systemctl --user restart xdg-desktop-portal.service 2>/dev/null || {
        log "Portal restart failed, attempting fresh start"
        systemctl --user stop xdg-desktop-portal.service 2>/dev/null || true
        sleep 2
        systemctl --user start xdg-desktop-portal.service 2>/dev/null || true
    }
    
    # Verify portal services are running
    if systemctl --user is-active xdg-desktop-portal.service >/dev/null 2>&1; then
        log "✓ Portal services active"
        return 0
    else
        log "✗ Portal services failed to start"
        return 1
    fi
}

# Original audio service management (keeping your existing logic)
restart_audio_services() {
    log "Managing audio services"
    
    # Audio services - be more careful with restart order
    if ! systemctl --user is-active pipewire.service >/dev/null 2>&1; then
        log "Starting PipeWire audio system"
        manage_service start pipewire.service 1
        manage_service start pipewire-pulse.service 1
        manage_service start wireplumber.service 1
    else
        log "PipeWire audio system already running"
    fi
}

# Main execution
main() {
    # Run simplified portal restart
    if restart_portals_simplified; then
        log "Portal setup completed successfully"
    else
        log "Portal setup completed with warnings - link handling may be affected"
    fi
    
    # Handle audio services
    restart_audio_services
    
    # Reload systemd to pick up any configuration changes
    log "Reloading systemd user daemon"
    systemctl --user daemon-reload
    
    log "Systemd integration completed"
    
    # Test link handling capability
    if command -v xdg-open >/dev/null && command -v firefox >/dev/null; then
        log "Link handling test: xdg-open available, browser configured"
    else
        log "Warning: Link handling may not work - missing xdg-open or browser"
    fi
}

# Execute main function
main "$@"
