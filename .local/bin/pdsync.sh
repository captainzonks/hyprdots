#!/usr/bin/env bash

#==========================================================#
#                 PROTON DRIVE SYNC v2.2.1                 #
#==========================================================#
# File: ~/.local/bin/pdsync.sh
# Purpose: Simple, fast Proton Drive w/ up, down or bidirectional sync
# Author: Matthew Barham
# Created: 2025-07-20
# Updated: 2025-07-21
# Dependencies: rclone v1.64.0+ with protondrive backend
# Changes in v2.2.1:
#   - Removal of subdirectories for connection test; tests root folder 
# Changes in v2.2:
#   - Reverted to v2.0 simplicity
#   - Fixed only the critical issues: removed invalid --retry-delay flag
#   - Added --protondrive-replace-existing-draft=true for draft handling
#   - Kept original simple connection test
#   - Removed complex enhancements that were breaking connectivity
#==========================================================#

set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="pdsync"
readonly SCRIPT_VERSION="2.2.0"

# Color definitions
readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Configuration paths
readonly CONFIG_DIR="$HOME/.config/rclone"
readonly LOG_DIR="$HOME/.local/share/rclone"
readonly LAST_SYNC_FILE="$LOG_DIR/last_sync_time"
# readonly FILTER_INCLUDE="$CONFIG_DIR/include_patterns.txt"
# readonly FILTER_EXCLUDE="$CONFIG_DIR/exclude_patterns.txt"

# Default paths (can be overridden by environment variables)
readonly LOCAL_BASE="${PROTON_LOCAL_BASE:-$HOME/ProtonDrive}"
readonly REMOTE_BASE="${PROTON_REMOTE_BASE:-protondrive:}"

# Global variables
AUTH_CODE=""
CANCELLED=false

# Signal handlers for graceful cancellation
handle_interrupt() {
    CANCELLED=true
    echo
    echo -e "${YELLOW}🛑 Sync cancelled by user (Ctrl+C)${NC}"
    echo -e "${BLUE}ℹ  Partial sync may have occurred - run again to complete${NC}"
    exit 130  # Standard exit code for SIGINT
}

handle_termination() {
    CANCELLED=true
    echo
    echo -e "${YELLOW}🛑 Sync terminated by system${NC}"
    echo -e "${BLUE}ℹ  Partial sync may have occurred - run again to complete${NC}"
    exit 143  # Standard exit code for SIGTERM
}

# Set up signal traps
trap handle_interrupt SIGINT
trap handle_termination SIGTERM

# Function to display help
show_help() {
    echo -e "${BLUE}Proton Drive Sync Tool v${SCRIPT_VERSION}${NC}"
    echo
    echo -e "${YELLOW}USAGE:${NC}"
    echo "    $SCRIPT_NAME [OPTIONS] [LOCAL_PATH] [REMOTE_PATH]"
    echo
    echo -e "${YELLOW}OPTIONS:${NC}"
    echo "    -h, --help       Show this help message"
    echo "    -d, --dry-run    Only show what would be synced"
    echo "    -u, --upload     One-way upload (local → remote)"
    echo "    -D, --download   One-way download (remote → local)"  
    echo "    --resync         Force resync for bidirectional mode"
    echo "    --cleanup        Clear draft conflicts before sync"
    echo "    -v, --verbose    Enable verbose output"
    echo
    echo -e "${YELLOW}EXAMPLES:${NC}"
    echo "    $SCRIPT_NAME                                # Sync entire ~/ProtonDrive ↔ protondrive:"
    echo "    $SCRIPT_NAME foo/bar                        # Sync specific subdirectory"
    echo "    $SCRIPT_NAME foo protondrive:backup/        # Custom remote path"
    echo "    $SCRIPT_NAME --dry-run foo                  # Test what would sync"
    echo "    $SCRIPT_NAME --upload foo                   # One-way: local → remote"
    echo "    $SCRIPT_NAME --download foo                 # One-way: remote → local"
    echo "    $SCRIPT_NAME --cleanup --upload foo         # Clean drafts then upload"
    echo
    echo -e "${YELLOW}SYNC MODES:${NC}"
    echo "    Default: Bidirectional sync (local ↔ remote) using rclone bisync"
    echo "    --upload: One-way sync (local → remote) using rclone sync"
    echo "    --download: One-way sync (remote → local) using rclone sync"
    echo
    echo -e "${YELLOW}v2.2 CHANGES:${NC}"
    echo "    • Fixed invalid rclone flags that were breaking connectivity"
    echo "    • Added essential draft conflict resolution"
    echo "    • Simplified connection testing"
    echo "    • Removed complex enhancements that caused issues"
    echo
    echo -e "${RED}⚠️  DANGER: --resync CAN OVERWRITE FILES!${NC}"
    echo -e "${RED}    Bidirectional sync with --resync may download remote files over local changes.${NC}"
    echo -e "${RED}    Use -u (upload) or -D (download) for predictable one-way sync.${NC}"
    echo
    echo -e "${YELLOW}PATH EXAMPLES:${NC}"
    echo "    foo/bar → ~/ProtonDrive/foo/bar ↔ protondrive:foo/bar"
    echo "    documents → ~/ProtonDrive/documents ↔ protondrive:documents"
    echo "    . → ~/ProtonDrive ↔ protondrive: (entire directory)"
}

