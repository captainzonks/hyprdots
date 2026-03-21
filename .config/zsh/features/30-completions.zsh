#==========================================================#
#                    ZSH COMPLETIONS                       #
#==========================================================#
# File: features/30-completions.zsh
# Purpose: ZSH completion system configuration
# Dependencies: Core ZSH configuration
# Last Updated: 2025-10-30
# Documentation: https://zsh.sourceforge.io/Doc/Release/Completion-System.html
#==========================================================#

#============= COMPLETION SYSTEM SETUP ===================#
# Configure completion system with XDG-compliant paths
zstyle :compinstall filename "$XDG_CONFIG_HOME/zsh/.zshrc"

# Load completions lazily for better startup performance
autoload -Uz compinit

#============= COMPLETION CACHE MANAGEMENT ===============#
# Use XDG-compliant cache location for completion dump
ZCOMPDUMP_FILE="$XDG_CACHE_HOME/zsh/.zcompdump"

# Ensure cache directory exists
mkdir -p "$(dirname "$ZCOMPDUMP_FILE")"

# Check if we need to regenerate completions
# Regenerate if main config is newer than dump file
if [[ "$ZCOMPDUMP_FILE" -nt "$XDG_CONFIG_HOME/zsh/.zshrc" ]]; then
    # Use cached completions for faster startup
    compinit -C -d "$ZCOMPDUMP_FILE"
else
    # Regenerate completion cache
    compinit -d "$ZCOMPDUMP_FILE"

    # Compile the completion dump for even faster loading
    [[ -f "$ZCOMPDUMP_FILE" && ! -f "${ZCOMPDUMP_FILE}.zwc" ]] && zcompile "$ZCOMPDUMP_FILE"
fi

#============= CUSTOM COMPLETIONS LOADING ================#
# Load custom completions from completions directory
COMPLETIONS_DIR="$XDG_CONFIG_HOME/zsh/completions"

if [[ -d "$COMPLETIONS_DIR" ]]; then
    # Add completions directory to fpath
    fpath=("$COMPLETIONS_DIR" $fpath)

    # Source any .zsh completion files directly (with error handling)
    for completion_file in "$COMPLETIONS_DIR"/*.zsh(N); do
        [[ -r "$completion_file" ]] && source "$completion_file"
    done

    # Load any _* completion functions (with safe globbing)
    local completion_funcs=("$COMPLETIONS_DIR"/_*(N))
    for completion_func in "${completion_funcs[@]}"; do
        [[ -r "$completion_func" ]] && autoload -Uz "$(basename "$completion_func")"
    done
fi

#============= COMPLETION STYLES ==========================#
# Modern completion styling for better UX

# Menu selection behavior
zstyle ':completion:*' menu select
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate

# Case-insensitive matching with additional fuzzy matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Visual styling with colors
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS:-}"
zstyle ':completion:*' verbose true
zstyle ':completion:*:descriptions' format '%B%F{green}-- %d --%f%b'
zstyle ':completion:*:messages' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- No matches found --%f'

# Group matches and describe
zstyle ':completion:*' group-name ''
zstyle ':completion:*:matches' group 'yes'

# Process completion
zstyle ':completion:*:processes' command 'ps -u $USER -o pid,user,comm -w -w'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'

# Directory completion
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*:cd:*' ignore-parents parent pwd
zstyle ':completion:*' special-dirs true

# SSH/SCP/RSYNC completion
zstyle ':completion:*:(ssh|scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr

# Command completion caching
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/completion-cache"

# Ensure completion cache directory exists
mkdir -p "$XDG_CACHE_HOME/zsh/completion-cache"

#============= APPLICATION-SPECIFIC COMPLETIONS =========#
# Load completions for commonly used tools

# Git completion enhancements
if command -v git >/dev/null 2>&1; then
    zstyle ':completion:*:*:git:*' tag-order 'common-commands'
    zstyle ':completion:*:*:git*:*' ignored-patterns '*ORIG_HEAD'
fi

#============= PERFORMANCE OPTIMIZATIONS =================#
# Optimize completion performance for better responsiveness

# Limit the number of completions shown
zstyle ':completion:*' max-errors 2 not-numeric
zstyle ':completion:*:approximate:*' max-errors 'reply=( $((($#PREFIX+$#SUFFIX)/3 )) numeric )'

# Speed up completion by avoiding certain slow completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' accept-exact-dirs true

# Use completion cache aggressively
zstyle ':completion:*' rehash true
