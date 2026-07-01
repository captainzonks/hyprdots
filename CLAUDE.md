# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the **Argonaut** dotfiles repository — a new Arch Linux desktop installation. The git working tree is the home directory itself (`~`), so all tracked paths are relative to `$HOME`. Remote: `git@github.com:captainzonks/hyprdots.git`. This desktop config lives on the `argonaut` branch; the Spartan laptop config lives on the `spartan` branch; `main` holds machine-agnostic shared config.

The repo is actively being built out. Many files in `git status` show `D` (tracked in git history from the laptop but not yet present on this machine) and `??` (new untracked files being added as the desktop is configured).

## Dotfiles Git Workflow

```sh
git status                    # see what's changed/missing/new
git add .config/zsh/...       # stage specific config files
git commit -m "message"
git push
```

To review untracked files filtered through the excludes list:
```sh
dotu        # uses ~/.config/dotfiles/excludes pathspec patterns
dotua       # unfiltered
```

`~/.config/dotfiles/excludes` contains `:!:` pathspec patterns to suppress noise (caches, app state, binaries, etc.).

## Shell & Editor

- **Shell**: ZSH — config in `~/.config/zsh/` (modular, loaded numerically)
- **Editor**: Helix, aliased as `him`
- **Reload ZSH**: `zup` (sources `~/.config/zsh/.zshrc`)

ZSH config load order:
1. `~/.config/zsh/core/` — environment, history, keybindings
2. `~/.config/zsh/features/` — completions, aliases, functions, autostart, plugins
3. `~/.config/zsh/init/` — pre-generated starship/zoxide init files

## Currently Configured

Configs set up: `zsh`, `foot`, `helix`, `zellij`, `starship`, `fastfetch`, `lsd`, `bottom`, `fd`, `procs`, `gh`, `git`, `hyprland`, `waybar`, `swaync`, `kitty`, `kanshi`, `wlogout`, `cursor-clip`, `hypridle`, `hyprlock`, `hyprsunset`, GTK theming (Gruvbox-Material-Dark icon theme), systemd user services.

Not yet set up (from Spartan-Arch reference): rofi, matugen, udiskie, wayland-pipewire-idle-inhibit.

## Key Aliases (from `~/.config/zsh/features/40-aliases.zsh`)

| Alias | Meaning |
|-------|---------|
| `him` | `helix` (editor) |
| `paru` / `yay` | AUR package manager |
| `l` / `ls` | `lsd -la` / `lsd` |
| `cd` / `cdi` | `zoxide z` / `zi` |
| `gs`, `ga`, `gc`, `gp` | git status/add/commit/push |
| `report` / `ureport` | `journalctl` system/user follow |
| `systat` / `sustat` | systemctl system/user status |
| `zup` | reload ZSH config |

## Package Management

```sh
paru <package>       # install
yeet <package>       # paru -Rcs (remove with deps + orphans)
lost                 # paru -Qdt (list orphans)
pclean               # paru -Scc (clean cache)
```
