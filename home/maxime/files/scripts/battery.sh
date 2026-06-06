#!/bin/bash

# Get the battery percentage
battery_percentage=$(cat /sys/class/power_supply/BAT0/capacity)

# Display the battery percentage
echo "Battery Percentage: $battery_percentage%"
