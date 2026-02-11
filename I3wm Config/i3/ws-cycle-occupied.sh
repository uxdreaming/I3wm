#!/bin/bash
# Cycle through workspaces that have at least one window
# Direction: "next" or "prev"

direction="${1:-next}"

# Get current focused workspace
current=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true) | .num')

# Get workspaces with windows (nodes > 0 or floating_nodes > 0)
occupied=$(i3-msg -t get_tree | jq -r '.. | objects | select(.type=="workspace" and .num >= 0) | select((.nodes | length) > 0 or (.floating_nodes | length) > 0) | .num' | sort -n)

# Convert to array
mapfile -t ws_array <<< "$occupied"

# Find current index
current_idx=-1
for i in "${!ws_array[@]}"; do
    if [[ "${ws_array[$i]}" == "$current" ]]; then
        current_idx=$i
        break
    fi
done

# If current not in occupied, find nearest
if [[ $current_idx -eq -1 ]]; then
    current_idx=0
fi

# Calculate next/prev index
count=${#ws_array[@]}

if [[ $count -le 1 ]]; then
    exit 0
fi

if [[ "$direction" == "next" ]]; then
    next_idx=$(( (current_idx + 1) % count ))
else
    next_idx=$(( (current_idx - 1 + count) % count ))
fi

# Switch to workspace
target="${ws_array[$next_idx]}"
if [[ -n "$target" ]]; then
    i3-msg "workspace number $target"
fi
