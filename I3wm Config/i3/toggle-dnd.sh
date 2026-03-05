#!/bin/bash
# Toggle Do Not Disturb (dunst pause)

dunstctl set-paused toggle

paused=$(dunstctl is-paused)

if [ "$paused" = "true" ]; then
    msg='<span size="xx-large">🔕  <b>Notifs</b> <span foreground="#d98a8a"><b>OFF</b></span></span>'
else
    msg='<span size="xx-large">🔔  <b>Notifs</b> <span foreground="#8ad9a0"><b>ON</b></span></span>'
fi

# Kill any previous popup
pkill -f "zenity.*DND" 2>/dev/null

zenity --info --text="$msg" --title="" --width=280 --timeout=2 --no-wrap --icon-name="" 2>/dev/null &
