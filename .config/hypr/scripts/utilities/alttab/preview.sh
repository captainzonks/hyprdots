#!/usr/bin/env bash
# =============================================================================
# Alt-Tab Preview
# =============================================================================
# Generates window preview for FZF using hyprctl
#
# Dependencies: hyprctl
# =============================================================================
line="$1"

IFS=$'\t' read -r addr _ <<< "$line"
dim=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}

grim -t png -l 0 -w "$addr" ~/.config/hypr/scripts/utilities/alttab/preview.png
chafa -f sixels --animate=false -s "$dim" "$XDG_CONFIG_HOME/hypr/scripts/utilities/alttab/preview.png"
