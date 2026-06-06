#!/usr/bin/env bash
# Interactive popup for completing reminders using yad

REMINDERS_DIR="$HOME/Documents/notes/Reminders"

# Kill existing popup if running
pkill -f "yad.*Reminders" 2>/dev/null

build_reminder_list() {
    local now=$(date +%s)
    local today_start=$(date -d "today 00:00" +%s)
    local today_end=$(date -d "today 23:59:59" +%s)
    local week_end=$(date -d "+7 days 23:59:59" +%s)

    # Check if reminders directory exists
    if [[ ! -d "$REMINDERS_DIR" ]]; then
        return
    fi

    # Temporary file to collect and sort items
    local tmp_file=$(mktemp)

    # Find all .md files and parse unchecked reminders
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local filename=$(basename "$file" .md)
        local lineno=0
        while IFS= read -r line; do
            ((lineno++))
            # Match: - [ ] Task title (@YYYY-MM-DD HH:mm)
            if [[ "$line" =~ ^-\ \[\ \]\ (.+)\ \(@([0-9]{4}-[0-9]{2}-[0-9]{2})\ ([0-9]{2}:[0-9]{2})\)$ ]]; then
                local task="${BASH_REMATCH[1]}"
                local date="${BASH_REMATCH[2]}"
                local time="${BASH_REMATCH[3]}"
                local reminder_ts=$(date -d "$date $time" +%s 2>/dev/null)

                if [[ -n "$reminder_ts" ]]; then
                    local category=""
                    local sort_key=""

                    if [[ $reminder_ts -lt $now ]]; then
                        category="OVERDUE"
                        sort_key="0"
                    elif [[ $reminder_ts -ge $today_start && $reminder_ts -le $today_end ]]; then
                        category="TODAY"
                        sort_key="1"
                    elif [[ $reminder_ts -le $week_end ]]; then
                        category=$(date -d "$date" +%A)
                        # Sort by day of week (2-8)
                        sort_key=$(($(date -d "$date" +%u) + 1))
                    else
                        continue
                    fi

                    # Tab-separated for sorting: sort_key, filename, then the display fields
                    # Order: Done | Ref | Category | Time | File | Task
                    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
                        "$sort_key" "$filename" "FALSE" "${file}:${lineno}" "$category" "$time" "$filename" "$task" >> "$tmp_file"
                fi
            fi
        done < "$file"
    done < <(find "$REMINDERS_DIR" -name "*.md" -type f 2>/dev/null)

    # Sort by category (sort_key) then by filename, output as newline-separated fields for yad
    if [[ -s "$tmp_file" ]]; then
        sort -t$'\t' -k1,1n -k2,2 "$tmp_file" | while IFS=$'\t' read -r _ _ done_col ref cat time fname task; do
            printf "%s\n%s\n%s\n%s\n%s\n%s\n" "$done_col" "$ref" "$cat" "$time" "$fname" "$task"
        done
    fi

    rm -f "$tmp_file"
}

complete_reminders() {
    local selections="$1"

    # Process each selected item
    while IFS='|' read -r file_line; do
        [[ -z "$file_line" ]] && continue

        local file="${file_line%:*}"
        local lineno="${file_line#*:}"

        # Replace "- [ ]" with "- [x]" on the specific line
        if [[ -f "$file" && -n "$lineno" ]]; then
            sed -i "${lineno}s/- \[ \]/- [x]/" "$file"
        fi

    done <<< "$selections"
}

# Build list
items=$(build_reminder_list)

if [[ -z "$items" ]]; then
    yad --info \
        --title="Reminders" \
        --text="No reminders in the next 7 days" \
        --button="OK:0" \
        --width=300 \
        --center \
        --on-top
    exit 0
fi

# Display checklist dialog
# Columns: Done | Ref (hidden) | Category | Time | File | Task
result=$(echo "$items" | yad --list \
    --title="Reminders" \
    --checklist \
    --column="Done" \
    --column="Ref:HD" \
    --column="Category" \
    --column="Time" \
    --column="File" \
    --column="Task" \
    --print-column=2 \
    --separator="|" \
    --width=700 \
    --height=400 \
    --center \
    --on-top \
    --button="Mark Complete:0" \
    --button="Cancel:1")

exit_code=$?

if [[ $exit_code -eq 0 && -n "$result" ]]; then
    # Remove trailing separator
    result="${result%|}"
    complete_reminders "$result"
fi
