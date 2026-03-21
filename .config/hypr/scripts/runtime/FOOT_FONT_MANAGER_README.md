# Foot Font Manager v2.1.0

## Overview
Dynamic font size management for Foot terminal with intelligent restart logic that balances terminal preservation with font updates.

## Key Changes in v2.1.0 (2025-10-30)

### Intelligent Restart Behavior
- ✅ **Smart detection** - Checks if any terminals are open before deciding
- ✅ **Auto-restart when safe** - If NO terminals open, automatically restarts server
- ✅ **Preserve when needed** - If terminals ARE open, preserves them and notifies you
- ✅ **Clear notifications** - Tells you exactly what happened and what to do next
- ✅ **Actually works** - New terminals now correctly get the updated font size

### How It Works Now
The script intelligently decides whether to restart the foot server:

**Case 1: No active terminals**
1. Detects monitor change
2. Updates config symlink
3. **Automatically restarts foot server** (safe, no data loss)
4. Shows notification: "Server restarted - all terminals using new font"
5. New terminals immediately use correct font size ✅

**Case 2: Active terminals exist**
1. Detects monitor change
2. Updates config symlink
3. **Preserves existing terminals** (no interruption)
4. Shows notification: "Config updated but terminals preserved - Restart server to apply: SUPER+SHIFT+T"
5. User manually restarts when ready using SUPER+SHIFT+T keybind

## Usage

### Automatic (via Kanshi)
When you plug/unplug monitors, Kanshi automatically runs the script.

**If you have NO terminals open**: The font applies immediately, no action needed.

**If you have terminals open**: Your terminals stay open. When you're ready to apply the new font, press `SUPER+SHIFT+T` to restart the foot server.

### Manual Commands

```bash
# Auto-detect and switch (preserves terminals)
~/.config/hypr/scripts/runtime/foot_font_manager.sh auto

# Force specific config (preserves terminals)
~/.config/hypr/scripts/runtime/foot_font_manager.sh laptop
~/.config/hypr/scripts/runtime/foot_font_manager.sh external

# Force restart to apply immediately (closes all terminals)
~/.config/hypr/scripts/runtime/foot_font_manager.sh laptop-restart
~/.config/hypr/scripts/runtime/foot_font_manager.sh external-restart

# Check current status
~/.config/hypr/scripts/runtime/foot_font_manager.sh status
```

## Use Cases

### Scenario 1: Monitor Switching (Default)
**Situation**: You unplug your laptop from LG monitor and go mobile.

**What happens**:
1. Kanshi detects monitor change
2. Script switches to laptop config (size 8)
3. Your existing terminals stay open with current font
4. You get a notification about the change
5. Next terminal you open uses size 8 font

**Action needed**: None, or open new terminals when convenient.

### Scenario 2: Need Immediate Change
**Situation**: After monitor switch, you want all terminals to use the new font right away.

**What happens**:
1. Run: `foot_font_manager.sh laptop-restart`
2. All terminals close (saves your tmux/zellij sessions first!)
3. Foot server restarts with new config
4. All new terminals use the correct font immediately

**Action needed**: Run the `-restart` variant of the command.

## Font Sizes

| Monitor Type | Resolution | Font Size |
|-------------|-----------|-----------|
| Laptop      | 1920x1080 | 8         |
| External    | 2560x1440 | 10        |

## Configuration Files

```
~/.config/foot/
├── foot.ini             -> Symlink to active config
├── foot_laptop.ini      -> Laptop config (size 8)
├── foot_external.ini    -> External config (size 10)
└── colors.ini           -> Shared color scheme
```

## Technical Details

### How It Works
The script uses symlinks for zero-overhead config switching:
1. `foot.ini` is a symlink pointing to either laptop or external config
2. When switching, the symlink is updated instantly
3. Foot server reads config on startup, so existing clients unaffected
4. New terminals (footclient) connect and use the new config

### State Tracking
Current config state stored in: `/run/user/$(id -u)/foot_font_state`

### Integration Points
- **Kanshi**: Calls script on monitor change
- **Hyprland**: No direct integration needed
- **Systemd**: Manages foot-server.service

## Troubleshooting

### Terminals showing wrong font size
**Cause**: Old terminals opened before the switch.
**Fix**: Close and reopen those terminals, or use `-restart` command.

### Config not switching automatically
**Cause**: Kanshi may not be running or detecting monitor.
**Check**: `systemctl --user status kanshi.service`
**Fix**: `systemctl --user restart kanshi.service`

### Want to customize font sizes
**Edit**: Lines 29-30 in `foot_font_manager.sh`
```bash
readonly LAPTOP_FONT_SIZE=8      # Change this
readonly EXTERNAL_FONT_SIZE=10   # Change this
```
Then run: `foot_font_manager.sh init` to recreate configs

## Benefits Over v1.0.0

| Aspect | v1.0.0 | v2.0.0 |
|--------|--------|--------|
| Terminal preservation | ❌ Closes all | ✅ Preserves all |
| User interruption | High | None |
| Data loss risk | Medium | None |
| Flexibility | Low | High (optional restart) |
| Notifications | ❌ No | ✅ Yes |

## Related Files

- Kanshi config: `~/.config/kanshi/config`
- Foot configs: `~/.config/foot/`
- Hyprland keybinds: `~/.config/hypr/conf/keybinding.conf`

## Version History

- **v2.0.0** (2025-10-30): Non-destructive config switching
- **v1.0.0** (2025-09-11): Initial release with automatic switching
