#!/usr/bin/env bash
# Obsidian Reminder module for waybar
# Parses reminders from markdown files and outputs JSON for waybar display

REMINDERS_DIR="$HOME/Documents/notes/Reminders"

get_reminders() {
    local now=$(date +%s)
    local today_start=$(date -d "today 00:00" +%s)
    local today_end=$(date -d "today 23:59:59" +%s)
    local week_end=$(date -d "+7 days 23:59:59" +%s)

    local overdue=0
    local today=0
    local upcoming=0

    local overdue_list=""
    local today_list=""
    local upcoming_list=""

    # Check if reminders directory exists
    if [[ ! -d "$REMINDERS_DIR" ]]; then
        echo '{"text": "󰂚", "tooltip": "Reminders folder not found", "class": "none"}'
        return
    fi

    # Find all .md files and parse unchecked reminders
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        while IFS= read -r line; do
            # Match: - [ ] Task title (@YYYY-MM-DD HH:mm)
            if [[ "$line" =~ ^-\ \[\ \]\ (.+)\ \(@([0-9]{4}-[0-9]{2}-[0-9]{2})\ ([0-9]{2}:[0-9]{2})\)$ ]]; then
                local task="${BASH_REMATCH[1]}"
                local date="${BASH_REMATCH[2]}"
                local time="${BASH_REMATCH[3]}"
                local reminder_ts=$(date -d "$date $time" +%s 2>/dev/null)

                if [[ -n "$reminder_ts" ]]; then
                    if [[ $reminder_ts -lt $now ]]; then
                        ((overdue++))
                        overdue_list+="  • $task ($time)\\n"
                    elif [[ $reminder_ts -ge $today_start && $reminder_ts -le $today_end ]]; then
                        ((today++))
                        today_list+="  • $task ($time)\\n"
                    elif [[ $reminder_ts -le $week_end ]]; then
                        ((upcoming++))
                        local day_name=$(date -d "$date" +%a)
                        upcoming_list+="  • $task ($day_name $time)\\n"
                    fi
                fi
            fi
        done < "$file"
    done < <(find "$REMINDERS_DIR" -name "*.md" -type f 2>/dev/null)

    # Build tooltip
    local tooltip=""
    local total=$((overdue + today + upcoming))

    if [[ $total -eq 0 ]]; then
        tooltip="No upcoming reminders"
    else
        if [[ $overdue -gt 0 ]]; then
            tooltip+="⚠ OVERDUE ($overdue)\\n${overdue_list}"
        fi
        if [[ $today -gt 0 ]]; then
            [[ -n "$tooltip" ]] && tooltip+="\\n"
            tooltip+="📅 TODAY ($today)\\n${today_list}"
        fi
        if [[ $upcoming -gt 0 ]]; then
            [[ -n "$tooltip" ]] && tooltip+="\\n"
            tooltip+="📆 UPCOMING ($upcoming)\\n${upcoming_list}"
        fi
    fi

    # Remove trailing newlines
    tooltip="${tooltip%\\n}"

    # Escape quotes for JSON
    tooltip="${tooltip//\"/\\\"}"

    # Determine class based on priority
    local class="none"
    [[ $upcoming -gt 0 ]] && class="upcoming"
    [[ $today -gt 0 ]] && class="today"
    [[ $overdue -gt 0 ]] && class="overdue"

    # Build display text
    local text=""
    if [[ $total -eq 0 ]]; then
        text="󰂚"
    elif [[ $overdue -gt 0 ]]; then
        text="󰂞 $overdue"
    else
        text="󰂜 $total"
    fi

    echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
}

get_reminders
