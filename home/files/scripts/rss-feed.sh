#!/bin/bash
# RSS Feed Fetcher for Hyprlock with AI Summarization

set -euo pipefail

# Configuration
CONFIG_FILE="$HOME/.config/hypr/rss-config.sh"
CACHE_DIR="$HOME/.cache/hyprlock-rss"
CACHE_ITEMS="$CACHE_DIR/rss-items.txt"
CACHE_SUMMARY="$CACHE_DIR/rss-summary.txt"
CACHE_TIMESTAMP="$CACHE_DIR/last-fetch"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Source config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Default cache duration: 1 hour (3600 seconds)
RSS_CACHE_DURATION=${RSS_CACHE_DURATION:-3600}

# RSS Feed URLs
FEEDS=(
    "https://archlinux.org/feeds/news/"
    "https://github.com/hyprwm/Hyprland/releases.atom"
    "https://github.com/neovim/neovim/releases.atom"
)

FEED_NAMES=("Arch" "Hyprland" "Neovim")

# Create cache directory
mkdir -p "$CACHE_DIR"

# Function: Check if cache is valid
cache_valid() {
    if [[ ! -f "$CACHE_ITEMS" ]] || [[ ! -f "$CACHE_TIMESTAMP" ]]; then
        return 1
    fi

    local last_fetch
    last_fetch=$(cat "$CACHE_TIMESTAMP" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    local age=$((now - last_fetch))

    [[ $age -lt $RSS_CACHE_DURATION ]]
}

# Function: Fetch and parse single RSS feed
fetch_feed() {
    local url="$1"
    local name="$2"
    local items_count=4

    local xml
    xml=$(curl -s --max-time 10 "$url" 2>/dev/null) || {
        echo "[!] $name: Failed"
        return 1
    }

    # Parse based on feed type (RSS vs Atom)
    if echo "$xml" | grep -q '<rss'; then
        # RSS format (Arch Linux)
        echo "$xml" | xmllint --xpath '//item[position()<='$items_count']/title/text()' - 2>/dev/null | \
            while IFS= read -r line; do
                [[ -n "$line" ]] && echo "[$name] $line"
            done
    else
        # Atom format (GitHub)
        echo "$xml" | xmllint --xpath '//*[local-name()="entry"][position()<='$items_count']/*[local-name()="title"]/text()' - 2>/dev/null | \
            while IFS= read -r line; do
                [[ -n "$line" ]] && echo "[$name] $line"
            done
    fi
}

# Function: Get AI summary
get_summary() {
    local items="$1"

    if [[ -z "${OPENAI_API_KEY:-}" ]] || [[ "$OPENAI_API_KEY" == "sk-your-api-key-here" ]]; then
        echo "Configure API key in"
        echo "~/.config/hypr/rss-config.sh"
        return 0
    fi

    python3 "$SCRIPT_DIR/rss-summarize.py" "$items" 2>/dev/null || {
        echo "AI summary unavailable"
    }
}

# Function: Format items for display
format_items() {
    local items="$1"
    local max_width=85

    echo "$items" | head -10 | while IFS= read -r line; do
        if [[ ${#line} -gt $max_width ]]; then
            echo "${line:0:$((max_width - 3))}..."
        else
            echo "$line"
        fi
    done
}

# Function: Format summary for display
format_summary() {
    local summary="$1"
    echo "$summary" | fold -w 85 -s
}

# Function: Refresh cache
refresh_cache() {
    # Fetch all feeds
    local all_items=""
    for i in "${!FEEDS[@]}"; do
        local feed_items
        feed_items=$(fetch_feed "${FEEDS[$i]}" "${FEED_NAMES[$i]}" 2>/dev/null) || true
        if [[ -n "$feed_items" ]]; then
            if [[ -n "$all_items" ]]; then
                all_items+=$'\n'
            fi
            all_items+="$feed_items"
        fi
    done

    # Handle empty results
    if [[ -z "$all_items" ]]; then
        all_items="No updates available"
    fi

    # Get AI summary
    local summary
    summary=$(get_summary "$all_items")

    # Cache formatted output
    format_items "$all_items" > "$CACHE_ITEMS"
    format_summary "$summary" > "$CACHE_SUMMARY"
    date +%s > "$CACHE_TIMESTAMP"
}

# Main execution
main() {
    local mode="${1:-all}"

    # Refresh cache if needed
    if ! cache_valid; then
        refresh_cache
    fi

    # Output based on mode
    case "$mode" in
        items)
            cat "$CACHE_ITEMS" 2>/dev/null || echo "Loading..."
            ;;
        summary)
            cat "$CACHE_SUMMARY" 2>/dev/null || echo "Loading..."
            ;;
        *)
            echo "=== RSS Updates ==="
            cat "$CACHE_ITEMS" 2>/dev/null
            echo ""
            echo "=== AI Summary ==="
            cat "$CACHE_SUMMARY" 2>/dev/null
            ;;
    esac
}

main "$@"
