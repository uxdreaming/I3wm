#!/bin/bash
# Toggle i3 Workspaces overlay with auto-refresh
DIR="$(cd "$(dirname "$0")" && pwd)"
WINDOW_NAME="i3 Workspaces"
LOOP_PID="/tmp/i3_workspaces_loop.pid"
OVERLAY_FILE="/tmp/i3_active_overlay"

# Check if our own window is open → toggle off
WID=$(xdotool search --name "$WINDOW_NAME" 2>/dev/null | head -1)
if [ -n "$WID" ]; then
    [ -f "$LOOP_PID" ] && kill "$(cat "$LOOP_PID")" 2>/dev/null && rm -f "$LOOP_PID"
    xdotool windowclose "$WID"
    rm -f "$OVERLAY_FILE"
    exit 0
fi

# Close any other active overlay
if [ -f "$OVERLAY_FILE" ]; then
    ACTIVE=$(cat "$OVERLAY_FILE")
    if [ -n "$ACTIVE" ]; then
        ACTIVE_WID=$(xdotool search --name "$ACTIVE" 2>/dev/null | head -1)
        [ -n "$ACTIVE_WID" ] && xdotool windowclose "$ACTIVE_WID"
    fi
    rm -f "$OVERLAY_FILE"
fi

# Open our overlay
echo "$WINDOW_NAME" > "$OVERLAY_FILE"
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

# Wait for window and force fullscreen
for i in $(seq 1 20); do
    sleep 0.1
    WID=$(xdotool search --name "$WINDOW_NAME" 2>/dev/null | head -1)
    if [ -n "$WID" ]; then
        i3-msg "[id=$WID] floating enable, border none, fullscreen enable" >/dev/null 2>&1
        break
    fi
done
