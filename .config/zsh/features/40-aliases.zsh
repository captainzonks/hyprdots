#==========================================================#
#                      ZSH ALIASES                         #
#==========================================================#
# File: features/40-aliases.zsh
# Purpose: ZSH alias list configuration
# Dependencies: Core ZSH configuration, XDG environment
# Last Updated: 2025-10-30
# Documentation: https://zsh.sourceforge.io/Doc/Release/
#==========================================================#
 
#========# Shell & Environment #===========================#
#==========================================================#
 
#----- zsh
alias zup='source "$XDG_CONFIG_HOME/zsh/.zshrc"'
alias zedit='him "$XDG_CONFIG_HOME/zsh/.zshrc"'
# CORE
alias zenv='him "$XDG_CONFIG_HOME/zsh/core/00-environment.zsh"'
alias zist='him "$XDG_CONFIG_HOME/zsh/core/10-history.zsh"'
alias zkeys='him "$XDG_CONFIG_HOME/zsh/core/20-keybindings.zsh"'
# FEATURES
alias zomp='him "$XDG_CONFIG_HOME/zsh/features/30-completions.zsh"'
alias zalii='him "$XDG_CONFIG_HOME/zsh/features/40-aliases.zsh"'
alias zunc='him "$XDG_CONFIG_HOME/zsh/features/50-functions.zsh"'
alias zauto='him "$XDG_CONFIG_HOME/zsh/features/60-autostart.zsh"'
alias zugins='him "$XDG_CONFIG_HOME/zsh/features/70-plugins.zsh"'

#----- Zellij
alias engage='eval "$(zellij setup --generate-auto-start zsh)"'

#----- Basic Commands
alias cd='z'
alias cdi='zi'
alias l='lsd -la'
alias ls='lsd'
alias tarup='tar -cvf' # {file.tar.gz} {src_file_or_dir}

#----- Package Manager
alias yay='paru'
alias boo='paru -R'
alias yeet='paru -Rcs'
alias lost='paru -Qdt'
alias pclean='paru -Scc'
alias pacnew='DIFFPROG=meld pacdiff -s'

#----- Apps
alias ff='fastfetch'

alias jqs='jq -CR --stream --unbuffered .'
alias bcat='bat --paging=never -l log' # for piping active stdout into bat for color

# find captive portal for public wifi networks
alias captive='curl -I http://detectportal.firefox.com/canonical.html'

# convert png to svg
alias tosvg='uv run https://raw.githubusercontent.com/nicobailon/png2svg/main/png2svg.py convert' # <image.png> <image.svg>

#========# Hyprland #======================================#
#==========================================================#
export HYPR_CONFIG_HOME=${XDG_CONFIG_HOME}/hypr
alias hdir="cd ${HYPR_CONFIG_HOME}"

#GUI Applications

#----- Compositors
alias niri='systemctl --user start niri.service'

#----- Terminal Emulator
alias foot='footclient'

#----- Game Dev
alias parsim='godot repos/particle-simulation/godot_project/project.godot'

#----- Games
alias gamehdr='gamescope -W 3840 -H 2160 -f --hdr-enabled -- steam -gamepadui'

#========# App Helpers #===================================#
#==========================================================#
alias wget='wget --hsts-file="$XDG_DATA_HOME/wget-hsts"'
alias keychain='keychain --dir "$XDG_RUNTIME_DIR/keychain" --absolute'

#========# Editor #========================================#
#==========================================================#
alias him='helix'
alias shim='sudo helix'

#========# Rust #==========================================#
#==========================================================#
alias rup="rustup update"
alias rinit="cargo init"
alias rbuild="cargo build"
alias rcheck="cargo check"

#========# System #========================================#
#==========================================================#

#----- Journal
alias report='journalctl -f -b -xe'
alias error='journalctl -b -xe -p err'
alias shit='journalctl -b -xe -u'
alias ureport='journalctl --user -f -b -xe'
alias uerror='journalctl --user -b -xe -p err'
alias ushit='journalctl --user -b -xe -u'

#----- System (sudo)
alias dload='sudo systemctl daemon-reload'
alias systat='systemctl status'
alias sysable='sudo systemctl enable'
alias sysdis='sudo systemctl disable'
alias systart='sudo systemctl start'
alias systop='sudo systemctl stop'
alias sysrst='sudo systemctl restart'
alias sysreset='sudo systemctl reset-failed'

#----- System (user)
alias duload='systemctl --user daemon-reload'
alias sustat='systemctl --user status'
alias susable='systemctl --user enable'
alias susdis='systemctl --user disable'
alias sustart='systemctl --user start'
alias sustop='systemctl --user stop'
alias susrst='systemctl --user restart'
alias susreset='systemctl --user reset-failed'

#----- Power/State
alias shutdown='systemctl poweroff'
alias suspend='systemctl suspend'
alias hibernate='systemctl hibernate'
alias gowindows='systemctl reboot --boot-loader-entry=windows.conf'

#----- Network
alias wifi='nmtui'
alias ports='sudo lsof -iTCP -sTCP:LISTEN -P -n'

#========# Git #===========================================#
#==========================================================#
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gst="git stash"
alias gsp="git stash; git pull"
alias gfo="git fetch origin"
alias gcheck="git checkout"
alias gcredential="git config credential.helper store"

# Modern git workflow aliases
alias gd='git diff'
alias gdc='git diff --cached'
alias gl='git log --oneline --graph --decorate'
alias gb='git branch'
alias gbd='git branch -d'
alias grb='git rebase'
alias grbi='git rebase -i'

#----- Dotfiles (bare repo)
alias dot='git --git-dir="$HOME/.dotfiles" --work-tree="$HOME"'
alias ds='dot status'
alias da='dot add -f'
alias dc='dot commit -m'
alias dp='dot push'
alias dpl='dot pull'
alias dd='dot diff'
alias ddc='dot diff --cached'
alias dl='dot log --oneline --graph --decorate'
alias db='dot branch'
alias dcheck='dot checkout'
alias dsync='dot fetch origin && dot rebase origin/main && dot push --force-with-lease && hyprctl reload'

