#==========================================================#
#                 ZSH ENVIRONMENT CONFIG                   #
#==========================================================#
# File: core/00-environment.zsh
# Purpose: Shell-specific environment configuration
# Dependencies: XDG variables (set by main .zshrc)
# Last Updated: 2026-03-10
# Documentation: https://zsh.sourceforge.io/Doc/Release/
#
# NOTE: XDG variables are set by main .zshrc with proper fallbacks
# This file handles shell-specific environment only
#==========================================================#

#============= EDITOR AND TOOLS ===========================#
export EDITOR="/usr/bin/helix"
export VISUAL="$EDITOR"
export PAGER="less"
export BROWSER="firefox"
export DOTFILES_DIR="$HOME/.dotfiles"
export GODOT4_BIN="/usr/bin/godot"

#============= DEVELOPMENT TOOLS ==========================#
# Claude Code ECC plugin root (used by hooks from everything-claude-code)
export CLAUDE_PLUGIN_ROOT="$HOME/.claude/plugins/marketplaces/everything-claude-code"

export JQ_COLORS="0;90:0;37:0;37:0;37:0;32:1;37:1;37:1;34"

# Python development
export PYTHONSTARTUP="$HOME/python/pythonrc"

# .NET development
export DOTNET_CLI_HOME="$XDG_DATA_HOME/dotnet"
export NUGET_PACKAGES="$XDG_CACHE_HOME/NuGetPackages"

# Java development
export _JAVA_OPTIONS="-Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java"

#============= XDG-COMPLIANT APPLICATION DIRECTORIES =====#
# Applications migrated to XDG Base Directory compliance
# Organized by functional category for maintainability

# Development and automation tools
export ANSIBLE_HOME="$XDG_DATA_HOME/ansible"
export PASSWORD_STORE_DIR="$XDG_DATA_HOME/pass"

# Terminal and shell utilities
export TERMINFO="$XDG_DATA_HOME/terminfo"
export TERMINFO_DIRS="$XDG_DATA_HOME/terminfo:/usr/share/terminfo"

# History and state management
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export HISTFILE="$XDG_STATE_HOME/bash/history"  # For bash compatibility if needed

# Package and dependency management
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"

# Application-specific configurations
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/starship.toml"

#============= GTK APPS ===================================#
export GTK_THEME="Adwaita:dark"
export QT_QPA_PLATFORMTHEME=qt6ct

#============= PATH MANAGEMENT ============================#
# Safely add local bin to PATH without breaking system paths
# Only add if not already present to prevent duplicates on reload

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Add cargo bin directory if it exists (Rust tools)
if [[ -d "$CARGO_HOME/bin" && ":$PATH:" != *":$CARGO_HOME/bin:"* ]]; then
    export PATH="$CARGO_HOME/bin:$PATH"
fi

# Add Go bin directory if it exists
if [[ -d "$GOPATH/bin" && ":$PATH:" != *":$GOPATH/bin:"* ]]; then
    export PATH="$GOPATH/bin:$PATH"
fi

# Add npm global bin directory if it exists
if [[ -d "$XDG_DATA_HOME/npm/bin" && ":$PATH:" != *":$XDG_DATA_HOME/npm/bin:"* ]]; then
    export PATH="$XDG_DATA_HOME/npm/bin:$PATH"
fi

#============= SHELL OPTIONS ==============================#
# Disable annoying beep
unsetopt beep

#============= DIRECTORY CREATION =========================#
# Ensure required shell directories exist
mkdir -p "$XDG_CACHE_HOME/zsh" "$XDG_STATE_HOME/bash" "$XDG_STATE_HOME/less"

# Create application-specific directories as needed
[[ ! -d "$XDG_CONFIG_HOME/starship" ]] && mkdir -p "$XDG_CONFIG_HOME/starship"
[[ ! -d "$XDG_CONFIG_HOME/java" ]] && mkdir -p "$XDG_CONFIG_HOME/java"
[[ ! -d "$XDG_CONFIG_HOME/npm" ]] && mkdir -p "$XDG_CONFIG_HOME/npm"

# Ensure file always exits successfully
true
