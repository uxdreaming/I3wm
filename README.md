# I3wm

A minimal i3wm setup with on-demand HUD overlays instead of a permanent status bar. No polybar, no i3bar — just fullscreen panels toggled with function keys.

## Components

### [I3wm Keybindings](I3wm%20Keybindings/)

Visual keybindings reference toggled with `F1`. All shortcuts displayed as realistic keycaps with color-coded modifiers in a masonry layout. Includes text search and modifier quick-filter (`1`-`5`).

![Keybindings HUD](I3wm%20Keybindings/screenshots/01-general.png)

### [I3wm Workspaces](I3wm%20Workspaces/)

Workspace overview toggled with `F2`. Shows all 20 workspaces (Super 0-9, Hyper 10-19) with occupancy status, window count, and focused workspace glow. Auto-refreshes every 3 seconds.

![Workspaces](I3wm%20Workspaces/screenshots/01-workspaces.png)

### [I3wm Hyper Key](I3wm%20Hyper%20Key/)

Converts Caps Lock to a **real Hyper key** on `mod3`, completely separate from Super (`mod4`). Includes install/uninstall scripts, autostart desktop entry, and udev rule for USB keyboards. Solves the common problem where most guides incorrectly put Hyper on mod4 making it identical to Super.

### [I3wm Config](I3wm%20Config/)

All dotfiles organized by application:

- `i3/` — i3wm config, launcher scripts, monitor daemon, window tracker
- `picom/` — Compositor with blur, shadows, rounded corners, HUD exclusions
- `alacritty/` — Terminal config (opacity, font, theme)
- `rofi/` — Launcher config, audio selector script
- `dunst/` — Notification daemon config
- `polybar/` — Status bar config (optional, not used in current setup)
- `nitrogen/` — Wallpaper manager config
- `gtk-2.0/` & `gtk-3.0/` — Dark theme settings (Adwaita-dark, Papirus icons)

### [I3wm Guide](I3wm%20Guide/)

Complete setup guide from scratch: base installation, essential programs (rofi, dunst, picom, nitrogen), applications (Chrome, VS Code, Obsidian, Logseq), GTK theming, Hyper key configuration, and post-installation checklist. Includes `install.sh` script.

## Quick Start

```bash
git clone https://github.com/uxdreaming/I3wm.git ~/I3wm
chmod +x ~/I3wm/I3wm\ Keybindings/toggle.sh
chmod +x ~/I3wm/I3wm\ Workspaces/{toggle,generate}.sh
```

Add to `~/.config/i3/config`:

```bash
bindsym F1 exec --no-startup-id ~/I3wm/I3wm\ Keybindings/toggle.sh
bindsym F2 exec --no-startup-id ~/I3wm/I3wm\ Workspaces/toggle.sh
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
