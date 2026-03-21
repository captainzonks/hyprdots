#==========================================================#
#                  ZSH AUTOSTART CONFIG                    #
#==========================================================#
# File: features/60-autostart.zsh
# Purpose: Initialize external tools and services
# Dependencies: Core ZSH configuration, XDG environment
# Last Updated: 2025-06-30
# Documentation: https://github.com/funtoo/keychain
#
# Security Notes:
# - Keychain only runs on login shells or when keys not loaded
# - Safe fallbacks for missing environment variables
# - External tools initialized with proper error handling
#==========================================================#
 
#=====================# MACHINE SECRETS #=================#
# Source machine-specific values (MAC addresses, hostnames, etc.)
# This file is NOT tracked by the dotfiles repo
#==========================================================#
[[ -f "$XDG_CONFIG_HOME/machine.env" ]] && source "$XDG_CONFIG_HOME/machine.env"

#=====================# GNOME KEYRING #===================#
# Handled by systemd socket activation (gnome-keyring-daemon.socket)
# Apps request secrets via D-Bus, systemd starts the daemon on demand
# SSH is handled by keychain below (--nogui, TTY-friendly)
#==========================================================#

#=====================# KEYCHAIN #=========================#
# Only run keychain on login shells or if keys aren't loaded
# Handle missing XDG_RUNTIME_DIR gracefully
#==========================================================#
if [[ -o login ]] || ! ssh-add -l >/dev/null 2>&1; then
    # Ensure XDG_RUNTIME_DIR is available for keychain
    if [[ -n "$XDG_RUNTIME_DIR" && -d "$XDG_RUNTIME_DIR" ]]; then
        eval "$(keychain --dir ${XDG_RUNTIME_DIR}/keychain --absolute --eval --quiet --nogui id_ed25519)"
    elif [[ -d "/run/user/$(id -u)" ]]; then
        # Fallback to standard runtime directory
        eval "$(keychain --dir /run/user/$(id -u)/keychain --absolute --eval --quiet --nogui id_ed25519)"
    else
        # Skip keychain if no suitable runtime directory
        echo "Warning: No suitable runtime directory for keychain - skipping SSH key loading" >&2
    fi
fi

#=====================# ZOXIDE INIT ======================#
# Initialize zoxide for smart directory jumping
#==========================================================#
if command -v zoxide >/dev/null 2>&1; then
    # Use pre-generated init file if available, otherwise generate
    if [[ -f "$XDG_CONFIG_HOME/zsh/init/zoxide.zsh" ]]; then
        source "$XDG_CONFIG_HOME/zsh/init/zoxide.zsh"
    else
        # Fallback: generate and cache zoxide init
        if [[ ! -f "$XDG_CACHE_HOME/zsh/zoxide_init.zsh" ]] || \
           [[ "$XDG_CONFIG_HOME/zsh/.zshrc" -nt "$XDG_CACHE_HOME/zsh/zoxide_init.zsh" ]]; then
            zoxide init zsh > "$XDG_CACHE_HOME/zsh/zoxide_init.zsh"
        fi
        source "$XDG_CACHE_HOME/zsh/zoxide_init.zsh"
    fi
else
    echo "Warning: zoxide not found - directory jumping with 'z' will not work" >&2
fi

#=====================# STARSHIP INIT ===================#
# Note: Starship is initialized in main .zshrc to ensure
# all other configurations are loaded first
