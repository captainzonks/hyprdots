#!/usr/bin/env bash
# =============================================================================
# Kitty Color Applicator
# =============================================================================
# Reloads Kitty terminals to apply new Material You colors
# Only runs if Material You theme is enabled in kitty.conf
#
# Dependencies: kitty
# =============================================================================

# Check if Material You colors are enabled in config
if ! grep -q "^include colors-material-you.conf" "$HOME/.config/kitty/kitty.conf" 2>/dev/null; then
    # Material You theme not active, skip
    exit 0
fi

# Apply new colors to all running Kitty instances
# Note: Requires allow_remote_control and listen_on to be configured
if kitty @ --to unix:@mykitty load-config 2>/dev/null; then
    echo "Kitty colors reloaded"
else
    # Fallback: If remote control fails, just log
    echo "Kitty remote control not available, colors will apply to new windows"
fi
