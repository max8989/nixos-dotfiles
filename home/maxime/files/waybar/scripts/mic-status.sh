#!/usr/bin/env bash
# Microphone status script for waybar

get_mic_status() {
    local muted=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -c MUTED)
    local vol=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{print int($2 * 100)}')

    if [[ $muted -eq 1 ]] || [[ -z "$vol" ]]; then
        echo '{"text": "MIC OFF", "class": "muted", "tooltip": "Microphone muted"}'
    else
        echo "{\"text\": \"MIC ${vol}%\", \"class\": \"active\", \"tooltip\": \"Microphone at ${vol}%\"}"
    fi
}

get_mic_status
