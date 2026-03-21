#!/usr/bin/env bash
# =============================================================================
# SwayNC System Alerts
# =============================================================================
# Sends system health and monitoring notifications through swaync
# Provides standardized alert interface for system scripts
#
# Dependencies: swaync-client
# =============================================================================

send_system_alert() {
    local level=$1
    local title=$2
    local message=$3
    local icon=${4:-"dialog-information"}
    
    case "$level" in
        critical)
            swaync-client -n --title "$title" --body "$message" --icon "$icon" --urgency critical --expire-time 0
            ;;
        warning)
            swaync-client -n --title "$title" --body "$message" --icon "$icon" --urgency normal --expire-time 10000
            ;;
        info)
            swaync-client -n --title "$title" --body "$message" --icon "$icon" --urgency low --expire-time 5000
            ;;
    esac
}

# Check system health and send alerts
check_and_alert() {
    # Check temperature
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    temp=$((temp / 1000))
    
    if [[ $temp -gt 85 ]]; then
        send_system_alert "critical" "System Overheating" "CPU temperature: ${temp}°C - Consider closing applications" "dialog-warning"
    elif [[ $temp -gt 75 ]]; then
        send_system_alert "warning" "High Temperature" "CPU temperature: ${temp}°C" "dialog-information"
    fi
    
    # Check for USB-C errors
    if dmesg | tail -10 | grep -qi "xhci.*died\|xhci.*error"; then
        send_system_alert "critical" "USB-C Controller Error" "Hardware failure detected - check system logs" "dialog-error"
    fi
    
    # Check memory usage
    local mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100.0}')
    if [[ $mem_usage -gt 95 ]]; then
        send_system_alert "warning" "Low Memory" "Memory usage: ${mem_usage}% - Consider closing applications" "dialog-warning"
    fi
    
    # Check disk usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 95 ]]; then
        send_system_alert "critical" "Disk Almost Full" "Root filesystem: ${disk_usage}% full" "dialog-error"
    elif [[ $disk_usage -gt 85 ]]; then
        send_system_alert "warning" "Disk Getting Full" "Root filesystem: ${disk_usage}% full" "dialog-warning"
    fi
}

case "${1:-check}" in
    check)
        check_and_alert
        ;;
    test)
        send_system_alert "info" "System Monitor Test" "System monitoring is working correctly" "dialog-information"
        ;;
esac
