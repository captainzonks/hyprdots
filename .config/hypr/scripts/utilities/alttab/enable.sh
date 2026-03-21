#!/usr/bin/env bash
# =============================================================================
# Alt-Tab Enable
# =============================================================================
# Enables alt-tab mode with keybindings and animation disabling
#
# Dependencies: hyprctl, footclient
# =============================================================================
hyprctl -q --batch "keyword animations:enabled false ; \
  dispatch exec footclient -a alttab ~/.config/hypr/scripts/utilities/alttab/alttab.sh $1 ; \
  keyword unbind ALT, TAB ; \
  keyword unbind ALT SHIFT, TAB ; \
  dispatch submap alttab"
