#==========================================================#
#                 ZSH KEYBINDINGS CONFIG                   #
#==========================================================#
# File: core/20-keybindings.zsh
# Purpose: Key bindings and vi mode configuration
# Dependencies: ZSH vi mode, FZF (optional)
# Last Updated: 2025-06-30
# Documentation: https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html
#
# Security Notes:
# - Vi mode keybindings for secure command editing
# - FZF integration only if command available
# - Terminal compatibility checks for cursor changes
#==========================================================#

#============= VI MODE SETUP ==============================#
# Enable vi mode
bindkey -v

# Remove delay when entering normal mode (ESC)
export KEYTIMEOUT=1

#============= FZF INTEGRATION ============================#
# Set up FZF key bindings if available
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
else
    echo "Warning: FZF not found - history search will use basic ZSH functionality" >&2
fi

#============= ENHANCED BINDINGS ==========================#
# Better vi mode cursor indication (if terminal supports it)
if [[ "$TERM" != "linux" ]]; then
    cursor_block='\e[2 q'
    cursor_beam='\e[6 q'

    function zle-keymap-select {
        if [[ ${KEYMAP} == vicmd ]] ||
           [[ $1 = 'block' ]]; then
            echo -ne $cursor_block
        elif [[ ${KEYMAP} == main ]] ||
             [[ ${KEYMAP} == viins ]] ||
             [[ ${KEYMAP} = '' ]] ||
             [[ $1 = 'beam' ]]; then
            echo -ne $cursor_beam
        fi
    }

    zle-line-init() {
        echo -ne $cursor_beam
    }

    zle -N zle-keymap-select
    zle -N zle-line-init
fi

#============= COMPLETION NAVIGATION ======================#
# Tab completion navigation
bindkey '^I' complete-word              # Tab
bindkey '^[[Z' reverse-menu-complete    # Shift+Tab

# Menu selection (if completion menu is active)
zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
