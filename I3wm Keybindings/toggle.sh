#!/bin/bash
# Toggle keybindings HUD overlay
DIR="$(cd "$(dirname "$0")" && pwd)"
WINDOW_NAME="i3 Keybindings HUD"
WID=$(xdotool search --name "$WINDOW_NAME" 2>/dev/null | head -1)

if [ -n "$WID" ]; then
    xdotool windowclose "$WID"
else
    google-chrome \
        --app="file://$DIR/keybindings.html" \
        --class=keybinds_hud \
        --user-data-dir=/tmp/keybinds_hud_chrome \
        --no-first-run \
        --disable-extensions \
        --disable-default-apps &

    # Wait for window and force fullscreen
    for i in $(seq 1 20); do
        sleep 0.1
        WID=$(xdotool search --name "$WINDOW_NAME" 2>/dev/null | head -1)
        if [ -n "$WID" ]; then
            i3-msg "[id=$WID] floating enable, border none, fullscreen enable" >/dev/null 2>&1
            break
        fi
    done
fi
