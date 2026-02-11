# I3wm Guide

Complete setup guide for this i3wm environment.

## Prerequisites

| Package | Purpose |
|---------|---------|
| i3wm | Window manager |
| Google Chrome | Renders HUD overlays via `--app` mode |
| xdotool | Window detection for toggle scripts |
| picom | Compositor (shadows, blur, transparency, rounded corners) |
| jq | JSON parsing for i3 workspace data |
| lm-sensors | CPU temperature readings |
| NetworkManager | WiFi SSID and connection info |

### Install on Arch-based systems

```bash
sudo pacman -S i3-wm google-chrome xdotool picom jq lm_sensors networkmanager
```

### Install on Debian/Ubuntu

```bash
sudo apt install i3 xdotool picom jq lm-sensors network-manager
# Chrome: install from https://google.com/chrome
```

## Installation

1. Clone the repo:

```bash
git clone https://github.com/uxdreaming/I3wm.git ~/I3wm
```

2. Make scripts executable:

```bash
chmod +x ~/I3wm/I3wm\ Keybindings/toggle.sh
chmod +x ~/I3wm/I3wm\ Dashboard/toggle.sh
chmod +x ~/I3wm/I3wm\ Dashboard/generate.sh
```

3. Add to your i3 config (`~/.config/i3/config`):

```bash
# Keybindings HUD (F1)
bindsym F1 exec --no-startup-id ~/I3wm/I3wm\ Keybindings/toggle.sh
for_window [class="keybinds_hud"] floating enable, border none, fullscreen enable
for_window [title="i3 Keybindings HUD"] floating enable, border none, fullscreen enable

# Dashboard (F2)
bindsym F2 exec --no-startup-id ~/I3wm/I3wm\ Dashboard/toggle.sh
for_window [class="i3_dashboard"] floating enable, border none, fullscreen enable
for_window [title="i3 Dashboard"] floating enable, border none, fullscreen enable
```

4. Copy the picom config:

```bash
cp ~/I3wm/I3wm\ Config/picom.conf ~/.config/picom/picom.conf
```

5. Reload i3: `Super+Shift+R`

## Usage

| Key | Action |
|-----|--------|
| `F1` | Toggle keybindings HUD |
| `F2` | Toggle system dashboard |

### Keybindings HUD

- Search by typing in the search bar
- Press `1`-`5` to filter by modifier (Super, Hyper, Alt, Ctrl, Shift)
- Press `Escape` to clear filters

### Dashboard

- Shows workspace indicators, system metrics (ring gauges), network, temperature, uptime, load
- Auto-refreshes every 3 seconds while open
- Background data generation stops automatically when the window closes

## Key Mapping

This setup uses CapsLock remapped to Hyper (Mod3) via xmodmap or xkb, giving three modifier layers:

| Modifier | Key | Color |
|----------|-----|-------|
| Super | Win key | Blue |
| Hyper | CapsLock | Purple |
| Alt | Alt key | Green |

Workspaces 0-9 use Super, workspaces 10-19 use Hyper.

## Picom

The picom config excludes both HUD windows from all compositor effects (shadows, fading, blur, transparency, rounded corners) so they render as clean fullscreen overlays without visual artifacts.
