#!/bin/bash
# Generate i3 Dashboard HTML with current system data
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/dashboard.html"
TMP="$OUT.tmp"

# ── Gather data ──────────────────────────────────────────

# Workspaces (JSON array from i3)
WS_JSON=$(i3-msg -t get_workspaces 2>/dev/null || echo '[]')

# Build all workspace HTML in a single jq call
eval $(echo "$WS_JSON" | jq -r '
  [.[] | {num, focused, urgent}] as $ws |
  "WS_OCCUPIED=\"" + ([.[] | .num | tostring] | join(" ")) + "\"",
  "WS_FOCUSED=\"" + ([.[] | select(.focused) | .num | tostring] | join(" ")) + "\"",
  "WS_URGENT=\"" + ([.[] | select(.urgent) | .num | tostring] | join(" ")) + "\""
' 2>/dev/null)

build_ws() {
  local start=$1 end=$2 color=$3 html=""
  for i in $(seq $start $end); do
    local cls="ws"
    [[ " $WS_OCCUPIED " == *" $i "* ]] && cls="$cls ws-occupied"
    [[ " $WS_FOCUSED " == *" $i "* ]] && cls="$cls ws-focused"
    [[ " $WS_URGENT " == *" $i "* ]] && cls="$cls ws-urgent"
    html="$html<div class=\"$cls\" data-color=\"$color\">$i</div>"
  done
  echo "$html"
}

WS_SUPER=$(build_ws 0 9 "blue")
WS_HYPER=$(build_ws 10 19 "purple")

# Battery
BAT_CAP=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
BAT_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
case "$BAT_STATUS" in
  Charging)    BAT_LABEL="Charging"; BAT_CLASS="charging" ;;
  Discharging) BAT_LABEL="Discharging"; BAT_CLASS="" ;;
  Full)        BAT_LABEL="Full"; BAT_CLASS="" ;;
  *)           BAT_LABEL="$BAT_STATUS"; BAT_CLASS="" ;;
esac

# Memory
MEM_DATA=$(free -m | awk '/Mem:/ {printf "%d %d %.0f", $3, $2, $3/$2*100}')
MEM_USED=$(echo "$MEM_DATA" | awk '{print $1}')
MEM_TOTAL=$(echo "$MEM_DATA" | awk '{print $2}')
MEM_PCT=$(echo "$MEM_DATA" | awk '{print $3}')
MEM_DISP=$(LC_NUMERIC=C awk -v u="$MEM_USED" -v t="$MEM_TOTAL" 'BEGIN {printf "%.1fG / %.0fG", u/1024, t/1024}')

# CPU (from load average, instant)
CPU_CORES=$(nproc)
LOAD_1=$(awk '{print $1}' /proc/loadavg)
CPU_PCT=$(awk -v load="$LOAD_1" -v cores="$CPU_CORES" 'BEGIN {pct=int(load/cores*100); if(pct>100) pct=100; print pct}')

# Disk
DISK_DATA=$(df -h / | awk 'NR==2 {print $3, $2, $5}')
DISK_USED=$(echo "$DISK_DATA" | awk '{print $1}')
DISK_TOTAL=$(echo "$DISK_DATA" | awk '{print $2}')
DISK_PCT=$(echo "$DISK_DATA" | awk '{gsub(/%/,"",$3); print $3}')

# Network
WIFI_SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1)
[ -z "$WIFI_SSID" ] && WIFI_SSID="Disconnected"
IP_ADDR=$(ip -4 addr show wlo1 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]}' | head -1)
[ -z "$IP_ADDR" ] && IP_ADDR=$(ip -4 addr show 2>/dev/null | grep 'inet ' | grep -v '127\.' | head -1 | awk '{split($2,a,"/"); print a[1]}')
[ -z "$IP_ADDR" ] && IP_ADDR="N/A"

