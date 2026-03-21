#==========================================================#
#                    ZSH MAIN CONFIG                       #
#==========================================================#
# File: ~/.config/zsh/.zshrc
# Purpose: Main ZSH configuration with modular loading
# Dependencies: zsh, optional UWSM environment
# Last Updated: 2025-10-30
# Documentation: https://zsh.sourceforge.io/Doc/Release/
#
# Security Notes:
# - Only sources .zsh files to prevent code injection
# - Validates directories before sourcing
# - Error handling for failed sources
# - Graceful XDG variable fallbacks for login shells
#==========================================================#

#============= XDG ENVIRONMENT SETUP ======================#
# Ensure XDG variables are available for configuration loading
# Reference: https://specifications.freedesktop.org/basedir-spec/latest/

# Set XDG defaults if not already set (fallback for login shells)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Ensure required directories exist
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

#============= CORE APPLICATION XDG COMPLIANCE ============#
# Essential applications that must be configured for XDG compliance
# These are set here to ensure availability during config loading

# Container and development tools
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export GOPATH="$XDG_DATA_HOME/go"

# Security and authentication
export GNUPGHOME="$XDG_DATA_HOME/gnupg"

# Node.js package management
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"

#============= CONFIGURATION LOADING =====================#
# Load configurations in dependency order
# Core configurations must load before features

source_zsh_configs() {
    local config_type="$1"
    local config_dir="$XDG_CONFIG_HOME/zsh/${config_type}"

    # Validate directory exists and is readable
    [[ -d "$config_dir" && -r "$config_dir" ]] || {
        # Only warn if it's an expected directory
        if [[ "$config_type" == "core" || "$config_type" == "features" ]]; then
            echo "Warning: ZSH $config_type directory not found: $config_dir" >&2
        fi
        return 1
    }

    # Source files in numerical order (ensures dependency resolution)
    local config_files=()
    while IFS= read -r -d '' file; do
        [[ "$file" =~ \.(zsh|sh)$ ]] && config_files+=("$file")
    done < <(find "$config_dir" -maxdepth 1 -type f -readable \( -name "*.zsh" -o -name "*.sh" \) -print0 2>/dev/null | sort -z)

    # Source each configuration file with error handling
    for file in "${config_files[@]}"; do
        # Optional debug output (uncomment for troubleshooting)
        # echo "Loading: $(basename "$file")" >&2

        if ! source "$file"; then
            echo "Error: Failed to source $file" >&2
            # Don't exit - continue loading other configs
        fi
    done
}

# Load core configurations first (essential functionality)
source_zsh_configs "core"

# Load feature configurations (optional enhancements)
source_zsh_configs "features"

# nvm initialization
source /usr/share/nvm/init-nvm.sh

#============= STARSHIP INITIALIZATION ====================#
# Initialize starship prompt (should be last to ensure all configs loaded)
if command -v starship >/dev/null 2>&1; then
    # Use pre-generated init file if available for faster startup
    if [[ -f "$XDG_CONFIG_HOME/zsh/init/starship.zsh" ]]; then
        source "$XDG_CONFIG_HOME/zsh/init/starship.zsh"
    else
        # Fallback: direct initialization
        eval "$(starship init zsh)"
    fi
else
    echo "Warning: starship not available - using basic prompt" >&2
    PS1='%n@%m:%~$ '
fi

#============= CLEANUP ====================================#
# Clean up functions that shouldn't persist in the shell
unfunction source_zsh_configs 2>/dev/null || true

#============= POST-LOAD VALIDATION ======================#
# Optional: validate that essential tools are available
# Uncomment for debugging or initial setup validation
# [[ -z "$EDITOR" ]] && echo "Warning: EDITOR not set" >&2
# [[ ! -d "$GNUPGHOME" ]] && echo "Warning: GnuPG directory not found" >&2
