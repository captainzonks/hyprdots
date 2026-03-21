# hyprdots

Hyprland dotfiles for Arch Linux, managed with a git bare repo. One repository, multiple machines — shared configs live on `main`, machine-specific configs live on named branches.

## Machines

| Branch | Machine | Hardware | Role |
|--------|---------|----------|------|
| `main` | — | — | Shared configs (shell, editor, terminal, CLI tools) |
| `argonaut` | Argonaut | Desktop, Ryzen 9 5900X, RTX 3080, 4K | Primary workstation |
| `spartan` | Spartan | ThinkPad E15 Gen 3, Ryzen 7 5700U, 1440p | Laptop |

## Architecture

### Bare repo pattern

The repo is cloned as a bare repository at `~/.dotfiles/`, with `$HOME` as the work tree. A `dot` alias wraps all git operations:

```bash
alias dot='git --git-dir="$HOME/.dotfiles" --work-tree="$HOME"'
```

This means dotfiles are managed in place — no symlinks, no stow, no copying. Files are tracked exactly where they live.

### Branch strategy

```
main ─────────────────────────────────── shared configs
  ├── argonaut ──────────────────────── desktop-specific
  └── spartan ───────────────────────── laptop-specific
```

**Shared configs** (on `main`) are identical across machines: shell, editor, prompt, CLI tool settings, color palettes.

**Machine branches** extend `main` with hardware-specific configs: compositor, status bar, display layout, power management, systemd services.

> **Never switch branches on a live machine.** Checking out a different branch deletes files only tracked on the current branch, which will break your running Hyprland session. Each machine stays on its own branch permanently. Shared changes flow through `main` via worktrees.

### Secret protection

The `.gitignore` uses an **ignore-everything-by-default** strategy:

```gitignore
# Ignore everything
*

# Explicitly allow tracked paths
!.config/zsh/
!.config/zsh/**
# ...
```

This means:
- Every `git add` requires the `-f` flag (the `da` alias handles this)
- Secrets, caches, and runtime files are excluded by default
- Only explicitly allowed paths can be committed
- `.config/gh/hosts.yml` (auth tokens) is explicitly blocked

## What's included

### Shared configs (`main`)

| Config | Purpose |
|--------|---------|
| **zsh** | Modular shell config (core, features, completions, aliases, functions) |
| **helix** | Modal editor with Gruvbox Dark Hard theme |
| **starship** | Cross-shell prompt with Gruvbox palette |
| **foot** | Wayland-native terminal emulator |
| **kitty** | GPU-accelerated terminal emulator |
| **lsd** | Modern `ls` replacement with custom colors |
| **git** | Global git config and credential helpers |
| **bottom** | System monitor |
| **fd** | File finder |
| **procs** | Process viewer |
| **fastfetch** | System info display |
| **wlogout** | Logout menu with custom icons |
| **colors** | Gruvbox Dark Hard CSS palette (shared color source of truth) |
| **GTK/Qt** | Dark theme settings |

### Machine-specific configs (branches)

| Config | Purpose |
|--------|---------|
| **hyprland** | Compositor config, keybindings, window rules, animations |
| **waybar** | Status bar (modules, layout, Gruvbox styling) |
| **kanshi** | Display profile management |
| **uwsm** | Session environment variables |
| **swaync** | Notification center (Gruvbox themed) |
| **hyprlock** | Lock screen (Gruvbox, static wallpaper) |
| **hypridle** | Idle behavior (lock, suspend) |
| **systemd** | User services (wallpaper, foot server, kanshi, waybar, etc.) |
| **rofi** | Application launcher (Spartan) |
| **zellij** | Terminal multiplexer (Spartan) |
| **yazi** | Terminal file manager (Spartan) |
| **wireplumber** | Audio/Bluetooth tuning (Spartan) |
| **scripts** | Hyprland utilities, power management, diagnostics |

## Theme

