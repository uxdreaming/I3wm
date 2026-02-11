# I3wm

A minimal i3wm setup with on-demand HUD overlays instead of a permanent status bar. No polybar, no i3bar — just fullscreen panels toggled with function keys.

## Components

### [I3wm Keybindings](I3wm%20Keybindings/)

Visual keybindings reference toggled with `F1`. All shortcuts displayed as realistic keycaps with color-coded modifiers in a masonry layout. Includes text search and modifier quick-filter (`1`-`5`).

![Keybindings HUD](I3wm%20Keybindings/screenshots/01-general.png)

### [I3wm Dashboard](I3wm%20Dashboard/)

System dashboard toggled with `F2`. Shows workspace indicators (Super 0-9, Hyper 10-19) and system metrics with SVG ring gauges. Auto-refreshes every 3 seconds.

**Ring gauges:** Battery, Memory, CPU, Disk — color-coded green/yellow/red by status.

**Info cards:** WiFi, Temperature, Uptime, Load — with SVG icons and colored accent borders.

### [I3wm Config](I3wm%20Config/)

i3 and picom configuration files. Includes:

- `config` — i3wm config with Super, Hyper (CapsLock), and Alt modifier layers
- `picom.conf` — Compositor with blur, shadows, rounded corners, and HUD exclusions

### [I3wm Guide](I3wm%20Guide/)

Setup instructions, prerequisites, and key mapping reference.

## Quick Start

```bash
git clone https://github.com/uxdreaming/I3wm.git ~/I3wm
chmod +x ~/I3wm/I3wm\ Keybindings/toggle.sh
chmod +x ~/I3wm/I3wm\ Dashboard/{toggle,generate}.sh
```

Add to `~/.config/i3/config`:

```bash
bindsym F1 exec --no-startup-id ~/I3wm/I3wm\ Keybindings/toggle.sh
bindsym F2 exec --no-startup-id ~/I3wm/I3wm\ Dashboard/toggle.sh
```

See the [I3wm Guide](I3wm%20Guide/) for full installation steps.

## Architecture

Both HUD overlays use the same pattern:

1. Shell script checks if window exists (via `xdotool`)
2. If open → close it
3. If closed → generate HTML → launch Chrome `--app` mode → force fullscreen via `i3-msg`

Each overlay runs in an isolated Chrome profile (`/tmp/`) so it doesn't interfere with regular browsing.

## License

MIT
