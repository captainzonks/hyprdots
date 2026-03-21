#!/usr/bin/env bash
# Power Management for Hyprland

set -euo pipefail

TIMEOUT=5
LOG_FILE="$HOME/.local/state/hyprland-power.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

terminate_clients() {
    log "Starting graceful client termination..."

    if ! command -v hyprctl >/dev/null || ! command -v jq >/dev/null; then
        log "Warning: hyprctl or jq not available, skipping client termination"
        return 0
    fi

    client_pids=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | .pid' 2>/dev/null || echo "")

    if [[ -z "$client_pids" ]]; then
        log "No clients to terminate"
        return 0
    fi

    for pid in $client_pids; do
        if kill -0 "$pid" 2>/dev/null; then
            log "Sending SIGTERM to PID $pid"
            kill -15 "$pid" 2>/dev/null || true
        fi
    done

    start_time=$(date +%s)
    for pid in $client_pids; do
        while kill -0 "$pid" 2>/dev/null; do
            current_time=$(date +%s)
            elapsed_time=$((current_time - start_time))

            if [[ $elapsed_time -ge $TIMEOUT ]]; then
                log "Timeout reached, forcing remaining clients"
                for remaining_pid in $client_pids; do
                    if kill -0 "$remaining_pid" 2>/dev/null; then
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

cleanup_background_services() {
    log "Cleaning up background services..."
    pkill -f "foot_uwsm_monitor" 2>/dev/null || true
    sleep 0.5
}

exit_hyprland() {
    log "=== EXIT HYPRLAND ==="
    terminate_clients
    cleanup_background_services
    sleep 0.5

    log "Stopping UWSM session..."
    if command -v uwsm >/dev/null; then
        uwsm stop 2>&1 | tee -a "$LOG_FILE"
    else
        log "UWSM not available, using direct Hyprland exit"
        hyprctl dispatch exit 2>&1 | tee -a "$LOG_FILE"
    fi

    sleep 2
    log "Warning: Exit may have failed, forcing..."
    exit 0
}

lock_screen() {
    log "=== LOCK SCREEN ==="
    sleep 0.3
    if command -v hyprlock >/dev/null; then
        hyprlock
    else
        notify-send "Lock failed" "hyprlock not installed"
    fi
}

reboot_system() {
    log "=== REBOOT SYSTEM ==="
    terminate_clients
    cleanup_background_services
    sleep 0.5
    systemctl reboot
}

shutdown_system() {
    log "=== SHUTDOWN SYSTEM ==="
    terminate_clients
    cleanup_background_services
    sleep 0.5
    systemctl poweroff
}

suspend_system() {
    log "=== SUSPEND SYSTEM ==="
    sleep 0.3
    systemctl suspend
}

hibernate_system() {
    log "=== HIBERNATE SYSTEM ==="
    sleep 0.5
    systemctl hibernate
}

case "${1:-}" in
    exit|logout) exit_hyprland ;;
    lock) lock_screen ;;
    reboot) reboot_system ;;
    shutdown|poweroff) shutdown_system ;;
    suspend|sleep) suspend_system ;;
    hibernate) hibernate_system ;;
    *)
        echo "Usage: $0 {exit|logout|lock|reboot|shutdown|suspend|hibernate}"
        exit 1
        ;;
esac
