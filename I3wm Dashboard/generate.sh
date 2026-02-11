#!/bin/bash
# Generate i3 Dashboard HTML — workspace overview
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/dashboard.html"
TMP="$OUT.tmp"

# ── Gather data ──────────────────────────────────────────

# Workspaces (JSON array from i3)
WS_JSON=$(i3-msg -t get_workspaces 2>/dev/null || echo '[]')

eval $(echo "$WS_JSON" | jq -r '
  "WS_OCCUPIED=\"" + ([.[] | .num | tostring] | join(" ")) + "\"",
  "WS_FOCUSED=\"" + ([.[] | select(.focused) | .num | tostring] | join(" ")) + "\"",
  "WS_URGENT=\"" + ([.[] | select(.urgent) | .num | tostring] | join(" ")) + "\""
' 2>/dev/null)

# Window names per workspace (for tooltips)
TREE_JSON=$(i3-msg -t get_tree 2>/dev/null || echo '{}')

# Build workspace → window list mapping
declare -A WS_WINDOWS
while IFS='|' read -r wsnum wname; do
  [ -z "$wsnum" ] && continue
  if [ -n "${WS_WINDOWS[$wsnum]}" ]; then
    WS_WINDOWS[$wsnum]="${WS_WINDOWS[$wsnum]}&#10;$wname"
  else
    WS_WINDOWS[$wsnum]="$wname"
  fi
done < <(echo "$TREE_JSON" | jq -r '
  recurse(.nodes[]?, .floating_nodes[]?) |
  select(.type == "workspace") |
  .num as $n |
  recurse(.nodes[]?, .floating_nodes[]?) |
  select(.window != null and .name != null) |
  "\($n)|\(.name | gsub("[\"<>]"; "") | .[0:40])"
' 2>/dev/null)

# Count windows per workspace
declare -A WS_COUNT
while IFS='|' read -r wsnum wname; do
  [ -z "$wsnum" ] && continue
  WS_COUNT[$wsnum]=$(( ${WS_COUNT[$wsnum]:-0} + 1 ))
done < <(echo "$TREE_JSON" | jq -r '
  recurse(.nodes[]?, .floating_nodes[]?) |
  select(.type == "workspace") |
  .num as $n |
  recurse(.nodes[]?, .floating_nodes[]?) |
  select(.window != null and .name != null) |
  "\($n)|\(.name)"
' 2>/dev/null)

build_ws() {
  local start=$1 end=$2 color=$3 html=""
  for i in $(seq $start $end); do
    local cls="ws"
    local count="${WS_COUNT[$i]:-0}"
    local tooltip="${WS_WINDOWS[$i]:-}"
    [[ " $WS_OCCUPIED " == *" $i "* ]] && cls="$cls ws-occupied"
    [[ " $WS_FOCUSED " == *" $i "* ]] && cls="$cls ws-focused"
    [[ " $WS_URGENT " == *" $i "* ]] && cls="$cls ws-urgent"
    html="$html<div class=\"$cls\" data-color=\"$color\" title=\"$tooltip\">"
    html="$html<span class=\"ws-num\">$i</span>"
    if [ "$count" -gt 0 ]; then
      html="$html<span class=\"ws-count\">$count</span>"
    fi
    html="$html</div>"
  done
  echo "$html"
}

WS_SUPER=$(build_ws 0 9 "blue")
WS_HYPER=$(build_ws 10 19 "purple")

# Date/Time
DATE_LINE=$(LC_TIME=en_US.UTF-8 date '+%a %d %b %Y · %I:%M %p')

# ── Generate HTML ────────────────────────────────────────

cat > "$TMP" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>i3 Dashboard</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  ::-webkit-scrollbar { display: none; }

  body {
    background: #101010;
    color: #d4d4d4;
    font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
    height: 100vh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    user-select: none;
  }

  header {
    position: absolute;
    top: 0; left: 0; right: 0;
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
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 48px;
  }

  /* ── Workspaces ── */
  .ws-section { text-align: center; }

  .ws-label {
    font-size: 14px; font-weight: 600; text-transform: uppercase;
    letter-spacing: 2px; margin-bottom: 14px;
  }
  .ws-label.blue { color: #60a5fa; }
  .ws-label.purple { color: #a78bfa; }

  .ws-row {
    display: flex; justify-content: center; gap: 12px;
  }

  .ws {
    width: 80px; height: 64px;
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    gap: 4px;
    border-radius: 10px;
    font-family: 'SF Mono', 'Fira Code', monospace;
    background: #1a1a1a; border: 1px solid #2a2a2a;
    color: #3a3a3a;
    transition: all 0.2s;
    position: relative;
  }

  .ws-num {
    font-size: 20px; font-weight: 600;
    line-height: 1;
  }

  .ws-count {
    font-size: 10px; font-weight: 500;
    color: #555;
    letter-spacing: 0.5px;
  }

  .ws-occupied[data-color="blue"] {
    background: linear-gradient(180deg, #1e3a6e, #162d55);
    border-color: #3b6eb8; color: #a8ccf0;
  }
  .ws-occupied[data-color="blue"] .ws-count { color: #6a9fd8; }

  .ws-occupied[data-color="purple"] {
    background: linear-gradient(180deg, #4a2a80, #3a1e68);
    border-color: #7a52c0; color: #c4aaf0;
  }
  .ws-occupied[data-color="purple"] .ws-count { color: #9a7ad0; }

  .ws-focused {
    box-shadow: 0 0 0 2px #60a5fa, 0 0 16px rgba(96,165,250,0.3);
    transform: scale(1.1);
  }
  .ws-focused[data-color="purple"] {
    box-shadow: 0 0 0 2px #a78bfa, 0 0 16px rgba(167,139,250,0.3);
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

  /* ── DateTime ── */
  .datetime {
    text-align: center;
  }

  .time {
    font-size: 20px; font-weight: 500; color: #555;
    letter-spacing: 1px;
    text-transform: capitalize;
  }

  footer {
    position: absolute;
    bottom: 0; left: 0; right: 0;
    text-align: center; padding: 8px;
    border-top: 1px solid #1a1a1a;
    font-size: 12px; color: #2a2a2a; letter-spacing: 1px;
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

# Workspaces
cat >> "$TMP" << WSSECTION
  <div class="ws-section">
    <div class="ws-label blue">Super Workspaces</div>
    <div class="ws-row">$WS_SUPER</div>
  </div>

  <div class="ws-section">
    <div class="ws-label purple">Hyper Workspaces</div>
    <div class="ws-row">$WS_HYPER</div>
  </div>

  <div class="datetime">
    <div class="time">$DATE_LINE</div>
  </div>
WSSECTION

cat >> "$TMP" << 'HTMLFOOT'
</div>

<footer>i3wm</footer>

<script>setTimeout(function(){location.reload()},3000);</script>
</body>
</html>
HTMLFOOT

# Atomic move
mv "$TMP" "$OUT"
