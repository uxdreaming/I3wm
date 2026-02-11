# i3wm Setup Guide

Complete guide to install and configure i3wm from scratch, replicating my personal setup.

**Base distro**: Linux Mint Debian Edition (LMDE) or any Debian/Ubuntu-based distro

---

## Table of Contents

1. [Base Installation](#1-base-installation)
2. [i3wm Configuration](#2-i3wm-configuration)
3. [Essential Programs](#3-essential-programs)
4. [Applications](#4-applications)
5. [Settings](#5-settings)
6. [Post-Installation](#6-post-installation)

---

## 1. Base Installation

### Update system
```bash
sudo apt update && sudo apt upgrade -y
```

### Install i3wm and essential dependencies
```bash
sudo apt install -y i3 i3lock i3status xorg xinit
```

### Install environment tools
```bash
sudo apt install -y \
  rofi \
  dunst \
  picom \
  nitrogen \
  thunar \
  flameshot \
  feh \
  xdotool \
  xclip \
  playerctl \
  pulseaudio \
  pavucontrol \
  network-manager-gnome \
  lxappearance \
  arandr \
  xsettingsd
```

---

## 2. i3wm Configuration

### Create config directory
```bash
mkdir -p ~/.config/i3
```

### Copy i3 configuration
The `config` file goes in `~/.config/i3/config`

**Base color theme**: `#202020` (dark background)

**Main features**:
- Mod key: Super (Windows key)
- Hyper key: Caps Lock (remapped to Mod3)
- Gaps: inner 4, outer 2
- Borders: 3px without title bars
- Rounded corners (via picom)

### Required scripts in `~/.config/i3/`

1. **setup-hyper.sh** - Remaps Caps Lock to Hyper key
2. **setup-dark-theme.sh** - Configures GTK dark theme
3. **update-lockscreen.sh** - Updates lockscreen wallpaper
4. **launch-obsidian.sh** - Obsidian launcher
5. **launch-logseq.sh** - Logseq launcher

---

## 3. Essential Programs

### Alacritty (Terminal)
```bash
sudo apt install -y alacritty
mkdir -p ~/.config/alacritty
```
Copy `alacritty.toml` to `~/.config/alacritty/`

**Features**:
- Opacity: 0.95
- Font: DejaVu Sans Mono 12
- Theme: Custom high legibility (background #1c1c1c)

### Rofi (Launcher)
```bash
sudo apt install -y rofi
mkdir -p ~/.config/rofi
```

### Dunst (Notifications)
```bash
sudo apt install -y dunst
mkdir -p ~/.config/dunst
```
Copy `dunstrc` to `~/.config/dunst/`

**Features**:
- Position: top-right
- Rounded corners: 8px
- Colors: #202020 theme

### Picom (Compositor)
```bash
sudo apt install -y picom
mkdir -p ~/.config/picom
```
Copy `picom.conf` to `~/.config/picom/`

**Features**:
- Backend: GLX
- Shadows enabled
- Fade in/out
- Blur: dual_kawase
- Rounded corners: 8px
- Inactive opacity: 0.95

### Nitrogen (Wallpaper)
```bash
sudo apt install -y nitrogen
mkdir -p ~/.config/nitrogen
mkdir -p ~/downloads/walls
```

### Autotiling (Auto splits)
```bash
pip3 install autotiling
```
Or clone from GitHub:
```bash
git clone https://github.com/nwg-piotr/autotiling.git ~/.config/autotiling
cd ~/.config/autotiling && pip3 install .
```

### i3-swallow (Window swallowing)
```bash
pip3 install i3-swallow
```

### Polybar (Status bar) - Optional
```bash
sudo apt install -y polybar
mkdir -p ~/.config/polybar
```

### Cava (Audio visualizer) - Optional
```bash
sudo apt install -y cava
mkdir -p ~/.config/cava
```

### Pipes (Terminal screensaver)
```bash
sudo apt install -y bsdgames
```
Alias: `alias pipes='/usr/games/pipes'`

---

## 4. Applications

### Google Chrome
```bash
wget -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i /tmp/chrome.deb
sudo apt install -f -y
```

### VS Code
```bash
wget -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
sudo dpkg -i /tmp/vscode.deb
sudo apt install -f -y
```

### Obsidian (AppImage)
```bash
mkdir -p ~/apps
wget -O ~/apps/Obsidian.AppImage "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.7.7/Obsidian-1.7.7.AppImage"
chmod +x ~/apps/Obsidian.AppImage
```

### Logseq (AppImage)
```bash
wget -O ~/apps/Logseq.AppImage "https://github.com/logseq/logseq/releases/latest/download/Logseq-linux-x64.AppImage"
chmod +x ~/apps/Logseq.AppImage
```

### Rnote (Handwritten notes)
```bash
flatpak install flathub com.github.flxzt.rnote -y
```

### Zen Browser
```bash
# Download from https://zen-browser.app/
# Or via Flatpak:
flatpak install flathub io.github.nickvergessen.ZenBrowser -y
```

### ZapZap (WhatsApp)
```bash
flatpak install flathub com.rtosta.zapzap -y
```

---

## 5. Settings

### GTK Theme (Dark)

#### GTK 3 (`~/.config/gtk-3.0/settings.ini`)
```ini
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Ubuntu 10
gtk-cursor-theme-name=breeze
gtk-cursor-theme-size=24
```

#### GTK 2 (`~/.gtkrc-2.0`)
```
gtk-theme-name="Adwaita-dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Ubuntu 10"
gtk-cursor-theme-name="breeze"
gtk-cursor-theme-size=24
```

### Install themes and icons
```bash
sudo apt install -y \
  papirus-icon-theme \
  breeze-cursor-theme \
  adwaita-icon-theme-full
```

### Hyper Key (Caps Lock → Mod3)

Caps Lock becomes Hyper key (Mod3) and is **permanently disabled** as caps toggle. The physical Caps Lock key is now Hyper and will never activate caps lock.

#### Configuration files

**1. Main script** `~/.config/i3/setup-hyper.sh`:
```bash
#!/bin/bash
# HYPER KEY SETUP - Caps Lock → Hyper (Mod3)
# Caps Lock is COMPLETELY disabled as caps toggle.

# Clear ALL previous xkb options
setxkbmap -layout latam -option

# Configure Caps Lock as Hyper
setxkbmap -option caps:hyper

sleep 0.2

# COMPLETELY remove Caps Lock functionality
xmodmap -e "clear lock"
xmodmap -e "keycode 66 = Hyper_L"

# Move Hyper from mod4 to mod3
xmodmap -e "remove mod4 = Hyper_L"
xmodmap -e "add mod3 = Hyper_L"
```

**2. Persistence** `~/.Xmodmap`:
```
clear lock
keycode 66 = Hyper_L
remove mod4 = Hyper_L
add mod3 = Hyper_L
```

**3. Auto-load** `~/.xsessionrc`:
```bash
#!/bin/bash
if [ -f ~/.Xmodmap ]; then
    xmodmap ~/.Xmodmap
fi
```

**4. In i3 config** (use `exec_always` so it applies on i3 restart too):
```
exec_always --no-startup-id ~/.config/i3/setup-hyper.sh
```

#### Verify configuration
```bash
xmodmap -pm | grep -E "lock|mod3|mod4"
# lock should be empty
# mod3 should contain Hyper_L
```

#### If it resets
Run manually: `~/.config/i3/setup-hyper.sh`
Or restart i3: `Super + Shift + r`

---

## 6. Post-Installation

### Main keybindings

| Shortcut | Action |
|----------|--------|
| `Super + Return` | Terminal (Alacritty) |
| `Super + d` | Launcher (Rofi) |
| `Super + c` | Close window |
| `Super + Shift+w` | Chrome |
| `Alt + o` | Obsidian |
| `Alt + l` | Logseq |
| `Alt + v` | VS Code |
| `Super + l` | Lock screen |
| `Super + Shift+n` | Nitrogen (wallpaper) |
| `Print` | Screenshot (Flameshot) |
| `Super + f` | Fullscreen |
| `Super + r` | Resize mode |
| `Alt + Tab` | Switch workspaces |

### Assigned workspaces

| App | Workspace |
|-----|-----------|
| Logseq | 0 |
| Obsidian | 3 |
| ZapZap | 9 |

### Verify installation
```bash
# Verify i3
i3 --version

# Verify picom
picom --version

# Verify autotiling
autotiling --help

# Test rofi
rofi -show drun
```

### Restart i3
```bash
# From i3
Super + Shift + r

# Or from terminal
i3-msg restart
```

---

## File structure

```
~/.config/
├── i3/
│   ├── config
│   ├── setup-hyper.sh
│   ├── setup-dark-theme.sh
│   ├── update-lockscreen.sh
│   ├── launch-obsidian.sh
│   └── launch-logseq.sh
├── alacritty/
│   └── alacritty.toml
├── rofi/
│   └── (themes)
├── dunst/
│   └── dunstrc
├── picom/
│   └── picom.conf
├── nitrogen/
│   └── nitrogen.cfg
├── polybar/
│   └── (config)
└── gtk-3.0/
    └── settings.ini
```

---

## Quick install (one-liner)

### Base packages
```bash
sudo apt install -y i3 i3lock rofi dunst picom nitrogen thunar flameshot alacritty feh xdotool xclip playerctl pavucontrol network-manager-gnome lxappearance arandr papirus-icon-theme breeze-cursor-theme
```

### Python tools
```bash
pip3 install autotiling i3-swallow
```

---

## Changelog

- **2025-12-28**: Initial version

---

*Guide created to replicate my personal i3wm configuration*