# Function to log messages
log_message() {
    local level="$1"
    local color="$2"
    shift 2
    echo -e "[$(date '+%H:%M:%S')] ${color}${level}:${NC} $*" >&2
}

# Function to get 2FA code if needed
get_2fa_code() {
    local use_2fa
    AUTH_CODE=""
    
    echo -ne "${YELLOW}2FA code needed? (y/N): ${NC}"
    read -n 1 use_2fa
    echo
    
    if [[ "$use_2fa" =~ ^[Yy]$ ]]; then
        echo -ne "${YELLOW}Enter 6-digit code: ${NC}"
        read -s AUTH_CODE
        echo
        
        if [[ ! "$AUTH_CODE" =~ ^[0-9]{6}$ ]]; then
            echo -e "${RED}❌ Invalid 2FA code format${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ 2FA code accepted${NC}"
    fi
}

# Function to build rclone command options (simplified, working version)
build_rclone_opts() {
    local opts=(
        --tpslimit 4
        --checkers 4
        --transfers 2
        --retries 3
        --progress
        --protondrive-replace-existing-draft=true  # Essential fix for draft conflicts
        --checksum                                 # Use checksum instead of modtime for Proton Drive
        REDACTED_DEBUG_FLAGS
    )
    
    if [[ -n "$AUTH_CODE" ]]; then
        opts+=(--protondrive-2fa="$AUTH_CODE")
    fi
    
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        opts+=(--verbose)
    fi
    
    # NOTE: not used currently
    # Add filters if they exist (use only one method to avoid conflicts)
    # if [[ -f "$FILTER_INCLUDE" ]]; then
    #     opts+=(--include-from="$FILTER_INCLUDE")
    #     # If using include patterns, exclude everything else by default
    #     if [[ -f "$FILTER_EXCLUDE" ]]; then
    #         log_message "WARN" "$YELLOW" "Both include and exclude patterns found - using include patterns only"
    #     fi
    # elif [[ -f "$FILTER_EXCLUDE" ]]; then
    #     opts+=(--exclude-from="$FILTER_EXCLUDE")
    # fi
    
    echo "${opts[@]}"
}

