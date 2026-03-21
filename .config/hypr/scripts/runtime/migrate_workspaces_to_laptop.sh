#!/usr/bin/env bash
# =============================================================================
# Workspace Migration
# =============================================================================
# Intelligent workspace migration when switching from external to laptop display
# Detects orphaned workspaces from disconnected monitors and migrates them
# Preserves workspace numbering, window arrangements, and focus state
#
# Dependencies: hyprctl, jq
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly LAPTOP_MONITOR="eDP-1"
readonly EXTERNAL_MONITOR="DP-1"
readonly LOG_FILE="$HOME/.local/state/workspace-migration.log"

# Workspace preferences for migration priority
readonly PREFERRED_WORKSPACE=1  # Default workspace to focus after migration

# =============================================================================
# LOGGING
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# =============================================================================
# HYPRLAND QUERY FUNCTIONS
# =============================================================================

# Get all workspaces with their monitor assignments
get_workspace_info() {
    if ! command -v hyprctl >/dev/null 2>&1; then
        log "ERROR" "hyprctl not available"
        return 1
    fi
    
    # Query current workspace configuration
    hyprctl workspaces -j 2>/dev/null | jq -r '.[] | "\(.id):\(.monitor):\(.name)"' 2>/dev/null || {
        log "ERROR" "Failed to query workspaces"
        return 1
    }
}

# Get currently active workspace
get_active_workspace() {
    hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo "1"
}

# Check if a monitor exists and is active
monitor_exists() {
    local monitor="$1"
    hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep -q "^${monitor}$"
}

# =============================================================================
# WORKSPACE MIGRATION LOGIC
# =============================================================================

# Migrate a single workspace to the laptop monitor
migrate_workspace() {
    local workspace_id="$1"
    local current_monitor="$2"
    
    log "INFO" "Migrating workspace $workspace_id from $current_monitor to $LAPTOP_MONITOR"
    
    # Use Hyprland's moveworkspacetomonitor dispatcher
    if hyprctl dispatch moveworkspacetomonitor "$workspace_id" "$LAPTOP_MONITOR" >/dev/null 2>&1; then
        log "INFO" "Successfully migrated workspace $workspace_id"
        return 0
    else
        log "WARNING" "Failed to migrate workspace $workspace_id"
        return 1
    fi
}

# Handle special workspaces (scratchpads)
migrate_special_workspaces() {
    log "INFO" "Checking for special workspaces to migrate"
    
    # Get special workspaces
    local special_workspaces
    special_workspaces=$(hyprctl workspaces -j 2>/dev/null | \
        jq -r '.[] | select(.name | startswith("special")) | "\(.name):\(.monitor)"' 2>/dev/null || echo "")
    
    if [[ -n "$special_workspaces" ]]; then
        while IFS=':' read -r workspace_name monitor; do
            if [[ "$monitor" != "$LAPTOP_MONITOR" ]]; then
                log "INFO" "Migrating special workspace: $workspace_name"
                hyprctl dispatch moveworkspacetomonitor "$workspace_name" "$LAPTOP_MONITOR" >/dev/null 2>&1 || \
                    log "WARNING" "Failed to migrate special workspace $workspace_name"
            fi
        done <<< "$special_workspaces"
    else
        log "DEBUG" "No special workspaces found"
    fi
}

# Main migration function
perform_migration() {
    log "INFO" "Starting workspace migration to laptop monitor"
    
    # Verify laptop monitor is available
    if ! monitor_exists "$LAPTOP_MONITOR"; then
        log "ERROR" "Laptop monitor $LAPTOP_MONITOR not available"
        return 1
    fi
    
    # Get current workspace information
    local workspace_info
    workspace_info=$(get_workspace_info) || {
        log "ERROR" "Failed to get workspace information"
        return 1
    }
    
    local active_workspace
    active_workspace=$(get_active_workspace)
    log "INFO" "Current active workspace: $active_workspace"
    
    # Track workspaces that need migration
    local workspaces_to_migrate=()
    local workspace_found=false
    
    # Parse workspace information and identify migration candidates
    while IFS=':' read -r workspace_id monitor workspace_name; do
        workspace_found=true
        
        # Skip if already on laptop monitor
        if [[ "$monitor" == "$LAPTOP_MONITOR" ]]; then
            log "DEBUG" "Workspace $workspace_id already on laptop monitor"
            continue
        fi
        
        # Skip special workspaces (handle separately)
        if [[ "$workspace_name" == special* ]]; then
            continue
        fi
        
        # Add to migration list
        workspaces_to_migrate+=("$workspace_id:$monitor")
        log "DEBUG" "Workspace $workspace_id on $monitor marked for migration"
        
    done <<< "$workspace_info"
    
    if ! $workspace_found; then
        log "WARNING" "No workspace information found"
        return 1
    fi
    
    # Perform the actual migrations
    local migration_count=0
    for workspace_entry in "${workspaces_to_migrate[@]}"; do
        IFS=':' read -r workspace_id source_monitor <<< "$workspace_entry"
        
        if migrate_workspace "$workspace_id" "$source_monitor"; then
            ((migration_count++))
        fi
    done
    
    # Handle special workspaces
    migrate_special_workspaces
    
    log "INFO" "Migrated $migration_count regular workspaces"
    
    # Focus management after migration
    restore_focus_after_migration "$active_workspace"
    
    return 0
}

