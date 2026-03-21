#!/usr/bin/env bash
# =============================================================================
# Foot Server Health Monitor
# =============================================================================
# Continuous background monitoring for Foot terminal server
# Monitors server health and handles monitor configuration changes
# Provides automatic recovery beyond systemd's basic restart capabilities
#
# Dependencies: systemctl, footclient, hyprctl, jq
# =============================================================================

set -euo pipefail

########################################################################
#                           CONFIGURATION                              #
########################################################################

readonly SERVICE_NAME="foot-server.service"
readonly LOG_TAG="foot-monitor"
readonly STATE_FILE="/run/user/$(id -u)/foot-monitor-state"

# Monitoring intervals (in seconds)
readonly HEALTH_CHECK_INTERVAL=30
readonly GRACE_PERIOD_AFTER_MONITOR_CHANGE=3

# Failure thresholds
readonly MAX_CONSECUTIVE_FAILURES=2

# State tracking
consecutive_failures=0

########################################################################
#                           LOGGING SYSTEM                             #
########################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    
    # Log to stderr for debugging
    echo "[$timestamp] [$level] $message" >&2
    
    # Also log to journal
    local priority
    case "$level" in
        "ERROR") priority="err" ;;
        "WARN")  priority="warning" ;;
        "INFO")  priority="info" ;;
        "DEBUG") priority="debug" ;;
        *) priority="info" ;;
    esac
    
    echo "$message" | systemd-cat -t "$LOG_TAG" -p "$priority" 2>/dev/null || true
}

########################################################################
#                         HEALTH CHECK FUNCTIONS                       #
########################################################################

# Test foot server responsiveness via footclient
is_foot_responsive() {
    timeout 3 footclient --version >/dev/null 2>&1
}

# Check if systemd service is running
is_service_running() {
    systemctl --user is-active "$SERVICE_NAME" >/dev/null 2>&1
}

# Comprehensive health check
perform_health_check() {
    # Check both service status and actual responsiveness
    is_service_running && is_foot_responsive
}

########################################################################
#                      MONITOR CHANGE DETECTION                        #
########################################################################

# Get current monitor configuration
get_monitor_state() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl monitors -j 2>/dev/null | jq -r '[.[].name] | sort | join(",")' 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Save current monitor state
save_monitor_state() {
    local state="$1"
    echo "$state" > "$STATE_FILE" 2>/dev/null || true
}

# Get previous monitor state
get_previous_monitor_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Check for monitor configuration changes and handle them
check_monitor_changes() {
    local current_state
    local previous_state
    
    current_state=$(get_monitor_state)
    previous_state=$(get_previous_monitor_state)
    
    if [[ "$current_state" != "$previous_state" ]] && [[ "$previous_state" != "unknown" ]]; then
        log "INFO" "Monitor configuration changed: $previous_state → $current_state"
        
        # Give system time to stabilize after monitor change
        sleep "$GRACE_PERIOD_AFTER_MONITOR_CHANGE"
        
        # Check if foot server is still healthy after the change
        if ! perform_health_check; then
            log "WARN" "Foot server became unhealthy after monitor change"
            restart_foot_service
        else
            log "DEBUG" "Foot server remained healthy after monitor change"
        fi
        
        save_monitor_state "$current_state"
    fi
}

########################################################################
#                         RECOVERY FUNCTIONS                           #
########################################################################

# Restart foot server via systemd
restart_foot_service() {
    log "INFO" "Restarting foot server service"
    
    if systemctl --user restart "$SERVICE_NAME"; then
        log "INFO" "Service restart command completed"
        
        # Reset failure counter on successful restart
        consecutive_failures=0
        
        # Wait a moment for service to be ready
        sleep 2
        
        # Verify restart was successful
        if perform_health_check; then
            log "INFO" "Service restart verified successful"
        else
            log "WARN" "Service restarted but may not be fully ready yet"
        fi
    else
        log "ERROR" "Failed to restart foot server service"
    fi
}

########################################################################
#                         MONITORING LOOP                              #
########################################################################

# Handle health check failure
handle_health_failure() {
    ((consecutive_failures++))
    log "WARN" "Health check failure #$consecutive_failures"
    
    if [[ $consecutive_failures -ge $MAX_CONSECUTIVE_FAILURES ]]; then
        log "ERROR" "Maximum consecutive failures ($MAX_CONSECUTIVE_FAILURES) reached"
        restart_foot_service
    else
        log "INFO" "Failure below threshold, continuing monitoring"
    fi
}

# Handle successful health check
handle_health_success() {
    if [[ $consecutive_failures -gt 0 ]]; then
        log "INFO" "Health restored after $consecutive_failures failures"
        consecutive_failures=0
    fi
}

# Main monitoring daemon loop
run_monitoring_daemon() {
    log "INFO" "Starting foot server monitoring daemon"
    
    # Initialize monitor state
    save_monitor_state "$(get_monitor_state)"
    
    # Main monitoring loop
    while true; do
        # First check for monitor changes (these can affect foot stability)
        check_monitor_changes
        
        # Then perform regular health check
        if perform_health_check; then
            handle_health_success
        else
            handle_health_failure
        fi
        
        # Wait before next check
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

########################################################################
#                           CLI INTERFACE                              #
########################################################################

# Simple command-line interface for manual operations
case "${1:-daemon}" in
    "--daemon"|"daemon")
        run_monitoring_daemon
        ;;
    "--check"|"check")
        if perform_health_check; then
            echo "✓ Foot server is healthy"
            log "INFO" "Manual health check: PASSED"
            exit 0
        else
            echo "✗ Foot server is not healthy"
            log "WARN" "Manual health check: FAILED"
            exit 1
        fi
        ;;
    "--restart"|"restart")
        log "INFO" "Manual restart requested"
        restart_foot_service
        ;;
    "--status"|"status")
        echo "=== Foot Monitor Status ==="
        echo "Service running: $(is_service_running && echo "YES" || echo "NO")"
        echo "Server responsive: $(is_foot_responsive && echo "YES" || echo "NO")"
        echo "Current monitors: $(get_monitor_state)"
        echo "Previous monitors: $(get_previous_monitor_state)"
        echo "Consecutive failures: $consecutive_failures"
        ;;
    "--help"|"help"|"-h")
        cat << 'EOF'
Foot Server Runtime Monitor

USAGE:
    foot_uwsm_monitor.sh [COMMAND]

COMMANDS:
    daemon      Run monitoring daemon (default, for autostart)
    --check     Perform single health check
    --restart   Restart foot server service
    --status    Show current monitoring status
    --help      Show this help

This script runs continuously in the background to monitor foot server
health and handle monitor change scenarios that could cause lockups.
EOF
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Use --help for usage information" >&2
        exit 1
        ;;
esac
