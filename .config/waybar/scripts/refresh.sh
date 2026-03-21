#!/usr/bin/env bash
# ~/.config/waybar/scripts/refresh.sh
# UWSM-integrated waybar refresh with proper systemd management

set -euo pipefail

# Configuration
readonly SERVICE_NAME="waybar.service"
readonly MAX_WAIT_TIME=10
readonly LOG_TAG="waybar-refresh"

# Logging function
log_message() {
    local level="$1"
    shift
    echo "[$LOG_TAG] [$level] $*" >&2
    logger -t "$LOG_TAG" "[$level] $*" 2>/dev/null || true
}

# Function to check systemd service status
check_service_status() {
    systemctl --user is-active "$SERVICE_NAME" 2>/dev/null || echo "inactive"
}

# Function to wait for service state change
wait_for_service() {
    local target_state="$1"
    local max_wait="$2"
    local count=0
    
    while [[ "$(check_service_status)" != "$target_state" && $count -lt $max_wait ]]; do
        sleep 0.5
        ((count++))
    done
    
    [[ "$(check_service_status)" == "$target_state" ]]
}

# Function to restart waybar service
restart_waybar() {
    log_message "INFO" "Restarting waybar service..."
    
    if ! systemctl --user restart "$SERVICE_NAME"; then
        log_message "ERROR" "Failed to restart waybar service"
        notify-send "Waybar Error" "Failed to restart waybar service" -u critical
        return 1
    fi
    
    # Wait for service to become active
    if wait_for_service "active" $MAX_WAIT_TIME; then
        log_message "INFO" "Waybar service restarted successfully"
        notify-send "Waybar" "Service restarted successfully" -u low
    else
        log_message "WARNING" "Waybar service restart may have failed"
        notify-send "Waybar Warning" "Service restart verification failed" -u normal
    fi
}

# Function to toggle waybar service
toggle_waybar() {
    local current_status
    current_status="$(check_service_status)"
    
    case "$current_status" in
        "active")
            log_message "INFO" "Stopping waybar service..."
            if systemctl --user stop "$SERVICE_NAME"; then
                log_message "INFO" "Waybar service stopped"
                notify-send "Waybar" "Service stopped" -u low
            else
                log_message "ERROR" "Failed to stop waybar service"
                notify-send "Waybar Error" "Failed to stop service" -u critical
            fi
            ;;
        "inactive"|"failed")
            log_message "INFO" "Starting waybar service..."
            if systemctl --user start "$SERVICE_NAME"; then
                if wait_for_service "active" $MAX_WAIT_TIME; then
                    log_message "INFO" "Waybar service started successfully"
                    notify-send "Waybar" "Service started successfully" -u low
                else
                    log_message "WARNING" "Waybar service start verification failed"
                fi
            else
                log_message "ERROR" "Failed to start waybar service"
                notify-send "Waybar Error" "Failed to start service" -u critical
            fi
            ;;
        *)
            log_message "WARNING" "Unknown service status: $current_status"
            restart_waybar
            ;;
    esac
}

# Function to show service status
show_status() {
    local status
    status="$(check_service_status)"
    
    cat <<EOF
Waybar Service Status: $status

Recent logs:
$(journalctl --user -u "$SERVICE_NAME" --no-pager -n 5 2>/dev/null || echo "No logs available")

Service info:
$(systemctl --user status "$SERVICE_NAME" --no-pager -l 2>/dev/null || echo "Service not found")
EOF
}

# Main function
main() {
    case "${1:-restart}" in
        restart|--restart|-r)
            restart_waybar
            ;;
        toggle|--toggle|-t)
            toggle_waybar
            ;;
        status|--status|-s)
            show_status
            ;;
        --help|-h)
            cat <<EOF
Waybar Refresh Script - UWSM Integrated

Usage: $0 [COMMAND]

COMMANDS:
    restart     Restart waybar service (default)
    toggle      Toggle waybar service on/off
    status      Show service status and logs
    --help      Show this help

Features:
    - Proper systemd service management
    - UWSM session integration
    - Error handling and logging
    - Desktop notifications
    - Service state verification

Configuration:
    Service: $SERVICE_NAME
    Max wait time: ${MAX_WAIT_TIME}s
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
