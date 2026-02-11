#!/bin/bash
# Cierra la ventana más reciente del workspace actual (LIFO)

STACK_FILE="$HOME/.cache/i3-window-stack.json"

# Obtener workspace actual
current_ws=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).name')

# Leer la ventana más reciente del stack (última del array)
if [ -f "$STACK_FILE" ]; then
    newest_window=$(jq -r ".[\"$current_ws\"] | if . then .[-1] else empty end" "$STACK_FILE")

    if [ -n "$newest_window" ] && [ "$newest_window" != "null" ]; then
        i3-msg "[con_id=$newest_window] kill"
    fi
fi
