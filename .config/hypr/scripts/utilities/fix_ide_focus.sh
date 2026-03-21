#!/usr/bin/env bash
# IDE Focus Fix for JetBrains IDEs in Hyprland

set -euo pipefail

readonly LOG_FILE="$HOME/.local/state/hyprland-ide-focus.log"
readonly RUSTOVER_PROPERTIES_DIR="$HOME/.local/share/JetBrains"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

find_rustover_dir() {
    local rustover_dir
    rustover_dir=$(find "$RUSTOVER_PROPERTIES_DIR" -maxdepth 1 -type d -name "RustRover*" 2>/dev/null | head -1)
    if [[ -n "$rustover_dir" ]]; then
        echo "$rustover_dir"
        return 0
    else
        log "WARNING: RustRover installation directory not found"
        return 1
    fi
}

configure_rustover_properties() {
    local rustover_dir
    if ! rustover_dir=$(find_rustover_dir); then
        log "Skipping RustRover properties configuration"
        return 0
    fi

    local properties_file="$rustover_dir/idea.properties"
    log "Configuring RustRover properties: $properties_file"
    mkdir -p "$(dirname "$properties_file")"

    cat > "$properties_file" << 'EOF'
# Hyprland Focus Fix Configuration for RustRover
suppress.focus.stealing=true
suppress.focus.stealing.auto.request.focus=true
suppress.focus.stealing.active.window.checks=true
suppress.focus.stealing.disable.auto.request.focus=true
popup.animation.enabled=false
ide.popup.resizable=true
awt.nativeDoubleBuffering=true
sun.java2d.xrender=false
sun.java2d.noddraw=true
ide.windowSystem.autoRequestFocus=false
ide.powersave.mode=false
sun.java2d.opengl=false
java2d.metal=false
EOF

    log "RustRover properties configured successfully"
}

apply_window_rules() {
    log "Reloading Hyprland configuration"
    if hyprctl reload >/dev/null 2>&1; then
        log "Hyprland configuration reloaded successfully"
    else
        log "ERROR: Failed to reload Hyprland configuration"
        return 1
    fi
}

show_status() {
    log "=== IDE Focus Fix Status ==="
    if hyprctl getoption windowrule | grep -q "jetbrains\|RustRover"; then
        echo "JetBrains window rules are active"
    else
        echo "JetBrains window rules not found"
    fi

    local rustover_dir
    if rustover_dir=$(find_rustover_dir) && [[ -f "$rustover_dir/idea.properties" ]]; then
        echo "RustRover properties configured"
    else
        echo "RustRover properties not configured"
    fi

    local running_ides
    running_ides=$(pgrep -f "jetbrains-|RustRover" | wc -l)
    if [[ "$running_ides" -gt 0 ]]; then
        echo "Found $running_ides running JetBrains IDE process(es)"
    else
        echo "No JetBrains IDE processes currently running"
    fi
}

case "${1:-apply}" in
    "apply")
        configure_rustover_properties
        apply_window_rules
        ;;
    "status")
        show_status
        ;;
    "reload")
        apply_window_rules
        ;;
    *)
        echo "Usage: $0 [apply|status|reload]"
        exit 1
        ;;
esac
