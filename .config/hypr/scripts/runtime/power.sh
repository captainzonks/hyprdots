#!/usr/bin/env bash
# =============================================================================
# Power Management
# =============================================================================
# Handles graceful exit, lock, reboot, shutdown, suspend, and hibernate
# operations with proper client termination and service cleanup.
#
# Dependencies: hyprctl, jq, systemd, uwsm
# =============================================================================

set -euo pipefail

TIMEOUT=5
LOG_FILE="$HOME/.local/state/hyprland-power.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

# Gracefully terminate all Hyprland clients
terminate_clients() {
    log "Starting graceful client termination..."

    # Get a list of all client PIDs in the current Hyprland session
    if ! command -v hyprctl >/dev/null || ! command -v jq >/dev/null; then
        log "Warning: hyprctl or jq not available, skipping client termination"
        return 0
    fi

    client_pids=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | .pid' 2>/dev/null || echo "")

    if [[ -z "$client_pids" ]]; then
        log "No clients to terminate"
        return 0
    fi

    # Send SIGTERM (kill -15) to each client PID
    for pid in $client_pids; do
        if kill -0 "$pid" 2>/dev/null; then
            log "Sending SIGTERM to PID $pid"
            kill -15 "$pid" 2>/dev/null || true
        fi
    done

    # Wait for processes to terminate with timeout
    start_time=$(date +%s)
    for pid in $client_pids; do
        while kill -0 "$pid" 2>/dev/null; do
            current_time=$(date +%s)
            elapsed_time=$((current_time - start_time))

            if [[ $elapsed_time -ge $TIMEOUT ]]; then
                log "Timeout reached ($TIMEOUT seconds), forcing remaining clients"
                # Force kill any remaining clients
                for remaining_pid in $client_pids; do
                    if kill -0 "$remaining_pid" 2>/dev/null; then
                        log "Force killing PID $remaining_pid"
                        kill -9 "$remaining_pid" 2>/dev/null || true
                    fi
                done
                return 0
            fi

            sleep 0.5
        done
        log "PID $pid terminated gracefully"
    done

    log "All clients terminated successfully"
}

# Stop background services/scripts that might hold the session
cleanup_background_services() {
    log "Cleaning up background services..."

    # Stop wallpaper automation if running
    pkill -f "wallpaper-automation" 2>/dev/null || true
    pkill -f "set_random_wallpaper" 2>/dev/null || true

    # Stop monitoring scripts
    pkill -f "foot_uwsm_monitor" 2>/dev/null || true

    # Give them a moment to clean up
    sleep 0.5
}

# Exit Hyprland session
exit_hyprland() {
    log "=== EXIT HYPRLAND ==="

    # Terminate clients gracefully
    terminate_clients

    # Clean up background services
    cleanup_background_services

    # Give everything a moment to settle
    sleep 0.5

    # Stop UWSM (which will stop Hyprland properly)
    log "Stopping UWSM session..."
    if command -v uwsm >/dev/null; then
        uwsm stop 2>&1 | tee -a "$LOG_FILE"
    else
        # Fallback to direct Hyprland exit if uwsm not available
        log "UWSM not available, using direct Hyprland exit"
        hyprctl dispatch exit 2>&1 | tee -a "$LOG_FILE"
    fi

    # If we're still here after 2 seconds, something went wrong
    sleep 2
    log "Warning: Exit may have failed, forcing..."
    exit 0
}

# Lock screen
lock_screen() {
    log "=== LOCK SCREEN ==="
    sleep 0.3
    if command -v hyprlock >/dev/null; then
        hyprlock
    else
        log "Warning: hyprlock not found"
        notify-send "Lock failed" "hyprlock not installed"
    fi
}

# Reboot system
reboot_system() {
    log "=== REBOOT SYSTEM ==="

    terminate_clients
    cleanup_background_services
    sleep 0.5

    log "Initiating system reboot..."
    systemctl reboot
}

# Shutdown system
shutdown_system() {
    log "=== SHUTDOWN SYSTEM ==="

    terminate_clients
    cleanup_background_services
    sleep 0.5

    log "Initiating system shutdown..."
    systemctl poweroff
}

# Suspend system
suspend_system() {
    log "=== SUSPEND SYSTEM ==="
    sleep 0.3
    systemctl suspend
}

# Hibernate system
hibernate_system() {
    log "=== HIBERNATE SYSTEM ==="
    sleep 0.5
    systemctl hibernate
}

# Main entry point
case "${1:-}" in
    exit|logout)
        exit_hyprland
        ;;
    lock)
        lock_screen
        ;;
    reboot)
        reboot_system
        ;;
    shutdown|poweroff)
        shutdown_system
        ;;
    suspend|sleep)
        suspend_system
        ;;
    hibernate)
        hibernate_system
        ;;
    *)
        echo "Usage: $0 {exit|logout|lock|reboot|shutdown|suspend|hibernate}"
        echo "  exit/logout  - Exit Hyprland session"
        echo "  lock         - Lock screen with hyprlock"
        echo "  reboot       - Reboot system"
        echo "  shutdown     - Power off system"
        echo "  suspend      - Suspend to RAM"
        echo "  hibernate    - Hibernate to disk"
        exit 1
        ;;
esac
