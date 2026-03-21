#!/usr/bin/env bash
# =============================================================================
# Alt-Tab Disable
# =============================================================================
# Disables alt-tab mode and restores default keybindings
#
# Dependencies: hyprctl
# =============================================================================
hyprctl -q keyword animations:enabled true

hyprctl -q --batch "keyword unbind ALT, TAB ; \
                    keyword unbind ALT SHIFT, TAB ; \
                    keyword bind ALT, TAB, exec, $HOME/.config/hypr/scripts/utilities/alttab/enable.sh 'down' ; \
                    keyword bind ALT SHIFT, TAB, exec, $HOME/.config/hypr/scripts/utilities/alttab/enable.sh 'up'"
