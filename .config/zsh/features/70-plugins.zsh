#==========================================================#
#                   ZSH PLUGINS CONFIG                     #
#==========================================================#
# File: features/70-plugins.zsh
# Purpose: Load ZSH plugins and extensions
# Dependencies: Core ZSH configuration
# Last Updated: 2025-06-30
# Documentation: https://github.com/zdharma-continuum/fast-syntax-highlighting
#
# Security Notes:
# - Only loads system-installed plugins (package manager)
# - Checks plugin availability before sourcing
# - Loads plugins last to avoid conflicts with configuration
#==========================================================#

#============= FAST SYNTAX HIGHLIGHTING ==================#
# Load fast-syntax-highlighting plugin if available
if [[ -f "/usr/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
    source "/usr/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
else
    echo "Warning: zsh-fast-syntax-highlighting plugin not found" >&2
fi

#============= ADDITIONAL PLUGINS ========================#
# Add other plugins here as needed
# Example format:
# if [[ -f "/path/to/plugin/plugin.zsh" ]]; then
#     source "/path/to/plugin/plugin.zsh"
# fi

#==========================================================#
# Notes:
# - Plugins load after all other features (70- prefix)
# - System-installed plugins are preferred for security
# - Each plugin should have availability check
# - Plugins that modify prompt should load before starship
#==========================================================#
