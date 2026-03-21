#!/usr/bin/env bash
# =============================================================================
# Hyprland System Integration
# =============================================================================
# Integrates system monitoring with Hyprland, waybar, and swaync
# Sets up monitoring scripts and notification handlers
#
# Dependencies: waybar, swaync
# =============================================================================

set -euo pipefail

# Configuration paths
readonly HYPR_SCRIPTS_DIR="$HOME/.config/hypr/scripts"
readonly SYSTEM_SCRIPTS_DIR="$HYPR_SCRIPTS_DIR/system"
readonly WAYBAR_CONFIG_DIR="$HOME/.config/waybar"
readonly SWAYNC_CONFIG_DIR="$HOME/.config/swaync"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to setup directory structure
setup_directories() {
    print_status "$BLUE" "=== Setting Up Directory Structure ==="
    
    # Create system script directories
    mkdir -p "$SYSTEM_SCRIPTS_DIR"/{diagnostics,monitoring,power}
    
    # Create symlinks for easy access
    ln -sf "$SYSTEM_SCRIPTS_DIR/diagnostics/system_crash_fix.sh" "$HOME/.local/bin/system-crash-fix" 2>/dev/null || true
    ln -sf "$SYSTEM_SCRIPTS_DIR/diagnostics/usbc_pd_monitor.sh" "$HOME/.local/bin/usbc-monitor" 2>/dev/null || true
    ln -sf "$SYSTEM_SCRIPTS_DIR/diagnostics/system_maintenance.sh" "$HOME/.local/bin/system-maintenance" 2>/dev/null || true
    
    print_status "$GREEN" "✓ Directory structure created"
    print_status "$GREEN" "✓ Symlinks created in ~/.local/bin/"
}

# Function to create waybar module for system status
create_waybar_system_module() {
    print_status "$BLUE" "=== Creating Waybar System Status Module ==="
    
    local waybar_system_script="$SYSTEM_SCRIPTS_DIR/monitoring/waybar_system_status.sh"
    
    cat > "$waybar_system_script" << 'EOF'
#!/usr/bin/env bash
# Waybar System Status Module
# Shows USB-C, thermal, and system health status
# Location: ~/.config/hypr/scripts/system/monitoring/waybar_system_status.sh

# Get system health indicators
get_system_status() {
    local status="good"
    local icon="✓"
    local color="#50fa7b"  # Green
    local tooltip="System: OK"
    
    # Check temperature
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    temp=$((temp / 1000))
    
    if [[ $temp -gt 80 ]]; then
        status="hot"
        icon="🔥"
        color="#ff5555"  # Red
        tooltip="System: High temperature (${temp}°C)"
    elif [[ $temp -gt 70 ]]; then
        status="warm"
        icon="⚠"
        color="#f1fa8c"  # Yellow
        tooltip="System: Warm (${temp}°C)"
    fi
    
    # Check for recent USB-C errors
    if dmesg | tail -20 | grep -qi "xhci.*error\|xhci.*died"; then
        status="usb_error"
        icon="🔌"
        color="#ff5555"  # Red
        tooltip="System: USB-C controller issue detected"
    fi
    
    # Check memory usage
    local mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}')
    if [[ $mem_usage -gt 90 ]]; then
        status="memory_high"
        icon="⚠"
        color="#ffb86c"  # Orange
        tooltip="System: High memory usage (${mem_usage}%)"
    fi
    
    # Output JSON for waybar
    echo "{\"text\":\"$icon\",\"tooltip\":\"$tooltip\",\"class\":\"$status\",\"color\":\"$color\"}"
}

case "${1:-status}" in
    status)
        get_system_status
        ;;
    click)
        # Handle click events
        case "${2:-left}" in
            left)
                # Show system information
                notify-send "System Status" "$(sensors 2>/dev/null | head -10)" --expire-time=5000
                ;;
            right)
                # Open system monitor
                hyprctl dispatch exec "foot -e htop"
                ;;
            middle)
                # Run USB-C diagnostics
                hyprctl dispatch exec "foot -e ~/.config/hypr/scripts/system/diagnostics/usbc_pd_monitor.sh --hardware"
                ;;
        esac
        ;;