**Gruvbox Dark Hard** across the entire system. A single CSS palette at `.config/colors/gruvbox-dark-palette.css` is the source of truth — other configs reference it or use equivalent hex values.

```
Background:  #1d2021    Foreground:  #ebdbb2
Red:         #fb4934    Green:       #b8bb26
Yellow:      #fabd2f    Blue:        #83a598
Purple:      #d3869b    Aqua:        #8ec07c
Orange:      #fe8019    Gray:        #928374
```

## Setup

### Prerequisites

Arch Linux with the following core packages:

```
hyprland foot kitty zsh starship helix lsd
waybar swaync kanshi uwsm wlogout hyprlock hypridle
```

### Installation

```bash
# Clone the bare repo
git clone --bare git@github.com:captainzonks/hyprdots.git "$HOME/.dotfiles"

# Define the dot alias for this session
dot() { git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" "$@"; }

# Hide untracked files from status output
dot config status.showUntrackedFiles no

# Checkout your machine branch (creates it from main if new)
dot checkout -b <machine-name> main -f

# Reload your shell to pick up aliases
source ~/.config/zsh/.zshrc
```

> The `-f` flag on checkout will overwrite existing config files with the versions from `main`. Back up anything you want to keep first.

### Adding a new machine

```bash
# After cloning, create a new branch from main
dot checkout -b <machine-name> main -f

# Add machine-specific configs
da .config/hypr/ .config/waybar/ .config/kanshi/
dc "feat: add <machine-name> configs"
dp -u origin <machine-name>
```

## Daily workflow

### Aliases

The `dot` aliases are defined in `.config/zsh/features/40-aliases.zsh`:

| Alias | Command | Purpose |
|-------|---------|---------|
| `dot` | `git --git-dir=... --work-tree=...` | Base command |
| `ds` | `dot status` | Check what changed |
| `da` | `dot add -f` | Stage files (force past gitignore) |
| `dc` | `dot commit -m` | Commit with message |
| `dp` | `dot push` | Push to remote |
| `dpl` | `dot pull` | Pull from remote |
| `dd` | `dot diff` | View unstaged changes |
| `ddc` | `dot diff --cached` | View staged changes |
| `dl` | `dot log --oneline --graph --decorate` | Commit history |
| `db` | `dot branch` | List branches |

### Propagating shared changes to main

When you change a shared config on a machine branch and want it everywhere:

```bash
# 1. Commit on your branch normally
dc "feat: update zsh aliases"
dp

# 2. Use a worktree to apply to main
dot worktree add /tmp/hyprdots-main main
cp ~/.config/zsh/features/40-aliases.zsh /tmp/hyprdots-main/.config/zsh/features/
cd /tmp/hyprdots-main
git add -f .config/zsh/features/40-aliases.zsh
git commit -m "feat: update zsh aliases"
git push
cd ~
dot worktree remove /tmp/hyprdots-main

# 3. Rebase your branch onto main
dot rebase origin/main
dp --force-with-lease
```

### Pulling shared changes from another machine

```bash
dot fetch origin
dot rebase origin/main
dp --force-with-lease
```

## Shell structure

The zsh config is modular, loaded in dependency order:

```
~/.config/zsh/
  .zshrc                    # Entry point — XDG setup, modular loader
  core/
    00-environment.zsh      # Editor, paths, XDG compliance
    10-history.zsh          # History settings
    20-keybindings.zsh      # Key bindings
  features/
    30-completions.zsh      # Tab completion
    40-aliases.zsh          # All aliases (dot, git, system, apps)
    50-functions.zsh        # Shell functions (hip, murder, game, etc.)
    60-autostart.zsh        # Keychain, zoxide
    70-plugins.zsh          # Plugin loading
  completions/              # Tool-specific completions
  init/                     # Pre-generated init scripts (starship, zoxide)
```

## License

These are my personal dotfiles. Feel free to use anything you find useful. No warranty, no support — but if something here helps you build a better setup, that's a win.
