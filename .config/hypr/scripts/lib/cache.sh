#!/usr/bin/env bash
# Hyprland Cache Management Library

export HYPR_CACHE_DIR="${HYPR_CACHE_DIR:-$HOME/.cache/hyprland}"
export HYPR_CACHE_WALLPAPERS="$HYPR_CACHE_DIR/wallpapers"
export HYPR_CACHE_STATE="$HYPR_CACHE_DIR/state"
export HYPR_CACHE_EFFECTS="$HYPR_CACHE_DIR/effects"
export HYPR_CACHE_THUMBNAILS="$HYPR_CACHE_DIR/thumbnails"

init_cache() {
    mkdir -p "$HYPR_CACHE_DIR"
    mkdir -p "$HYPR_CACHE_WALLPAPERS"
    mkdir -p "$HYPR_CACHE_STATE"
    mkdir -p "$HYPR_CACHE_EFFECTS"
    mkdir -p "$HYPR_CACHE_THUMBNAILS"
}

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

write_state() {
    local state_name="$1"
    local value="$2"
    echo "$value" > "$HYPR_CACHE_STATE/$state_name"
}

delete_state() {
    rm -f "$HYPR_CACHE_STATE/$1"
}

has_state() {
    [[ -f "$HYPR_CACHE_STATE/$1" ]]
}

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

is_gamemode_enabled() { has_state "gamemode"; }
enable_gamemode() { write_state "gamemode" "1"; }
disable_gamemode() { delete_state "gamemode"; }

are_animations_disabled() { has_state "animations_disabled"; }
set_animations_disabled() { write_state "animations_disabled" "1"; }
set_animations_enabled() { delete_state "animations_disabled"; }

init_cache
