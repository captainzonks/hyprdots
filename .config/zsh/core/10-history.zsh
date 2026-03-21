#==========================================================#
#                   ZSH HISTORY CONFIG                     #
#==========================================================#
# File: core/10-history.zsh
# Purpose: ZSH history configuration and optimization
# Dependencies: XDG environment variables
# Last Updated: 2025-10-30
# Documentation: https://zsh.sourceforge.io/Doc/Release/Options.html#History
#
# Security Notes:
# - Commands starting with space are not recorded
# - History file uses XDG-compliant location
# - Sensitive command patterns can be filtered
#==========================================================#

#============= HISTORY FILE CONFIGURATION ================#
# Use XDG-compliant location for history
export HISTFILE="$XDG_CACHE_HOME/zsh/history"
export HISTSIZE=50000
export SAVEHIST=50000

# Ensure history directory exists
mkdir -p "$(dirname "$HISTFILE")"

#============= HISTORY OPTIONS ============================#
# Modern history behavior optimized for daily use

# File format and timing
setopt EXTENDED_HISTORY          # Record timestamp and duration
setopt INC_APPEND_HISTORY        # Append immediately, don't wait for exit
setopt SHARE_HISTORY             # Share history between sessions

# Duplicate handling
setopt HIST_IGNORE_ALL_DUPS      # Remove older duplicate entries
setopt HIST_IGNORE_DUPS          # Don't record consecutive duplicates
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicates first when trimming
setopt HIST_SAVE_NO_DUPS         # Don't save duplicates to file

# Content filtering
setopt HIST_IGNORE_SPACE         # Commands starting with space are not recorded
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks
setopt HIST_VERIFY               # Show expanded history before executing

# Search behavior
setopt HIST_FIND_NO_DUPS         # Don't show duplicates in search
