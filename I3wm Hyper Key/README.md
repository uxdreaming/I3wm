# Hyper Key Config

Converts Caps Lock to a **real Hyper key** on Linux — on **mod3**, completely **separate from Super**.

## The Problem

Most guides online tell you to use:
```bash
setxkbmap -option caps:hyper
# or
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:hyper']"
```

**This is wrong.** These methods put Hyper on **mod4**, the same modifier as Super. Result:
- `Hyper+X` = `Super+X` (they're identical)
- You can't have separate Hyper shortcuts

## The Solution

This repo uses **pure xmodmap** to:
1. Map Caps Lock → Hyper_L
2. Put Hyper_L on **mod3** (not mod4)
3. Keep Super on mod4 (unchanged)

Result: Hyper and Super are **completely independent modifiers**.

## Installation

```bash
git clone git@github.com:uxdreaming/hyper-key-config.git
cd hyper-key-config
sudo ./install.sh
```

## Verify it works

```bash
xmodmap -pm | grep mod
```

**Correct output:**
```
mod3        Hyper_L (0x42)
mod4        Super_L (0x85),  Super_R (0x86)
```

**Wrong output (Hyper = Super):**
```
mod4        Hyper_L (0x42),  Super_L (0x85),  Super_R (0x86)
```

## What it does

| Component | Location | Purpose |
|-----------|----------|---------|
| hyper-key-fix | /usr/local/bin/ | xmodmap script that configures Hyper on mod3 |
| autostart | ~/.config/autostart/ | Runs hyper-key-fix on login |
| udev rule | /etc/udev/rules.d/ | Runs hyper-key-fix when USB keyboard connects |

**Important:** We intentionally do NOT use gsettings or localectl with `caps:hyper` because they force Hyper onto mod4.

## If Hyper stops working

**Run this:**
```bash
hyper-key-fix
```

That's it. The script re-applies the xmodmap configuration.

**NEVER run** `setxkbmap -option caps:hyper` — that merges Hyper with Super.

### When it can reset

| Situation | Resets? | Solution |
|-----------|---------|----------|
| System reboot | No | autostart applies it |
| USB keyboard connected | No | udev applies it |
| Suspend/Resume | **Possible** | `hyper-key-fix` or install systemd service |
| Change keyboard layout | **Yes** | `hyper-key-fix` |
| Run `setxkbmap` | **Yes** | `hyper-key-fix` |

## How it works

The `hyper-key-fix` script runs:

```bash
# Clear xkb options (they conflict with our setup)
setxkbmap -option

# Pure xmodmap configuration
xmodmap - <<'EOF'
clear lock
keycode 66 = Hyper_L
remove mod4 = Hyper_L
add mod3 = Hyper_L
EOF
```

## Troubleshooting

### Hyper is still on mod4

1. Check for conflicting settings:
   ```bash
   gsettings get org.gnome.desktop.input-sources xkb-options
   localectl status | grep Options
   ```

2. Clear them:
   ```bash
   gsettings reset org.gnome.desktop.input-sources xkb-options
   sudo localectl set-x11-keymap us pc105 "" ""
   ```

3. Re-run the fix:
   ```bash
   hyper-key-fix
   ```

### Configuration resets after suspend/resume

Add to `/etc/systemd/system/hyper-key-resume.service`:
```ini
[Unit]
Description=Restore Hyper key after resume
After=suspend.target hibernate.target hybrid-sleep.target

[Service]
Type=oneshot
Environment=DISPLAY=:0
ExecStart=/usr/local/bin/hyper-key-fix

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target
```

Then: `sudo systemctl enable hyper-key-resume`

### Check the log

```bash
cat /tmp/hyper-key.log
```

## Uninstall

```bash
sudo ./uninstall.sh
```

## Files

- `hyper-key-fix` - xmodmap script (does NOT use setxkbmap -option caps:hyper)
- `hyper-key.desktop` - Autostart entry
- `99-hyper-key.rules` - udev rule for USB keyboards
- `install.sh` - Installation script
- `uninstall.sh` - Removal script

## Tested on

- Linux Mint 22 (Cinnamon)
- Ubuntu 24.04 (GNOME)
- Xfce / i3wm
