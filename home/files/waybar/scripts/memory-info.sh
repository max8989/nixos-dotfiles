#!/usr/bin/env bash
# Memory info script for waybar with detailed tooltip

get_memory_info() {
    # Get memory info from free
    local mem_info=$(free -h | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local available=$(echo "$mem_info" | awk '{print $7}')

    # Get percentage
    local percentage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')

    # Get swap info
    local swap_info=$(free -h | grep Swap)
    local swap_total=$(echo "$swap_info" | awk '{print $2}')
    local swap_used=$(echo "$swap_info" | awk '{print $3}')

    # Get top memory-consuming processes, grouped by command name
    local top_procs=$(ps aux --sort=-%mem | awk 'NR>1 {
        cmd = $11
        gsub(/.*\//, "", cmd)  # Remove path
        gsub(/^-/, "", cmd)    # Remove leading dash
        mem[cmd] += $4
    }
    END {
        for (cmd in mem) print mem[cmd], cmd
    }' | sort -rn | head -5 | awk '{printf "%-6.1f%%  %s\n", $1, $2}')

    # Build tooltip with better spacing
    local tooltip="Memory: ${used} / ${total} (${percentage}%)\\nAvailable: ${available}\\nSwap: ${swap_used} / ${swap_total}\\n\\nTop processes:\\n${top_procs}"

    # Escape for JSON
    tooltip=$(echo "$tooltip" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

    echo "{\"text\": \"MEM ${percentage}%\", \"tooltip\": \"${tooltip}\", \"class\": \"memory\", \"percentage\": ${percentage}}"
}

get_memory_info
