#!/usr/bin/env bash
# Battery Status Monitor for ThinkPad
# Shows comprehensive battery information including health metrics

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== ThinkPad Battery Status ===${NC}"

# Find battery
BATTERY_PATH="/sys/class/power_supply/BAT0"
[[ ! -d "$BATTERY_PATH" ]] && BATTERY_PATH="/sys/class/power_supply/BAT1"

if [[ ! -d "$BATTERY_PATH" ]]; then
    echo -e "${RED}✗ No battery found${NC}"
    exit 1
fi

# Basic battery information
echo "Battery Location: $BATTERY_PATH"
echo "Status: $(cat "$BATTERY_PATH/status" 2>/dev/null || echo 'Unknown')"
echo "Capacity: $(cat "$BATTERY_PATH/capacity" 2>/dev/null || echo 'Unknown')%"

# Detailed capacity information
if [[ -f "$BATTERY_PATH/charge_full_design" ]] && [[ -f "$BATTERY_PATH/charge_full" ]]; then
    DESIGN_CAPACITY=$(cat "$BATTERY_PATH/charge_full_design")
    FULL_CAPACITY=$(cat "$BATTERY_PATH/charge_full")
    HEALTH_PERCENT=$(echo "scale=1; $FULL_CAPACITY * 100 / $DESIGN_CAPACITY" | bc -l 2>/dev/null || echo "Unknown")
    echo "Battery Health: ${HEALTH_PERCENT}%"
    
    # Health assessment
    if (( $(echo "$HEALTH_PERCENT > 85" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${GREEN}✓ Battery health is excellent${NC}"
    elif (( $(echo "$HEALTH_PERCENT > 70" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${YELLOW}⚠ Battery health is good${NC}"
    else
        echo -e "${RED}⚠ Battery health is degraded${NC}"
    fi
fi

# Charge thresholds
echo ""
echo -e "${BLUE}Charge Thresholds:${NC}"
if [[ -f "$BATTERY_PATH/charge_control_start_threshold" ]]; then
    START_THRESH=$(cat "$BATTERY_PATH/charge_control_start_threshold" 2>/dev/null || echo "Not set")
    STOP_THRESH=$(cat "$BATTERY_PATH/charge_control_end_threshold" 2>/dev/null || echo "Not set")
    echo "  Start charging at: ${START_THRESH}%"
    echo "  Stop charging at: ${STOP_THRESH}%"
else
    echo "  Charge thresholds: Managed by TLP"
fi

# Power consumption (if available)
if [[ -f "$BATTERY_PATH/power_now" ]]; then
    POWER_NOW=$(cat "$BATTERY_PATH/power_now" 2>/dev/null)
    if [[ "$POWER_NOW" -gt 0 ]]; then
        POWER_WATTS=$(echo "scale=2; $POWER_NOW / 1000000" | bc -l)
        echo "Current Power Draw: ${POWER_WATTS}W"
    fi
fi

# Cycle count (if available)
if [[ -f "$BATTERY_PATH/cycle_count" ]]; then
    CYCLES=$(cat "$BATTERY_PATH/cycle_count" 2>/dev/null || echo "Unknown")
    echo "Charge Cycles: $CYCLES"
fi

# TLP status
echo ""
echo -e "${BLUE}TLP Power Management:${NC}"
if command -v tlp-stat >/dev/null 2>&1; then
    echo "TLP Version: $(tlp-stat -s | grep "TLP version" | cut -d' ' -f3 2>/dev/null || echo 'Unknown')"
    echo "Power Source: $(tlp-stat -s | grep "Power source" | cut -d':' -f2 | xargs 2>/dev/null || echo 'Unknown')"
    echo "TLP Mode: $(tlp-stat -s | grep "TLP mode" | cut -d':' -f2 | xargs 2>/dev/null || echo 'Unknown')"
else
    echo "TLP not installed or not in PATH"
fi

echo ""
echo "Run 'tlp-stat -b' for detailed battery information"
echo "Run 'tlp-stat -s' for full TLP status"