# Function to perform sync operation
perform_sync() {
    local sync_mode="$1"
    local local_path="$2"
    local remote_path="$3"
    local dry_run="$4"
    local resync="$5"
    local cleanup="$6"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    local log_file="$LOG_DIR/sync_$(date +%Y%m%d_%H%M%S).log"
    
    # Build rclone options
    local rclone_opts
    read -ra rclone_opts <<< "$(build_rclone_opts)"
    rclone_opts+=(--log-file "$log_file")
    
    if [[ "$dry_run" == "true" ]]; then
        rclone_opts+=(--dry-run)
        echo -e "${YELLOW}📋 Dry-run mode - no files will be modified${NC}"
    fi
    
    # Show what we're syncing
    echo -e "${BLUE}📁 Local:  ${local_path}${NC}"
    echo -e "${BLUE}☁️  Remote: ${remote_path}${NC}"
    echo -e "${BLUE}🔄 Mode:   ${sync_mode}${NC}"
    echo -e "${BLUE}📄 Log:    ${log_file}${NC}"
    echo
    
    # Simple cleanup if requested
    if [[ "$cleanup" == "true" && "$dry_run" != "true" ]]; then
        echo -e "${YELLOW}🧹 Cleanup enabled - draft conflicts will be automatically resolved${NC}"
        echo
    fi
    
    # Perform sync based on mode
    case "$sync_mode" in
        "bidirectional")
            if [[ "$resync" == "true" ]]; then
                echo -e "${YELLOW}🔄 Performing initial resync...${NC}"
                rclone_opts+=(--resync)
            fi
            
            echo -e "${BLUE}🔄 Starting bidirectional sync...${NC}"
            if rclone bisync "$local_path" "$remote_path" "${rclone_opts[@]}"; then
                echo -e "${GREEN}✅ Bidirectional sync completed successfully${NC}"
            else
                local exit_code=$?
                if [[ "$CANCELLED" == "true" ]]; then
                    exit $exit_code
                else
                    echo -e "${RED}❌ Bidirectional sync failed${NC}"
                    if [[ $exit_code -eq 2 ]]; then
                        echo -e "${YELLOW}💡 Try with --resync if this is the first sync${NC}"
                    fi
                    echo -e "${BLUE}💡 Try with --cleanup to clear draft conflicts${NC}"
                    echo -e "${BLUE}💡 Consider using --upload or --download instead of bidirectional sync${NC}"
                    exit $exit_code
                fi
            fi
            ;;
        "upload")
            echo -e "${BLUE}⬆️  Starting upload (local → remote)...${NC}"
            if rclone sync "$local_path" "$remote_path" "${rclone_opts[@]}"; then
                echo -e "${GREEN}✅ Upload completed successfully${NC}"
            else
                local exit_code=$?
                if [[ "$CANCELLED" != "true" ]]; then
                    echo -e "${RED}❌ Upload failed${NC}"
                    echo -e "${BLUE}💡 Try with --cleanup to clear draft conflicts${NC}"
                    echo -e "${BLUE}💡 Check log file: $log_file${NC}"
                fi
                exit $exit_code
            fi
            ;;
        "download")
            echo -e "${BLUE}⬇️  Starting download (remote → local)...${NC}"
            if rclone sync "$remote_path" "$local_path" "${rclone_opts[@]}"; then
                echo -e "${GREEN}✅ Download completed successfully${NC}"
            else
                local exit_code=$?
                if [[ "$CANCELLED" != "true" ]]; then
                    echo -e "${RED}❌ Download failed${NC}"
                    echo -e "${BLUE}💡 Check log file: $log_file${NC}"
                fi
                exit $exit_code
            fi
            ;;
    esac
    
    # Record sync time
    if [[ "$dry_run" != "true" ]]; then
        date +%s > "$LAST_SYNC_FILE"
    fi
    
    echo -e "${BLUE}📄 Detailed log: $log_file${NC}"
}

# Main function
main() {
    local sync_mode="bidirectional"
    local dry_run="false"
    local resync="false"
    local cleanup="false"
    local local_subpath=""
    local remote_subpath=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dry-run)
                dry_run="true"
                shift
                ;;
            -u|--upload)
                sync_mode="upload"
                shift
                ;;
            -D|--download)
                sync_mode="download"
                shift
                ;;
            --resync)
                resync="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --cleanup)
                cleanup="true"
                shift
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                if [[ -z "$local_subpath" ]]; then
                    local_subpath="$1"
                elif [[ -z "$remote_subpath" ]]; then
                    remote_subpath="$1"
                else
                    echo -e "${RED}Too many arguments${NC}"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Build full paths
    local local_path="$LOCAL_BASE"
    local remote_path="$REMOTE_BASE"
    
    if [[ -n "$local_subpath" && "$local_subpath" != "." ]]; then
        local_path="$LOCAL_BASE/$local_subpath"
        if [[ -z "$remote_subpath" ]]; then
            remote_path="$REMOTE_BASE$local_subpath"
        fi
    fi
    
    if [[ -n "$remote_subpath" ]]; then
        remote_path="$remote_subpath"
    fi
    
    # Ensure paths end correctly
    if [[ "$local_path" != */ ]]; then
        local_path="$local_path/"
    fi
    if [[ "$remote_path" != *: && "$remote_path" != */ ]]; then
        remote_path="$remote_path/"
    fi
    
    # Header
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}    PROTON DRIVE SYNC v${SCRIPT_VERSION} (Minimal)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    
    # Get 2FA if needed (FIRST, before any connection attempts)
    get_2fa_code
    
    # Simple connectivity test (test root connection, not subdirectory)
    echo -e "${BLUE}🔗 Testing connection...${NC}"
    local test_remote
    test_remote=$(echo "$remote_path" | cut -d: -f1):  # Extract just "protondrive:"
    
    local test_cmd="rclone lsd $test_remote --max-depth 1"
    if [[ -n "$AUTH_CODE" ]]; then
        test_cmd="$test_cmd --protondrive-2fa=$AUTH_CODE"
    fi
    
    if eval "$test_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Connection successful${NC}"
    else
        echo -e "${RED}❌ Cannot connect to Proton Drive${NC}"
        echo -e "${BLUE}💡 Check your credentials and try reconfiguring: rclone config${NC}"
        exit 1
    fi
    
    # Perform sync
    perform_sync "$sync_mode" "$local_path" "$remote_path" "$dry_run" "$resync" "$cleanup"
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