esac
EOF

    chmod +x "$waybar_system_script"
    
    # Create waybar configuration snippet
    local waybar_config_snippet="$WAYBAR_CONFIG_DIR/modules/system_status.json"
    mkdir -p "$WAYBAR_CONFIG_DIR/modules"
    
    cat > "$waybar_config_snippet" << 'EOF'
{
    "custom/system-status": {
        "exec": "~/.config/hypr/scripts/system/monitoring/waybar_system_status.sh status",
        "return-type": "json",
        "interval": 10,
        "tooltip": true,
        "on-click": "~/.config/hypr/scripts/system/monitoring/waybar_system_status.sh click left",
        "on-click-right": "~/.config/hypr/scripts/system/monitoring/waybar_system_status.sh click right",
        "on-click-middle": "~/.config/hypr/scripts/system/monitoring/waybar_system_status.sh click middle",
        "format": "{icon}",
        "format-icons": {
            "good": "✓",
            "warm": "⚠",
            "hot": "🔥",
            "usb_error": "🔌",
            "memory_high": "⚠"
        }
    }
}
EOF

    print_status "$GREEN" "✓ Waybar system status module created"
    print_status "$YELLOW" "Add '\"custom/system-status\"' to your waybar modules list"
}

# Function to setup swaync integration
setup_swaync_integration() {
    print_status "$BLUE" "=== Setting Up Swaync Integration ==="
    
    local swaync_system_script="$SYSTEM_SCRIPTS_DIR/monitoring/swaync_system_alerts.sh"
    
    cat > "$swaync_system_script" << 'EOF'
#!/usr/bin/env bash
# Swaync System Alerts Integration
# Sends system health notifications through swaync
# Location: ~/.config/hypr/scripts/system/monitoring/swaync_system_alerts.sh

send_system_alert() {
    local level=$1
    local title=$2
    local message=$3
    local icon=${4:-"dialog-information"}
    
    case "$level" in
        critical)
            swaync-client -n --title "$title" --body "$message" --icon "$icon" --urgency critical --expire-time 0
            ;;
        warning)
            swaync-client -n --title "$title" --body "$message" --icon "$icon" --urgency normal --expire-time 10000
            ;;
        info)
            swaync-client -n --title "$title" --body "$message" --icon "$icon" --urgency low --expire-time 5000
            ;;
    esac
}

# Check system health and send alerts
check_and_alert() {
    # Check temperature
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    temp=$((temp / 1000))
    
    if [[ $temp -gt 85 ]]; then
        send_system_alert "critical" "System Overheating" "CPU temperature: ${temp}°C - Consider closing applications" "dialog-warning"
    elif [[ $temp -gt 75 ]]; then
        send_system_alert "warning" "High Temperature" "CPU temperature: ${temp}°C" "dialog-information"
    fi
    
    # Check for USB-C errors
    if dmesg | tail -10 | grep -qi "xhci.*died\|xhci.*error"; then
        send_system_alert "critical" "USB-C Controller Error" "Hardware failure detected - check system logs" "dialog-error"
    fi
    
    # Check memory usage
    local mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}')
    if [[ $mem_usage -gt 95 ]]; then
        send_system_alert "warning" "Low Memory" "Memory usage: ${mem_usage}% - Consider closing applications" "dialog-warning"
    fi
    
    # Check disk usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 95 ]]; then
        send_system_alert "critical" "Disk Almost Full" "Root filesystem: ${disk_usage}% full" "dialog-error"
    elif [[ $disk_usage -gt 85 ]]; then
        send_system_alert "warning" "Disk Getting Full" "Root filesystem: ${disk_usage}% full" "dialog-warning"
    fi
}

case "${1:-check}" in
    check)
        check_and_alert
        ;;
    test)
        send_system_alert "info" "System Monitor Test" "System monitoring is working correctly" "dialog-information"
        ;;
esac
EOF

    chmod +x "$swaync_system_script"
    
    print_status "$GREEN" "✓ Swaync system alerts integration created"
}

# Function to setup systemd user services
setup_systemd_services() {
    print_status "$BLUE" "=== Setting Up Systemd User Services ==="
    
    local systemd_user_dir="$HOME/.config/systemd/user"
    mkdir -p "$systemd_user_dir"
    
    # System health monitoring service
    cat > "$systemd_user_dir/hypr-system-monitor.service" << EOF
[Unit]
Description=Hyprland System Health Monitor
Documentation=file://$SYSTEM_SCRIPTS_DIR/monitoring/swaync_system_alerts.sh

[Service]
Type=oneshot
ExecStart=$SYSTEM_SCRIPTS_DIR/monitoring/swaync_system_alerts.sh check
Environment=HOME=$HOME
Environment=WAYLAND_DISPLAY=wayland-1
EOF

    # System health monitoring timer
    cat > "$systemd_user_dir/hypr-system-monitor.timer" << 'EOF'
[Unit]
Description=Run Hyprland System Health Monitor every 2 minutes
Requires=hypr-system-monitor.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
EOF

    # Enable the timer
    systemctl --user daemon-reload
    systemctl --user enable hypr-system-monitor.timer
    systemctl --user start hypr-system-monitor.timer
    
    print_status "$GREEN" "✓ Systemd user services created and enabled"
}

