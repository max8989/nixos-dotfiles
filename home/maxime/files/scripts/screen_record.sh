#!/bin/env bash

# Check if already recording and stop if so
pgrep -x "wf-recorder" && pkill -INT -x wf-recorder && notify-send "Screen Recording" "Finished Recording" -i video-display -t 5000 && exit 0

# Countdown notifications
notify-send "Screen Recording" "Recording in: 3" -i video-display -t 4000
sleep 1
notify-send "Screen Recording" "Recording in: 2" -i video-display -t 3000
sleep 1
notify-send "Screen Recording" "Recording in: 1" -i video-display -t 2000
sleep 1
notify-send "Screen Recording" "Recording..." -i video-display -t 1000
sleep 1

# Set date/time for filename
dateTime=$(date +%m-%d-%Y-%H-%M-%S)

# Get currently focused monitor
currentMonitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')

# Start recording with more explicit format settings
mkdir -p $HOME/Videos/ScreenRecordings
wf-recorder -o "$currentMonitor" --bframes max_b_frames -c h264_vaapi -d /dev/dri/renderD128 -f $HOME/Videos/ScreenRecordings/$dateTime.mp4 2>/dev/null