# =============================================================================
# FOCUS RESTORATION
# =============================================================================

# Restore appropriate focus after workspace migration
restore_focus_after_migration() {
    local original_active_workspace="$1"
    
    log "INFO" "Restoring focus after migration (original: $original_active_workspace)"
    
    # Wait for migrations to complete
    sleep 1
    
    # Strategy 1: Try to focus the original active workspace
    if hyprctl dispatch workspace "$original_active_workspace" >/dev/null 2>&1; then
        log "INFO" "Restored focus to original workspace $original_active_workspace"
        return 0
    fi
    
    # Strategy 2: Focus the preferred default workspace
    if hyprctl dispatch workspace "$PREFERRED_WORKSPACE" >/dev/null 2>&1; then
        log "INFO" "Focused preferred workspace $PREFERRED_WORKSPACE"
        return 0
    fi
    
    # Strategy 3: Focus any available workspace on laptop monitor
    local available_workspace
    available_workspace=$(hyprctl workspaces -j 2>/dev/null | \
        jq -r ".[] | select(.monitor == \"$LAPTOP_MONITOR\") | .id" 2>/dev/null | head -1 || echo "")
    
    if [[ -n "$available_workspace" ]]; then
        hyprctl dispatch workspace "$available_workspace" >/dev/null 2>&1
        log "INFO" "Focused available workspace $available_workspace on laptop monitor"
        return 0
    fi
    
    log "WARNING" "Could not restore focus to any workspace"
    return 1
}

# =============================================================================
# VALIDATION AND RECOVERY
# =============================================================================

# Validate that migration was successful
validate_migration() {
    log "INFO" "Validating workspace migration"
    
    # Check that laptop monitor has at least one workspace
    local laptop_workspaces
    laptop_workspaces=$(hyprctl workspaces -j 2>/dev/null | \
        jq -r ".[] | select(.monitor == \"$LAPTOP_MONITOR\") | .id" 2>/dev/null | wc -l || echo "0")
    
    if [[ "$laptop_workspaces" -gt 0 ]]; then
        log "INFO" "Migration validation successful: $laptop_workspaces workspaces on laptop monitor"
        return 0
    else
        log "ERROR" "Migration validation failed: no workspaces on laptop monitor"
        return 1
    fi
}

# Emergency recovery: ensure at least one workspace exists on laptop monitor
emergency_workspace_recovery() {
    log "WARNING" "Performing emergency workspace recovery"
    
    # Create and focus workspace 1 on laptop monitor
    hyprctl dispatch focusmonitor "$LAPTOP_MONITOR" >/dev/null 2>&1
    hyprctl dispatch workspace 1 >/dev/null 2>&1
    
    log "INFO" "Emergency recovery: created workspace 1 on laptop monitor"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log "INFO" "Starting workspace migration to laptop display"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Perform the migration
    if perform_migration; then
        # Validate migration success
        if validate_migration; then
            log "INFO" "Workspace migration completed successfully"
            
            # Optional: Send notification
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -i laptop "Workspace Migration" \
                    "Workspaces migrated to laptop display" \
                    --expire-time=2000 2>/dev/null || true
            fi
        else
            log "ERROR" "Migration validation failed, attempting recovery"
            emergency_workspace_recovery
        fi
    else
        log "ERROR" "Workspace migration failed, attempting emergency recovery"
        emergency_workspace_recovery
    fi
    
    return 0
}

# Execute main function
main "$@"
