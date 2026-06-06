#!/usr/bin/env bash
# Reminder notification daemon
# Sends cascading notifications at 2h, 1h, 30m, 15m, 5m before reminders

REMINDERS_DIR="$HOME/Documents/notes/Reminders"
CACHE_DIR="$HOME/.cache/waybar-reminders"
STATE_FILE="$CACHE_DIR/notified.json"

# Notification intervals in minutes
INTERVALS=(120 60 30 15 5)

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"
[[ ! -f "$STATE_FILE" ]] && echo '{}' > "$STATE_FILE"

send_notification() {
    local task="$1"
    local minutes="$2"
    local urgency="normal"

    # Critical urgency for 15min and 5min
    [[ $minutes -le 15 ]] && urgency="critical"

    local time_text=""
    if [[ $minutes -ge 60 ]]; then
        local hours=$((minutes / 60))
        time_text="${hours}h"
    else
        time_text="${minutes}min"
    fi

    notify-send \
        -a "Obsidian Reminders" \
        -u "$urgency" \
        -i "appointment-soon" \
        "Reminder in ${time_text}" \
        "$task"
}

check_reminders() {
    local now=$(date +%s)

    # Check if reminders directory exists
    if [[ ! -d "$REMINDERS_DIR" ]]; then
        return
    fi

    # Read current state
    local state
    state=$(cat "$STATE_FILE" 2>/dev/null || echo '{}')

    local new_state="$state"
    local state_changed=false

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
                    local diff_seconds=$((reminder_ts - now))
                    local diff_minutes=$((diff_seconds / 60))

                    # Skip if already past
                    [[ $diff_minutes -lt 0 ]] && continue

                    # Create unique key for this reminder (sanitize task name)
                    local sanitized_task="${task// /_}"
                    sanitized_task="${sanitized_task//[^a-zA-Z0-9_-]/}"
                    local key="${date}_${time}_${sanitized_task}"

                    for interval in "${INTERVALS[@]}"; do
                        # Check if we're within a 2-minute window for this notification
                        # This allows the minute-based timer to catch notifications
                        if [[ $diff_minutes -ge $((interval - 1)) && $diff_minutes -le $((interval + 1)) ]]; then
                            local notify_key="${key}_${interval}"

                            # Check if already notified using jq
                            if ! echo "$state" | jq -e ".[\"$notify_key\"]" > /dev/null 2>&1; then
                                send_notification "$task" "$interval"
                                # Mark as notified
                                new_state=$(echo "$new_state" | jq ". + {\"$notify_key\": $now}")
                                state_changed=true
                            fi
                        fi
                    done
                fi
            fi
        done < "$file"
    done < <(find "$REMINDERS_DIR" -name "*.md" -type f 2>/dev/null)

    # Clean old entries (older than 24 hours)
    local cutoff=$((now - 86400))
    new_state=$(echo "$new_state" | jq "with_entries(select(.value > $cutoff))")

    # Save state if changed or cleaned
    echo "$new_state" > "$STATE_FILE"
}

check_reminders
