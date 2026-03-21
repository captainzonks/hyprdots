#!/usr/bin/env bash
# =============================================================================
# Random Wallpaper Setter
# =============================================================================
# Sets a random wallpaper and regenerates Material You color theme
# Run via systemd timer for automated rotation
#
# Dependencies: hyprctl, swaybg (via systemd), matugen, sed, timeout
# =============================================================================

set -euo pipefail

# Source cache library
source "$HOME/.config/hypr/scripts/lib/cache.sh" || exit 1

# Logging
LOGFILE="$HYPR_CACHE_DIR/wallpaper-switch.log"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOGFILE"
}

# Instance prevention - only allow one instance at a time
SCRIPT_NAME=$(basename "$0")
LOCK_FILE="$HYPR_CACHE_STATE/${SCRIPT_NAME}.lock"

if [ -f "$LOCK_FILE" ]; then
    LOCK_PID=$(cat "$LOCK_FILE")
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        log "Another instance is running (PID: $LOCK_PID), exiting"
        exit 0
    else
        log "Removing stale lock file for PID: $LOCK_PID"
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file
echo $$ > "$LOCK_FILE"

# Cleanup function
cleanup() {
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

log "Script started (PID: $$)"

# Setup environment - get Hyprland socket info for hyprctl commands
HYPR_PID=$(pgrep -x Hyprland | head -n 1)
if [ -n "$HYPR_PID" ]; then
    eval $(grep -z WAYLAND_DISPLAY /proc/$HYPR_PID/environ | tr '\0' '\n' | sed 's/^/export /')
    eval $(grep -z HYPRLAND_INSTANCE_SIGNATURE /proc/$HYPR_PID/environ | tr '\0' '\n' | sed 's/^/export /')
    log "Using HYPRLAND_INSTANCE_SIGNATURE from Hyprland: $HYPRLAND_INSTANCE_SIGNATURE"
else
    log "ERROR - Hyprland is not running"
    exit 1
fi

log "Environment setup complete"

WALLPAPER_DIR="${HOME}/Pictures/wallpaper"

# Check if wallpaper automation is paused (e.g., by gamemode)
if has_state "wallpaper_automation_paused"; then
    log "Wallpaper automation is paused (gamemode active), skipping"
    exit 0
fi

# Get monitors (used for logging)
log "Getting monitors..."
MONITORS=$(timeout 5 hyprctl monitors 2>&1) || {
    log "ERROR - Failed to get monitors"
    exit 1
}

# Select random wallpaper (only image files)
wallpaper="$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)"

if [ -z "$wallpaper" ]; then
    log "ERROR - No image files found in $WALLPAPER_DIR"
    exit 1
fi

log "Selected wallpaper: $wallpaper"

# Set wallpaper via swaybg (restart the systemd service with the new image)
# swaybg has no IPC — wallpaper changes require restarting the process
log "Setting wallpaper via swaybg"
systemctl --user set-environment SWAYBG_IMAGE="$wallpaper"
timeout 10 systemctl --user restart swaybg.service || log "WARN - Failed to restart swaybg"
log "swaybg restarted with new wallpaper"

# Store current wallpaper in cache
set_current_wallpaper "$wallpaper"
log "Saved current wallpaper to cache"

# Generate Material You colors from new wallpaper
if [ -x "$HOME/.local/share/cargo/bin/matugen" ]; then
    log "Generating Material You colors..."
    timeout 10 $HOME/.local/share/cargo/bin/matugen image "$wallpaper" >/dev/null 2>&1 || {
        log "WARN - matugen timed out or failed"
    }

    # Update starship colors in main config
    if [ -f "$HOME/.cache/starship-colors-generated.txt" ]; then
        sed -i '/# MATUGEN_COLORS_START/,/# MATUGEN_COLORS_END/d' "$HOME/.config/starship/starship.toml"
        sed -i "/palette = 'material_you'/r $HOME/.cache/starship-colors-generated.txt" "$HOME/.config/starship/starship.toml"
        log "Updated starship colors"
    fi

    # Apply terminal colors (background process)
    ~/.config/hypr/scripts/runtime/apply_terminal_colors.sh >/dev/null 2>&1 &
    log "Applied Foot terminal colors"

    # Apply Kitty colors if Material You theme is enabled
    ~/.config/hypr/scripts/runtime/apply_kitty_colors.sh >/dev/null 2>&1 &
    log "Applied Kitty terminal colors"

    # Reload waybar to apply new colors (with timeout)
    timeout 5 systemctl --user restart waybar.service >/dev/null 2>&1 || log "WARN - waybar restart timed out"
    log "Reloaded waybar"

    # Reload swaync to apply new colors (with timeout)
    # This was the blocking call causing hangs
    timeout 3 swaync-client -rs >/dev/null 2>&1 || log "WARN - swaync reload timed out"
    log "Reloaded swaync"

    # Reload Hyprland to apply new colors
    sleep 0.5
    timeout 5 hyprctl reload >/dev/null 2>&1 || log "WARN - hyprctl reload timed out"
    log "Reloaded Hyprland"
fi

log "Wallpaper change complete"
