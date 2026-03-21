#!/usr/bin/env bash
# =============================================================================
# Process Priority Optimization
# =============================================================================
# Runs periodically to optimize CPU and I/O priorities for Hyprland processes
# Ensures UI responsiveness by prioritizing compositor and interactive apps
#
# Dependencies: renice, ionice, pgrep
# =============================================================================

# Enable proper signal handling for clean shutdown
set -euo pipefail

# Handle termination signals gracefully
cleanup() {
    echo "Process optimization script received termination signal, exiting cleanly..."
    exit 0
}

trap cleanup SIGTERM SIGINT SIGHUP

# Function to set process priority based on application type
optimize_process_priority() {
    local process_name="$1"
    local priority="$2"
    local io_class="$3"
    local io_priority="$4"
    
    # Find all matching processes
    local pids=$(pgrep -f "$process_name" 2>/dev/null)
    if [[ -z "$pids" ]]; then
        echo "No processes found matching: $process_name"
        return 0
    fi
    
    for pid in $pids; do
        # Set CPU priority (nice value) with error handling
        if renice "$priority" "$pid" >/dev/null 2>&1; then
            echo "Set nice priority $priority for $process_name (PID: $pid)"
        else
            echo "Warning: Could not set nice priority for $process_name (PID: $pid) - insufficient privileges or process not found"
        fi
        
        # Set I/O scheduling priority with error handling
        if ionice -c "$io_class" -n "$io_priority" -p "$pid" >/dev/null 2>&1; then
            echo "Set I/O priority $io_class/$io_priority for $process_name (PID: $pid)"
        else
            echo "Warning: Could not set I/O priority for $process_name (PID: $pid) - insufficient privileges or process not found"
        fi
    done
}

# Critical user interface processes (highest priority within user limits)
optimize_process_priority "waybar" 0 1 4          # Best effort I/O, highest user CPU priority
optimize_process_priority "hyprland" 0 1 4        # Compositor gets highest priority

# Important user applications (medium-high priority)
optimize_process_priority "kitty" 2 2 3           # Terminal gets high priority
optimize_process_priority "helix" 2 2 3           # Editor gets high priority

# Background applications (normal priority)
optimize_process_priority "signal-desktop" 5 2 5   # Signal gets normal priority
optimize_process_priority "firefox" 5 2 5          # Browser gets normal priority

# Background services (low priority)
optimize_process_priority "udiskie" 10 3 7         # Mount daemon gets low priority
optimize_process_priority "clipse" 15 3 7          # Clipboard manager gets lowest priority

echo "Process optimization completed at $(date)"
