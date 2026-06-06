#!/usr/bin/env bash
# Navigate through Hyprland workspaces with next/prev and move/switch actions.

# Get arguments
direction=$1   # Expected: "next" or "prev"
action=$2      # Expected: "move" or "switch"

# Get current workspace ID
current_id=$(hyprctl activeworkspace -j | jq -r '.id')

# Calculate target workspace ID
if [ "$direction" = "next" ]; then
    target_id=$((current_id + 1))
else
    target_id=$((current_id - 1))
fi

# Check if target workspace exists
workspace_exists=$(hyprctl workspaces -j | jq -r ".[].id" | grep -q "^${target_id}$" && echo "yes" || echo "no")

# Construct the command
if [ "$action" = "move" ]; then
    cmd="movetoworkspace"
else
    cmd="workspace"
fi

# Execute the command
if [ "$workspace_exists" = "yes" ]; then
    hyprctl dispatch "$cmd" "$target_id"
else
    hyprctl dispatch "$cmd" "empty"
fi