# Temperature
CPU_TEMP=$(sensors 2>/dev/null | awk '/Package id 0|Tctl|Core 0/ {gsub(/[+°C]/,"",$NF); print int($NF); exit}')
[ -z "$CPU_TEMP" ] && CPU_TEMP="0"

# Date/Time (conky format, single line)
DATE_LINE=$(LC_TIME=es_ES.UTF-8 date '+%a %d de %b %Y W%V · %I:%M %p')

# Load average
LOAD_AVG=$(awk '{print $1}' /proc/loadavg)
LOAD_5=$(awk '{print $2}' /proc/loadavg)
PROCS=$(awk '{split($4,a,"/"); print a[2]}' /proc/loadavg)

# Uptime (compact)
UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime)
UPTIME_D=$((UPTIME_SEC / 86400))
UPTIME_H=$(((UPTIME_SEC % 86400) / 3600))
UPTIME_M=$(((UPTIME_SEC % 3600) / 60))
if [ "$UPTIME_D" -gt 0 ]; then
  UPTIME="${UPTIME_D}d ${UPTIME_H}h"
elif [ "$UPTIME_H" -gt 0 ]; then
  UPTIME="${UPTIME_H}h ${UPTIME_M}m"
else
  UPTIME="${UPTIME_M}m"
fi

# ── Ring gauge calculations ──────────────────────────────
CIRC="251.327"
ring_offset() {
  LC_NUMERIC=C awk -v pct="$1" -v c="$CIRC" 'BEGIN {printf "%.2f", c * (1 - pct/100)}'
}
BAT_OFFSET=$(ring_offset "$BAT_CAP")
MEM_OFFSET=$(ring_offset "$MEM_PCT")
CPU_OFFSET=$(ring_offset "$CPU_PCT")
DISK_OFFSET=$(ring_offset "$DISK_PCT")

# ── Color logic ──────────────────────────────────────────
bar_color() {
  local pct=$1 invert=$2
  if [ "$invert" = "1" ]; then
    if [ "$pct" -lt 40 ]; then echo "#34d399"
    elif [ "$pct" -lt 70 ]; then echo "#fbbf24"
    else echo "#f87171"
    fi
  else
    if [ "$pct" -lt 50 ]; then echo "#34d399"
    elif [ "$pct" -lt 80 ]; then echo "#fbbf24"
    else echo "#f87171"
    fi
  fi
}

BAT_COLOR=$(bar_color $((100 - BAT_CAP)) 0)
MEM_COLOR=$(bar_color "$MEM_PCT" 0)
CPU_COLOR=$(bar_color "$CPU_PCT" 1)
DISK_COLOR=$(bar_color "$DISK_PCT" 0)

# Temperature color
if [ "$CPU_TEMP" -lt 60 ]; then TEMP_COLOR="#34d399"
elif [ "$CPU_TEMP" -lt 80 ]; then TEMP_COLOR="#fbbf24"
else TEMP_COLOR="#f87171"
fi

# WiFi color
[ "$WIFI_SSID" = "Disconnected" ] && WIFI_COLOR="#f87171" || WIFI_COLOR="#34d399"

# Load color
LOAD_PCT=$(awk -v l="$LOAD_1" -v c="$CPU_CORES" 'BEGIN {print int(l/c*100)}')
if [ "$LOAD_PCT" -lt 50 ]; then LOAD_COLOR="#34d399"
elif [ "$LOAD_PCT" -lt 80 ]; then LOAD_COLOR="#fbbf24"
else LOAD_COLOR="#f87171"
fi

# Value highlight styles
TEMP_VAL_STYLE=""
[ "$CPU_TEMP" -ge 80 ] && TEMP_VAL_STYLE="color: #f87171"
[ "$CPU_TEMP" -ge 60 ] && [ "$CPU_TEMP" -lt 80 ] && TEMP_VAL_STYLE="color: #fbbf24"

