#!/bin/bash
# Generate i3 Workspaces HTML
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/workspaces.html"
TMP="$OUT.tmp"

# ── Gather data ──────────────────────────────────────────

# Workspaces (JSON array from i3)
WS_JSON=$(i3-msg -t get_workspaces 2>/dev/null || echo '[]')

eval $(echo "$WS_JSON" | jq -r '
  "WS_OCCUPIED=\"" + ([.[] | .num | tostring] | join(" ")) + "\"",
  "WS_FOCUSED=\"" + ([.[] | select(.focused) | .num | tostring] | join(" ")) + "\"",
  "WS_URGENT=\"" + ([.[] | select(.urgent) | .num | tostring] | join(" ")) + "\""
' 2>/dev/null)

# Window classes per workspace
TREE_JSON=$(i3-msg -t get_tree 2>/dev/null || echo '{}')

# Normalize app class names (for alt/tooltip text)
normalize_class() {
  case "$1" in
    Google-chrome) echo "Chrome" ;;
    obsidian)      echo "Obsidian" ;;
    Alacritty)     echo "Terminal" ;;
    code-oss|Code) echo "Code" ;;
    zapzap|ZapZap) echo "ZapZap" ;;
    *)             echo "$1" ;;
  esac
}

# Map app class to Papirus icon path
icon_for_class() {
  local base="/usr/share/icons/Papirus/32x32/apps"
  case "$1" in
    Google-chrome)  echo "$base/google-chrome.svg" ;;
    obsidian)       echo "$base/obsidian.svg" ;;
    Alacritty)      echo "$base/com.alacritty.Alacritty.svg" ;;
    code-oss|Code)  echo "$base/vscode.svg" ;;
    zapzap|ZapZap)  echo "$base/com.rtosta.zapzap.svg" ;;
    *)              echo "" ;;
  esac
}

# Build workspace → icon list (pipe-separated, max 4, no dedup)
declare -A WS_ICON_LIST  # WS_ICON_LIST[3]="/path/icon.svg:Alt|/path/icon2.svg:Alt2"
while IFS='|' read -r wsnum wclass; do
  [ -z "$wsnum" ] && continue
  local_icon=$(icon_for_class "$wclass")
  [ -z "$local_icon" ] && continue
  local_name=$(normalize_class "$wclass")
  # Count existing entries
  existing="${WS_ICON_LIST[$wsnum]:-}"
  if [ -z "$existing" ]; then
    count=0
  else
    count=$(echo "$existing" | tr '|' '\n' | wc -l)
  fi
  [ "$count" -ge 4 ] && continue
  WS_ICON_LIST[$wsnum]="${existing:+${existing}|}${local_icon}:${local_name}"
done < <(echo "$TREE_JSON" | jq -r '
  recurse(.nodes[]?, .floating_nodes[]?) |
  select(.type == "workspace") |
  .num as $n |
  recurse(.nodes[]?, .floating_nodes[]?) |
  select(.window != null and .window_properties.class != null) |
  "\($n)|\(.window_properties.class)"
' 2>/dev/null)

build_ws() {
  local start=$1 end=$2 color=$3 display_offset=${4:-0} html=""
  for i in $(seq $start $end); do
    local display_num=$((i - display_offset))
    local cls="ws"
    local icons="${WS_ICON_LIST[$i]:-}"
    [[ " $WS_OCCUPIED " == *" $i "* ]] && cls="$cls ws-occupied"
    [[ " $WS_FOCUSED " == *" $i "* ]] && cls="$cls ws-focused"
    [[ " $WS_URGENT " == *" $i "* ]] && cls="$cls ws-urgent"
    html="$html<div class=\"$cls\" data-color=\"$color\">"
    html="$html<span class=\"ws-num\">$display_num</span>"
    if [ -n "$icons" ]; then
      html="$html<div class=\"ws-icons\">"
      IFS='|' read -ra entries <<< "$icons"
      for entry in "${entries[@]}"; do
        local icon_path="${entry%%:*}"
        local alt_text="${entry#*:}"
        html="$html<img src=\"$icon_path\" alt=\"$alt_text\">"
      done
      html="$html</div>"
    fi
    html="$html</div>"
  done
  echo "$html"
}

WS_SUPER_A=$(build_ws 0 4 "blue" 0)
WS_SUPER_B=$(build_ws 5 9 "blue" 0)
WS_HYPER_A=$(build_ws 10 14 "purple" 10)
WS_HYPER_B=$(build_ws 15 19 "purple" 10)


# ── Generate HTML ────────────────────────────────────────

cat > "$TMP" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>i3 Workspaces</title>
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
    gap: 40px;
  }

  /* ── Workspaces ── */
  .ws-section { text-align: center; display: flex; flex-direction: column; align-items: center; gap: 10px; }

  .ws-label {
    font-size: 14px; font-weight: 600; text-transform: uppercase;
    letter-spacing: 2px; margin-bottom: 14px;
  }
  .ws-label.blue { color: #60a5fa; }
  .ws-label.purple { color: #a78bfa; }

  .ws-row {
    display: flex; justify-content: center; gap: 10px;
  }

  .ws {
    width: 140px; height: 115px;
    display: flex; flex-direction: column;
    align-items: center;
    padding: 10px 0 8px;
    gap: 2px;
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

  .ws-icons {
    display: flex; flex-wrap: wrap;
    justify-content: center;
    gap: 4px;
    margin-top: 6px;
    max-width: 64px;
  }

  .ws-icons img {
    width: 24px; height: 24px;
    opacity: 0.85;
  }

  .ws-occupied[data-color="blue"] {
    background: linear-gradient(180deg, #1e3a6e, #162d55);
    border-color: #3b6eb8; color: #a8ccf0;
  }
  .ws-occupied[data-color="blue"] .ws-icons img { opacity: 1; }

  .ws-occupied[data-color="purple"] {
    background: linear-gradient(180deg, #4a2a80, #3a1e68);
    border-color: #7a52c0; color: #c4aaf0;
  }
  .ws-occupied[data-color="purple"] .ws-icons img { opacity: 1; }

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
  <h1>i3 Workspaces</h1>
  <span class="hint">Press <kbd>F2</kbd> to close</span>
</header>

<div class="content">
HTMLHEAD

# Workspaces
cat >> "$TMP" << WSSECTION
  <div class="ws-section">
    <div class="ws-label blue">Super Workspaces</div>
    <div class="ws-row">$WS_SUPER_A</div>
    <div class="ws-row">$WS_SUPER_B</div>
  </div>

  <div class="ws-section">
    <div class="ws-label purple">Hyper Workspaces</div>
    <div class="ws-row">$WS_HYPER_A</div>
    <div class="ws-row">$WS_HYPER_B</div>
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