# Function to create keybindings
create_keybindings() {
    print_status "$BLUE" "=== Creating Hyprland Keybindings ==="
    
    local keybind_config="$HOME/.config/hypr/conf/system_keybinds.conf"
    
    cat > "$keybind_config" << 'EOF'
# System Monitoring and Diagnostics Keybindings
# Include this in your main hyprland.conf with: source = ~/.config/hypr/conf/system_keybinds.conf

# System monitoring shortcuts
bind = SUPER SHIFT, F1, exec, uwsm app -- foot -e ~/.config/hypr/scripts/system/diagnostics/usbc_pd_monitor.sh --hardware
bind = SUPER SHIFT, F2, exec, uwsm app -- foot -e ~/.config/hypr/scripts/system/diagnostics/system_crash_fix.sh
bind = SUPER SHIFT, F3, exec, uwsm app -- foot -e ~/.config/hypr/scripts/system/diagnostics/system_maintenance.sh

# Quick system status
bind = SUPER SHIFT, F4, exec, ~/.config/hypr/scripts/system/monitoring/swaync_system_alerts.sh test

# Open system logs
bind = SUPER SHIFT, F5, exec, uwsm app -- foot -e journalctl -f -p err

# Temperature monitoring
bind = SUPER SHIFT, F6, exec, notify-send "System Temperature" "$(sensors 2>/dev/null | head -10)"

# System resource monitoring
bind = SUPER SHIFT, F7, exec, uwsm app -- foot -e htop
bind = SUPER SHIFT, F8, exec, uwsm app -- foot -e iostat -x 1

# Emergency: disable USB autosuspend temporarily
bind = SUPER SHIFT CTRL, U, exec, echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend && notify-send "USB Autosuspend" "Disabled temporarily"
EOF

    print_status "$GREEN" "✓ Keybinding configuration created"
    print_status "$YELLOW" "Add 'source = ~/.config/hypr/conf/system_keybinds.conf' to your hyprland.conf"
}

# Function to show integration summary
show_integration_summary() {
    print_status "$BLUE" "=== Integration Summary ==="
    
    cat << EOF
System monitoring integration created with the following components:

DIRECTORY STRUCTURE:
  ~/.config/hypr/scripts/system/
  ├── diagnostics/          # Crash fix and diagnostic scripts
  ├── monitoring/           # Ongoing monitoring scripts  
  └── power/               # Power management scripts

WAYBAR INTEGRATION:
  - System status module created
  - Shows temperature, USB-C status, memory usage
  - Click handlers for quick actions

SWAYNC INTEGRATION:  
  - Automatic system health alerts
  - Critical/warning/info notification levels
  - Monitors temperature, USB-C, memory, disk

SYSTEMD SERVICES:
  - hypr-system-monitor.timer (every 2 minutes)
  - Automatic health monitoring in background

KEYBINDINGS:
  - SUPER+SHIFT+F1: USB-C hardware check
  - SUPER+SHIFT+F2: Run crash fix script
  - SUPER+SHIFT+F3: System maintenance
  - SUPER+SHIFT+F4: Test notifications
  - SUPER+SHIFT+F5: Monitor error logs
  - SUPER+SHIFT+F6: Show temperature
  - SUPER+SHIFT+F7: Open htop
  - SUPER+SHIFT+F8: Open iostat

QUICK ACCESS COMMANDS:
  - system-crash-fix      # Main crash fix script
  - usbc-monitor         # USB-C PD monitoring  
  - system-maintenance   # Weekly maintenance

MANUAL CONFIGURATION NEEDED:
1. Add to waybar config: "custom/system-status"
2. Add to hyprland.conf: source = ~/.config/hypr/conf/system_keybinds.conf
3. Test with: systemctl --user status hypr-system-monitor.timer

Next steps:
1. Place your diagnostic scripts in ~/.config/hypr/scripts/system/diagnostics/
2. Run this integration script: chmod +x hypr_system_integration.sh && ./hypr_system_integration.sh
3. Restart Hyprland to load new keybindings
4. Add waybar module to your waybar configuration
EOF
}

# Main function
main() {
    print_status "$BLUE" "=== Hyprland System Integration Setup ==="
    
    setup_directories
    create_waybar_system_module
    setup_swaync_integration
    setup_systemd_services
    create_keybindings
    show_integration_summary
    
    print_status "$GREEN" "=== Integration setup completed ==="
}

# Execute main function
main "$@"