LOAD_VAL_STYLE=""
[ "$LOAD_PCT" -ge 80 ] && LOAD_VAL_STYLE="color: #f87171"
[ "$LOAD_PCT" -ge 50 ] && [ "$LOAD_PCT" -lt 80 ] && LOAD_VAL_STYLE="color: #fbbf24"

# ── Generate HTML ────────────────────────────────────────

cat > "$TMP" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>i3 Dashboard</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  ::-webkit-scrollbar { display: none; }
  * { scrollbar-width: none; }

  body {
    background: #101010;
    color: #d4d4d4;
    font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
    height: 100vh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
    user-select: none;
  }

  header {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 32px 10px;
    border-bottom: 1px solid #1f1f1f;
  }

  header h1 { font-size: 20px; font-weight: 700; color: #e5e5e5; }

  .hint {
    font-size: 14px; color: #555;
    display: flex; align-items: center; gap: 6px;
  }
  .hint kbd {
    display: inline-block; padding: 2px 8px;
    background: linear-gradient(180deg, #3a3a3a, #2a2a2a);
    border: 1px solid #444; border-bottom: 2px solid #1a1a1a;
    border-radius: 4px; font-family: monospace; font-size: 13px; color: #aaa;
  }

  .content {
    flex: 1; width: 100%; max-width: 960px;
    display: flex; flex-direction: column;
    justify-content: center; gap: 20px;
    padding: 16px 32px;
  }

  /* ── Workspaces ── */
  .ws-section { text-align: center; }

  .ws-label {
    font-size: 13px; font-weight: 600; text-transform: uppercase;
    letter-spacing: 1.5px; margin-bottom: 8px;
  }
  .ws-label.blue { color: #60a5fa; }
  .ws-label.purple { color: #a78bfa; }

  .ws-row {
    display: flex; justify-content: center; gap: 8px;
  }

  .ws {
    width: 52px; height: 40px;
    display: flex; align-items: center; justify-content: center;
    border-radius: 8px;
    font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 14px; font-weight: 500;
    background: #1a1a1a; border: 1px solid #2a2a2a;
    color: #444; transition: all 0.2s;
  }

  .ws-occupied[data-color="blue"] {
    background: linear-gradient(180deg, #1e3a6e, #162d55);
    border-color: #3b6eb8; color: #a8ccf0;
  }
  .ws-occupied[data-color="purple"] {
    background: linear-gradient(180deg, #4a2a80, #3a1e68);
    border-color: #7a52c0; color: #c4aaf0;
  }

  .ws-focused {
    box-shadow: 0 0 0 2px #60a5fa, 0 0 12px rgba(96,165,250,0.3);
    transform: scale(1.08);
  }
  .ws-focused[data-color="purple"] {
    box-shadow: 0 0 0 2px #a78bfa, 0 0 12px rgba(167,139,250,0.3);
  }

  .ws-urgent {
    background: linear-gradient(180deg, #7f1d1d, #5c1414) !important;
    border-color: #dc2626 !important; color: #fca5a5 !important;
    animation: pulse 1.5s infinite;
  }

  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.7; }
  }

  /* ── Widgets Grid ── */
  .widgets {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
  }

  /* ── Ring Gauge Widgets ── */
  .widget-ring {
    background: #1a1a1a;
    border: 1px solid #252525;
    border-radius: 12px;
    padding: 14px 14px 12px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }

  .widget-ring .widget-title {
    font-size: 11px; font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    color: #555;
  }

  .ring-svg { display: block; }

  .ring-bg {
    fill: none;
    stroke: #252525;
    stroke-width: 6;
  }

  .ring-fg {
    fill: none;
    stroke-width: 6;
    stroke-linecap: round;
  }

  .ring-text {
    font-family: 'Inter', system-ui, sans-serif;
    font-weight: 700;
    fill: #e5e5e5;
  }

  .widget-ring .widget-sub {
    font-size: 12px;
    color: #555;
  }

  /* Charging animation */
  @keyframes charge-pulse {
    0%, 100% { opacity: 0.6; }
    50% { opacity: 1; }
  }

  .charging .ring-fg {
    animation: charge-pulse 2s ease-in-out infinite;
  }

  .charging .widget-sub {
    color: #34d399;
  }

  /* ── Info Widgets ── */
  .widget-info {
    background: #1a1a1a;
    border: 1px solid #252525;
    border-left: 3px solid var(--accent);
    border-radius: 12px;
    padding: 14px 14px 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .widget-info .widget-header {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .widget-info .widget-icon {
    width: 16px; height: 16px;
    flex-shrink: 0;
  }

  .widget-info .widget-title {
    font-size: 11px; font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 1.2px;
    color: #555;
  }

  .widget-info .widget-value {
    font-size: 24px; font-weight: 700;
    color: #e5e5e5;
    line-height: 1.2;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .widget-info .widget-sub {
    font-size: 12px;
    color: #444;
  }

  /* ── DateTime ── */
  .datetime {
    text-align: center; padding: 4px 0;
  }

  .time {
    font-size: 28px; font-weight: 700; color: #e5e5e5;
    letter-spacing: 1px; line-height: 1;
    text-transform: capitalize;
  }

  footer {
    width: 100%; text-align: center; padding: 6px;
    border-top: 1px solid #1a1a1a;
    font-size: 12px; color: #333; letter-spacing: 1px;
  }
</style>
</head>
<body>

<header>
  <h1>i3 Dashboard</h1>
  <span class="hint">Press <kbd>F2</kbd> to close</span>
</header>

<div class="content">
HTMLHEAD

# Workspaces section (unchanged)
cat >> "$TMP" << WSSECTION
  <div class="ws-section">
    <div class="ws-label blue">Super Workspaces</div>
    <div class="ws-row">$WS_SUPER</div>
  </div>

  <div class="ws-section" style="margin-bottom: 12px;">
    <div class="ws-label purple">Hyper Workspaces</div>
    <div class="ws-row">$WS_HYPER</div>
  </div>
WSSECTION

# Widgets (ring gauges + info cards)
cat >> "$TMP" << WIDGETS
  <div class="widgets">
    <div class="widget-ring $BAT_CLASS">
      <div class="widget-title">Battery</div>
      <svg class="ring-svg" viewBox="0 0 100 100" width="88" height="88">
        <circle class="ring-bg" cx="50" cy="50" r="40"/>
        <circle class="ring-fg" cx="50" cy="50" r="40"
          stroke="$BAT_COLOR" stroke-dasharray="$CIRC" stroke-dashoffset="$BAT_OFFSET"
          transform="rotate(-90 50 50)"/>
        <text class="ring-text" x="50" y="50" text-anchor="middle" dominant-baseline="central" font-size="22">${BAT_CAP}%</text>
      </svg>
      <div class="widget-sub">$BAT_LABEL</div>
    </div>

    <div class="widget-ring">
      <div class="widget-title">Memory</div>
      <svg class="ring-svg" viewBox="0 0 100 100" width="88" height="88">
        <circle class="ring-bg" cx="50" cy="50" r="40"/>
        <circle class="ring-fg" cx="50" cy="50" r="40"
          stroke="$MEM_COLOR" stroke-dasharray="$CIRC" stroke-dashoffset="$MEM_OFFSET"
          transform="rotate(-90 50 50)"/>
        <text class="ring-text" x="50" y="50" text-anchor="middle" dominant-baseline="central" font-size="22">${MEM_PCT}%</text>
      </svg>
      <div class="widget-sub">$MEM_DISP</div>
    </div>

    <div class="widget-ring">
      <div class="widget-title">CPU</div>
      <svg class="ring-svg" viewBox="0 0 100 100" width="88" height="88">
        <circle class="ring-bg" cx="50" cy="50" r="40"/>
        <circle class="ring-fg" cx="50" cy="50" r="40"
          stroke="$CPU_COLOR" stroke-dasharray="$CIRC" stroke-dashoffset="$CPU_OFFSET"
          transform="rotate(-90 50 50)"/>
        <text class="ring-text" x="50" y="50" text-anchor="middle" dominant-baseline="central" font-size="22">${CPU_PCT}%</text>
      </svg>
      <div class="widget-sub">${CPU_CORES} cores</div>
    </div>

    <div class="widget-ring">
      <div class="widget-title">Disk</div>
      <svg class="ring-svg" viewBox="0 0 100 100" width="88" height="88">
        <circle class="ring-bg" cx="50" cy="50" r="40"/>
        <circle class="ring-fg" cx="50" cy="50" r="40"
          stroke="$DISK_COLOR" stroke-dasharray="$CIRC" stroke-dashoffset="$DISK_OFFSET"
          transform="rotate(-90 50 50)"/>
        <text class="ring-text" x="50" y="50" text-anchor="middle" dominant-baseline="central" font-size="22">${DISK_PCT}%</text>
      </svg>
      <div class="widget-sub">${DISK_USED} / ${DISK_TOTAL}</div>
    </div>

    <div class="widget-info" style="--accent: $WIFI_COLOR">
      <div class="widget-header">
        <svg class="widget-icon" viewBox="0 0 24 24" fill="none" stroke="$WIFI_COLOR" stroke-width="2" stroke-linecap="round">
          <path d="M5 12.55a11 11 0 0114.08 0"/>
          <path d="M1.42 9a16 16 0 0121.16 0"/>
          <path d="M8.53 16.11a6 6 0 016.95 0"/>
          <circle cx="12" cy="20" r="1" fill="$WIFI_COLOR" stroke="none"/>
        </svg>
        <span class="widget-title">WiFi</span>
      </div>
      <div class="widget-value">$WIFI_SSID</div>
      <div class="widget-sub">$IP_ADDR</div>
    </div>

    <div class="widget-info" style="--accent: $TEMP_COLOR">
      <div class="widget-header">
        <svg class="widget-icon" viewBox="0 0 24 24" fill="none" stroke="$TEMP_COLOR" stroke-width="2" stroke-linecap="round">
          <path d="M14 14.76V3.5a2.5 2.5 0 00-5 0v11.26a4.5 4.5 0 105 0z"/>
        </svg>
        <span class="widget-title">Temperature</span>
      </div>
      <div class="widget-value" style="$TEMP_VAL_STYLE">${CPU_TEMP}°C</div>
      <div class="widget-sub">CPU Package</div>
    </div>

    <div class="widget-info" style="--accent: #60a5fa">
      <div class="widget-header">
        <svg class="widget-icon" viewBox="0 0 24 24" fill="none" stroke="#60a5fa" stroke-width="2" stroke-linecap="round">
          <circle cx="12" cy="12" r="10"/>
          <path d="M12 6v6l4 2"/>
        </svg>
        <span class="widget-title">Uptime</span>
      </div>
      <div class="widget-value">$UPTIME</div>
      <div class="widget-sub">since boot</div>
    </div>

    <div class="widget-info" style="--accent: $LOAD_COLOR">
      <div class="widget-header">
        <svg class="widget-icon" viewBox="0 0 24 24" fill="none" stroke="$LOAD_COLOR" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
        </svg>
        <span class="widget-title">Load</span>
      </div>
      <div class="widget-value" style="$LOAD_VAL_STYLE">$LOAD_AVG / $LOAD_5</div>
      <div class="widget-sub">$PROCS processes</div>
    </div>
  </div>
WIDGETS

# DateTime, footer, and auto-refresh
cat >> "$TMP" << HTMLFOOT

  <div class="datetime">
    <div class="time">$DATE_LINE</div>
  </div>

</div>

<footer>i3wm dashboard</footer>

<script>setTimeout(function(){location.reload()},3000);</script>
</body>
</html>
HTMLFOOT

# Atomic move
mv "$TMP" "$OUT"
