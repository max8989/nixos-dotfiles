#!/usr/bin/env bash
# CPU info script for waybar with detailed tooltip

get_cpu_info() {
    # Get overall CPU usage
    local usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')

    # Get top CPU-consuming processes, grouped by command name
    local top_procs=$(ps aux --sort=-%cpu | awk 'NR>1 {
        cmd = $11
        gsub(/.*\//, "", cmd)  # Remove path
        gsub(/^-/, "", cmd)    # Remove leading dash
        cpu[cmd] += $3
    }
    END {
        for (cmd in cpu) print cpu[cmd], cmd
    }' | sort -rn | head -5 | awk '{printf "%-6.1f%%  %s\n", $1, $2}')

    # Get CPU frequency
    local freq=$(cat /proc/cpuinfo | grep "MHz" | head -1 | awk '{printf "%.1f GHz", $4/1000}')

    # Get load average
    local load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

    # Build tooltip with better spacing
    local tooltip="CPU Usage: ${usage}%\\nFrequency: ${freq}\\nLoad: ${load}\\n\\nTop processes:\\n${top_procs}"

    # Escape for JSON
    tooltip=$(echo "$tooltip" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

    echo "{\"text\": \"CPU ${usage}%\", \"tooltip\": \"${tooltip}\", \"class\": \"cpu\", \"percentage\": ${usage}}"
}

get_cpu_info
