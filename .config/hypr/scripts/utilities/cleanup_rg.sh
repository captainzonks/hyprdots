#!/usr/bin/env bash
# =============================================================================
# Runaway Ripgrep Cleanup
# =============================================================================
# Kills runaway ripgrep processes from VS Code that exceed 2-minute runtime
# Workaround for VS Code indexer bugs causing high CPU usage
#
# Dependencies: pgrep, ps, kill
# =============================================================================

# Find VS Code rg PIDs by full binary path
RG_PIDS=$(pgrep -f "/opt/visual-studio-code/resources/app/node_modules/@vscode/ripgrep/bin/rg")

if [ -z "$RG_PIDS" ]; then
    echo "No VS Code ripgrep processes found"
    echo "Current load:$(uptime | awk -F'load average:' '{print $2}')"
    exit 0
fi

# Check each PID's runtime
RUNAWAY_RG=""
for pid in $RG_PIDS; do
    # Get elapsed time for this PID
    etime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
    if [ -z "$etime" ]; then
        continue
    fi

    # Parse time (MM:SS or HH:MM:SS or DD-HH:MM:SS)
    if [[ "$etime" == *"-"* ]]; then
        # Has days (DD-HH:MM:SS)
        IFS='-:' read -ra time <<< "$etime"
        minutes=$(( 10#${time[0]} * 24 * 60 + 10#${time[1]} * 60 + 10#${time[2]} ))
    else
        # Split by colon
        IFS=':' read -ra time <<< "$etime"
        if [ ${#time[@]} -eq 3 ]; then
            # HH:MM:SS
            minutes=$(( 10#${time[0]} * 60 + 10#${time[1]} ))
        elif [ ${#time[@]} -eq 2 ]; then
            # MM:SS - force base 10 to avoid octal interpretation
            minutes=$((10#${time[0]}))
        else
            # Unknown format, skip
            continue
        fi
    fi

    # If running more than 2 minutes, add to kill list
    if [ "$minutes" -gt 2 ]; then
        RUNAWAY_RG="$RUNAWAY_RG $pid"
    fi
done

if [ -n "$RUNAWAY_RG" ]; then
    COUNT=$(echo "$RUNAWAY_RG" | wc -l)
    echo "Found $COUNT runaway ripgrep process(es), killing..."
    echo "$RUNAWAY_RG" | xargs kill -9 2>/dev/null
    echo "✓ Killed runaway rg processes"
else
    echo "No runaway rg processes found"
fi

# Show current system load
echo "Current load:$(uptime | awk -F'load average:' '{print $2}')"
