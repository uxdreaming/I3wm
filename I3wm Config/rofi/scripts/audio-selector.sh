#!/bin/bash
# Audio device selector for rofi
# Hyper+p to toggle
# Press M to show/hide microphones

THEME="$HOME/.config/rofi/audio-theme.rasi"
CARD="alsa_card.pci-0000_00_1f.3"
SHOW_MICS="${SHOW_MICS:-0}"

get_active_sink_port() {
    # Get current profile to determine if HDMI or analog
    local profile=$(pactl list cards | grep -A 5 "Name: $CARD" | grep "Active Profile:" | cut -d: -f2 | xargs)
    if [[ "$profile" == *hdmi* ]]; then
        echo "hdmi-output-0"
    else
        pactl list sinks | grep "Active Port:" | head -1 | cut -d: -f2 | xargs
    fi
}

get_active_source_port() {
    pactl list sources | tail -20 | grep "Active Port:" | cut -d: -f2 | xargs 2>/dev/null
}

list_menu() {
    local active_sink_port=$(get_active_sink_port)

    # Output ports
    local ports=("analog-output-headphones:Headphones:A:1" "hdmi-output-0:HDMI:H:2" "analog-output-speaker:Laptop:L:3")

    for p in "${ports[@]}"; do
        IFS=: read -r port_name port_desc cat num <<< "$p"

        # Check availability for HDMI
        if [[ "$port_name" == "hdmi"* ]]; then
            pactl list cards | grep -A 200 "Name: $CARD" | grep -q "$port_name.*not available" && continue
        fi

        if [[ "$port_name" == "$active_sink_port" ]]; then
            echo "$num [$cat] ● $port_desc"
        else
            echo "$num [$cat]   $port_desc"
        fi
    done

    # Input ports (only if SHOW_MICS is enabled)
    if [[ "$SHOW_MICS" == "1" ]]; then
        local active_source_port=$(get_active_source_port)
        local inputs=("analog-input-internal-mic:Internal Mic:I:4" "analog-input-headphone-mic:Headset Mic:A:5")

        for p in "${inputs[@]}"; do
            IFS=: read -r port_name port_desc cat num <<< "$p"

            if [[ "$port_name" == "$active_source_port" ]]; then
                echo "$num [$cat] ● $port_desc"
            else
                echo "$num [$cat]   $port_desc"
            fi
        done
    fi
}

set_output() {
    local key="$1"

    case "$key" in
        1|A|*Headphones*)
            pactl set-card-profile "$CARD" "output:analog-stereo+input:analog-stereo"
            sleep 0.1
            sink=$(pactl list sinks short | grep analog | cut -f2)
            pactl set-default-sink "$sink"
            pactl set-sink-port "$sink" "analog-output-headphones"
            ;;
        2|H|*HDMI*)
            pactl set-card-profile "$CARD" "output:hdmi-stereo+input:analog-stereo"
            sleep 0.1
            sink=$(pactl list sinks short | grep hdmi | cut -f2)
            pactl set-default-sink "$sink"
            ;;
        3|L|*Laptop*)
            pactl set-card-profile "$CARD" "output:analog-stereo+input:analog-stereo"
            sleep 0.1
            sink=$(pactl list sinks short | grep analog | cut -f2)
            pactl set-default-sink "$sink"
            pactl set-sink-port "$sink" "analog-output-speaker"
            ;;
        *)
            return 1
            ;;
    esac

    # Move all playing streams
    pactl list sink-inputs short 2>/dev/null | while read -r id rest; do
        pactl move-sink-input "$id" "$(pactl get-default-sink)" 2>/dev/null
    done
}

set_input() {
    local key="$1"
    local port=""

    case "$key" in
        4|I|*Internal*)
            port="analog-input-internal-mic"
            ;;
        5|*Headset*)
            port="analog-input-headphone-mic"
            ;;
        *)
            return 1
            ;;
    esac

    source=$(pactl list sources short | grep -v monitor | grep analog | cut -f2)
    pactl set-default-source "$source"
    pactl set-source-port "$source" "$port"
}

# Direct mode: audio-selector.sh [1|2|3|A|H|L|4|5]
if [[ -n "$1" ]]; then
    case "$1" in
        1|2|3|A|H|L|a|h|l) set_output "$1" ;;
        4|5|I|i) set_input "$1" ;;
        *) echo "Usage: $0 [1|A=Headphones] [2|H=HDMI] [3|L=Laptop] [4|I=IntMic] [5=HeadsetMic]" ;;
    esac
    exit 0
fi

# Menu mode
menu=$(list_menu)

if [[ "$SHOW_MICS" == "1" ]]; then
    mesg="[M] Ocultar mics"
else
    mesg="[M] Mostrar mics"
fi

selected=$(echo "$menu" | rofi -dmenu -i -p " Audio" -mesg "$mesg" -theme "$THEME" -kb-custom-1 "m")
ret=$?

# M key pressed (custom-1 returns 10)
if [[ $ret -eq 10 ]]; then
    if [[ "$SHOW_MICS" == "1" ]]; then
        SHOW_MICS=0 exec "$0"
    else
        SHOW_MICS=1 exec "$0"
    fi
fi

[[ -z "$selected" ]] && exit 0

# Extract the number
key=$(echo "$selected" | grep -oE "^[0-9]" | head -1)

if [[ -z "$key" ]]; then
    key="$selected"
fi

# 1-3 are outputs, 4-5 are inputs
case "$key" in
    1|2|3) set_output "$key" ;;
    4|5) set_input "$key" ;;
    *) set_output "$key" ;;  # Fallback
esac
