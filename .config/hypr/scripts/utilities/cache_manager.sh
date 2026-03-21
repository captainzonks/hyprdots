#!/usr/bin/env bash
# =============================================================================
# Hyprland Cache Manager
# =============================================================================
# Manages Hyprland cache directory - view status, clean old files, reset state
# Provides utilities for cache maintenance and troubleshooting
#
# Dependencies: du, find
# =============================================================================

set -euo pipefail

# Source cache library
source "$HOME/.config/hypr/scripts/lib/cache.sh" || exit 1

# Print usage
usage() {
    cat << EOF
Hyprland Cache Manager

USAGE:
    $(basename "$0") <command> [options]

COMMANDS:
    status              Show cache status and current states
    clean [days]        Clean cache files older than N days (default: 7)
    clean-all           Remove all cached effects and thumbnails (keep state)
    reset               Reset all state files (animations, gamemode, etc.)
    reset-state <name>  Reset specific state file
    list-states         List all state files
    path                Print cache directory path
    help                Show this help message

EXAMPLES:
    $(basename "$0") status
    $(basename "$0") clean 14
    $(basename "$0") clean-all
    $(basename "$0") reset
    $(basename "$0") reset-state gamemode

CACHE STRUCTURE:
    $HYPR_CACHE_DIR/
    ├── wallpapers/      Cached wallpaper files
    ├── effects/         Processed wallpaper effects
    ├── thumbnails/      Wallpaper thumbnails
    └── state/           State files (gamemode, animations, etc.)

EOF
}

# Show detailed status
show_status() {
    print_cache_status
}

# Clean old cache files
clean_cache() {
    local days="${1:-7}"

    echo "Cleaning cache files older than $days days..."
    clean_cache_older_than "$days"

    echo "Cache cleanup complete"
    echo ""
    show_status
}

# Clean all cache (keep state)
clean_all_cache() {
    echo "Removing all cached effects and thumbnails..."

    # Clean effects
    if [[ -d "$HYPR_CACHE_EFFECTS" ]]; then
        rm -rf "${HYPR_CACHE_EFFECTS:?}"/*
        echo "✓ Cleared effects cache"
    fi

    # Clean thumbnails
    if [[ -d "$HYPR_CACHE_THUMBNAILS" ]]; then
        rm -rf "${HYPR_CACHE_THUMBNAILS:?}"/*
        echo "✓ Cleared thumbnails cache"
    fi

    # Keep wallpapers and state
    echo "✓ Preserved wallpapers and state files"

    echo ""
    show_status
}

# Reset all states
reset_all_states() {
    echo "Resetting all state files..."

    if [[ -d "$HYPR_CACHE_STATE" ]] && [[ -n "$(ls -A "$HYPR_CACHE_STATE" 2>/dev/null)" ]]; then
        local count=0
        for state_file in "$HYPR_CACHE_STATE"/*; do
            if [[ -f "$state_file" ]]; then
                state_name=$(basename "$state_file")
                echo "  Removing: $state_name"
                rm -f "$state_file"
                ((count++))
            fi
        done
        echo "✓ Removed $count state file(s)"
    else
        echo "No state files to reset"
    fi

    echo ""
    show_status
}

# Reset specific state
reset_specific_state() {
    local state_name="$1"

    if [[ -z "$state_name" ]]; then
        echo "Error: State name required"
        echo "Usage: $(basename "$0") reset-state <name>"
        exit 1
    fi

    if has_state "$state_name"; then
        delete_state "$state_name"
        echo "✓ Reset state: $state_name"
    else
        echo "State '$state_name' does not exist"
        exit 1
    fi
}

# List all states
list_all_states() {
    echo "=== Current State Files ==="

    if [[ -d "$HYPR_CACHE_STATE" ]] && [[ -n "$(ls -A "$HYPR_CACHE_STATE" 2>/dev/null)" ]]; then
        for state_file in "$HYPR_CACHE_STATE"/*; do
            if [[ -f "$state_file" ]]; then
                state_name=$(basename "$state_file")
                state_value=$(cat "$state_file")
                echo "$state_name: $state_value"
            fi
        done
    else
        echo "(no states)"
    fi
}

# Print cache path
print_cache_path() {
    echo "$HYPR_CACHE_DIR"
}

# Main command handler
main() {
    local command="${1:-status}"

    case "$command" in
        status)
            show_status
            ;;
        clean)
            clean_cache "${2:-7}"
            ;;
        clean-all)
            clean_all_cache
            ;;
        reset)
            reset_all_states
            ;;
        reset-state)
            reset_specific_state "${2:-}"
            ;;
        list-states|list)
            list_all_states
            ;;
        path)
            print_cache_path
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: $command"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
