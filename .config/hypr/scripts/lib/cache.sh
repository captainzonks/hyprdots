#!/usr/bin/env bash
# =============================================================================
# Hyprland Cache Management Library
# =============================================================================
# Centralized cache management for Hyprland configuration
# Provides consistent cache directory structure and helper functions
#
# Dependencies: None (pure bash)
# =============================================================================

# Cache directory structure
export HYPR_CACHE_DIR="${HYPR_CACHE_DIR:-$HOME/.cache/hyprland}"
export HYPR_CACHE_WALLPAPERS="$HYPR_CACHE_DIR/wallpapers"
export HYPR_CACHE_STATE="$HYPR_CACHE_DIR/state"
export HYPR_CACHE_EFFECTS="$HYPR_CACHE_DIR/effects"
export HYPR_CACHE_THUMBNAILS="$HYPR_CACHE_DIR/thumbnails"

# Initialize cache directory structure
init_cache() {
    mkdir -p "$HYPR_CACHE_DIR"
    mkdir -p "$HYPR_CACHE_WALLPAPERS"
    mkdir -p "$HYPR_CACHE_STATE"
    mkdir -p "$HYPR_CACHE_EFFECTS"
    mkdir -p "$HYPR_CACHE_THUMBNAILS"
}

# Read state file (returns content or default value)
# Usage: read_state "state_name" "default_value"
read_state() {
    local state_name="$1"
    local default_value="${2:-}"
    local state_file="$HYPR_CACHE_STATE/$state_name"

    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "$default_value"
    fi
}

# Write state file
# Usage: write_state "state_name" "value"
write_state() {
    local state_name="$1"
    local value="$2"
    local state_file="$HYPR_CACHE_STATE/$state_name"

    echo "$value" > "$state_file"
}

# Delete state file
# Usage: delete_state "state_name"
delete_state() {
    local state_name="$1"
    local state_file="$HYPR_CACHE_STATE/$state_name"

    rm -f "$state_file"
}

# Check if state exists
# Usage: has_state "state_name"
has_state() {
    local state_name="$1"
    local state_file="$HYPR_CACHE_STATE/$state_name"

    [[ -f "$state_file" ]]
}

# Toggle state (returns new state: 0 or 1)
# Usage: toggle_state "state_name"
toggle_state() {
    local state_name="$1"

    if has_state "$state_name"; then
        delete_state "$state_name"
        echo "0"
    else
        write_state "$state_name" "1"
        echo "1"
    fi
}

# Get current wallpaper from cache
get_current_wallpaper() {
    read_state "current_wallpaper" ""
}

# Set current wallpaper in cache
set_current_wallpaper() {
    local wallpaper="$1"
    write_state "current_wallpaper" "$wallpaper"
}

# Check if wallpaper automation is enabled
is_wallpaper_automation_enabled() {
    has_state "wallpaper_automation"
}

# Enable wallpaper automation
enable_wallpaper_automation() {
    write_state "wallpaper_automation" "1"
}

# Disable wallpaper automation
disable_wallpaper_automation() {
    delete_state "wallpaper_automation"
}

# Check if gamemode is enabled
is_gamemode_enabled() {
    has_state "gamemode"
}

# Enable gamemode
enable_gamemode() {
    write_state "gamemode" "1"
}

# Disable gamemode
disable_gamemode() {
    delete_state "gamemode"
}

# Check if animations are disabled
are_animations_disabled() {
    has_state "animations_disabled"
}

# Disable animations (set state)
set_animations_disabled() {
    write_state "animations_disabled" "1"
}

# Enable animations (clear state)
set_animations_enabled() {
    delete_state "animations_disabled"
}

# Clean old cache files (older than N days)
# Usage: clean_cache_older_than 7
clean_cache_older_than() {
    local days="${1:-7}"

    # Clean old wallpaper effects (keep current)
    find "$HYPR_CACHE_EFFECTS" -type f -mtime "+$days" -delete 2>/dev/null || true

    # Clean old thumbnails
    find "$HYPR_CACHE_THUMBNAILS" -type f -mtime "+$days" -delete 2>/dev/null || true

    # Don't clean state files or current wallpapers
}

# Get cache size in human-readable format
get_cache_size() {
    du -sh "$HYPR_CACHE_DIR" 2>/dev/null | cut -f1
}

# List all state files
list_states() {
    if [[ -d "$HYPR_CACHE_STATE" ]]; then
        find "$HYPR_CACHE_STATE" -type f -exec basename {} \;
    fi
}

# Print cache status
print_cache_status() {
    echo "=== Hyprland Cache Status ==="
    echo "Cache directory: $HYPR_CACHE_DIR"
    echo "Total size: $(get_cache_size)"
    echo ""
    echo "Current states:"

    if [[ -d "$HYPR_CACHE_STATE" ]] && [[ -n "$(ls -A "$HYPR_CACHE_STATE" 2>/dev/null)" ]]; then
        for state_file in "$HYPR_CACHE_STATE"/*; do
            if [[ -f "$state_file" ]]; then
                state_name=$(basename "$state_file")
                state_value=$(cat "$state_file")
                echo "  $state_name: $state_value"
            fi
        done
    else
        echo "  (none)"
    fi

    echo ""
    echo "Cached wallpapers: $(find "$HYPR_CACHE_WALLPAPERS" -type f 2>/dev/null | wc -l)"
    echo "Cached effects: $(find "$HYPR_CACHE_EFFECTS" -type f 2>/dev/null | wc -l)"
    echo "Cached thumbnails: $(find "$HYPR_CACHE_THUMBNAILS" -type f 2>/dev/null | wc -l)"
}

# Initialize cache on library load
init_cache
