#!/bin/bash
# Toggle i3 Dashboard overlay with auto-refresh
DIR="$(cd "$(dirname "$0")" && pwd)"
WINDOW_NAME="i3 Dashboard"
LOOP_PID="/tmp/i3_dashboard_loop.pid"
WID=$(xdotool search --name "$WINDOW_NAME" 2>/dev/null | head -1)

if [ -n "$WID" ]; then
    # Kill refresh loop
    [ -f "$LOOP_PID" ] && kill "$(cat "$LOOP_PID")" 2>/dev/null && rm -f "$LOOP_PID"
    xdotool windowclose "$WID"
else
    "$DIR/generate.sh"

    # Start background refresh loop (self-terminates if window closes)
    (while true; do
        sleep 2
        xdotool search --name "$WINDOW_NAME" >/dev/null 2>&1 || break
        "$DIR/generate.sh"
    done; rm -f "$LOOP_PID") &
    echo $! > "$LOOP_PID"

    google-chrome \
        --app="file://$DIR/dashboard.html" \
        --class=i3_dashboard \
        --user-data-dir=/tmp/i3_dashboard_chrome \
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
