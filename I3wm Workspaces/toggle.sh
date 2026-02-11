#!/bin/bash
# Toggle i3 Workspaces overlay with auto-refresh
DIR="$(cd "$(dirname "$0")" && pwd)"
WINDOW_NAME="i3 Workspaces"
LOOP_PID="/tmp/i3_workspaces_loop.pid"
WID=$(xdotool search --name "$WINDOW_NAME" 2>/dev/null | head -1)

if [ -n "$WID" ]; then
    [ -f "$LOOP_PID" ] && kill "$(cat "$LOOP_PID")" 2>/dev/null && rm -f "$LOOP_PID"
    xdotool windowclose "$WID"
else
    "$DIR/generate.sh"

    # Background refresh loop (self-terminates if window closes)
    (while true; do
        sleep 2
        xdotool search --name "$WINDOW_NAME" >/dev/null 2>&1 || break
        "$DIR/generate.sh"
    done; rm -f "$LOOP_PID") &
    echo $! > "$LOOP_PID"

    google-chrome \
        --app="file://$DIR/workspaces.html" \
        --class=i3_workspaces \
        --user-data-dir=/tmp/i3_workspaces_chrome \
        --no-first-run \
        --disable-extensions \
        --disable-default-apps &

    for i in $(seq 1 20); do
        sleep 0.1
        WID=$(xdotool search --name "$WINDOW_NAME" 2>/dev/null | head -1)
        if [ -n "$WID" ]; then
            i3-msg "[id=$WID] floating enable, border none, fullscreen enable" >/dev/null 2>&1
            break
        fi
    done
fi
