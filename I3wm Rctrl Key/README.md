<h1 align="center">
  Right Ctrl Key
</h1>

<h4 align="center">Turns Right Ctrl into an independent modifier (Mod5) for i3wm — separate from Super, Hyper, and Alt</h4>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux-blue?style=for-the-badge&logo=linux&logoColor=white">
  <img src="https://img.shields.io/badge/WM-i3wm-green?style=for-the-badge&logo=i3&logoColor=white">
  <img src="https://img.shields.io/badge/Tool-xmodmap-orange?style=for-the-badge">
  <img src="https://img.shields.io/badge/Modifier-Mod5-teal?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge">
</p>

---

## The Problem

i3wm only gives you **four usable modifiers**: Super (mod4), Alt (mod1), Hyper (mod3 if configured), and Shift/Control as combo modifiers. That's not enough — keybindings run out fast, especially if you use workspaces, app launchers, media keys, and window management.

**Right Ctrl sits on your keyboard doing nothing useful.** It duplicates Left Ctrl, which is already on mod `control`. Meanwhile, mod5 is wasted on AltGr (`ISO_Level3_Shift`), which doesn't need a modifier slot to produce special characters.

## The Solution

This script:

1. **Clears mod5** — removes AltGr from the modifier map
2. **Removes Right Ctrl from `control`** — so it stops acting as Ctrl
3. **Maps keycode 105 → `Hyper_R`** — gives it a unique keysym
4. **Assigns `Hyper_R` to mod5** — makes it a standalone modifier

**Result:** Right Ctrl becomes `$rctrl` (Mod5) in i3 — a completely independent modifier key that doesn't conflict with anything.

### What about AltGr?

**AltGr still works.** Characters like `@`, `#`, `{`, `}`, `~`, `|` are handled by XKB at the keysym level, not by the modifier map. Removing `ISO_Level3_Shift` from mod5 does **not** break AltGr's character production.

## Modifier Map After Setup

```
shift       Shift_L, Shift_R
control     Control_L              ← only Left Ctrl
mod1        Alt_L, Meta_L          ← Alt
mod2        Num_Lock
mod3        Hyper_L                ← Caps Lock (Hyper)
mod4        Super_L, Super_R       ← Super/Windows
mod5        Hyper_R                ← Right Ctrl (new!)
```

**Five independent modifiers** — each on a different physical key.

## Installation

### Quick Setup

```bash
# Copy the script
cp setup-rctrl.sh ~/.config/i3/setup-rctrl.sh
chmod +x ~/.config/i3/setup-rctrl.sh
```

Add to `~/.config/i3/config`:

```bash
# Right Ctrl as Mod5
set $rctrl Mod5

# Must run AFTER setup-hyper.sh
exec_always --no-startup-id ~/.config/i3/setup-rctrl.sh
```

### Usage in i3 Config

```bash
# Examples
bindsym $rctrl+Return exec alacritty
bindsym $rctrl+d exec rofi -show drun
bindsym $rctrl+q kill
bindsym $rctrl+Shift+s exec flameshot gui

# Combine with other modifiers
bindsym $rctrl+Shift+Left move container to workspace prev
```

## Verify It Works

```bash
xmodmap -pm
```

**Correct output:**

```
mod5        Hyper_R (0x69)
```

**Check control only has Left Ctrl:**

```
control     Control_L (0x25)
```

**Test AltGr characters** — open a terminal and type:

| Combo | Expected |
|-------|----------|
| `AltGr + 2` | `@` |
| `AltGr + 3` | `#` |
| `AltGr + '` | `{` |
| `AltGr + ¡` | `}` |

If all characters work → setup is correct.

## How It Works

```
┌─────────────────────────────────────────────────┐
│                    BEFORE                        │
│                                                  │
│  Right Ctrl ──► control modifier (= Left Ctrl)  │
│  AltGr      ──► mod5 (ISO_Level3_Shift)         │
│                                                  │
├─────────────────────────────────────────────────┤
│                    AFTER                          │
│                                                  │
│  Right Ctrl ──► mod5 (Hyper_R) ──► $rctrl in i3 │
│  AltGr      ──► (no modifier) ──► still types @#{}│
│  Left Ctrl  ──► control (unchanged)              │
│                                                  │
└─────────────────────────────────────────────────┘
```

The key insight is that **xmodmap modifiers** and **XKB keysym production** are independent systems. AltGr's ability to type `@`, `#`, `{`, `}` comes from XKB's level3 shift mechanism — it doesn't require a slot in the modifier map.

## Execution Order

This script **must** run after `setup-hyper.sh` because `setup-hyper.sh` calls `setxkbmap` which resets the modifier map:

```bash
# In ~/.config/i3/config
exec_always --no-startup-id ~/.config/i3/setup-hyper.sh    # 1st: resets xkb, sets Hyper
exec_always --no-startup-id ~/.config/i3/setup-rctrl.sh    # 2nd: configures Right Ctrl
```

## Troubleshooting

### Right Ctrl still acts as Ctrl

```bash
# Check if Control_R is still in control
xmodmap -pm | grep control

# If you see Control_R, re-run the script
~/.config/i3/setup-rctrl.sh
```

### AltGr stopped producing special characters

This shouldn't happen, but if it does:

```bash
# Re-add ISO_Level3_Shift to mod5
xmodmap -e "add mod5 = ISO_Level3_Shift"
```

### Modifier resets after i3 reload

That's expected — `exec_always` re-runs on reload, which re-applies the configuration. If it's not working after reload, check that `setup-rctrl.sh` runs **after** `setup-hyper.sh` in your config.

### mod5 shows both Hyper_R and ISO_Level3_Shift

```bash
# Clear and re-apply
xmodmap -e "clear mod5"
xmodmap -e "add mod5 = Hyper_R"
```

## Files

| File | Purpose |
|------|---------|
| `setup-rctrl.sh` | xmodmap script — clears mod5, remaps Right Ctrl to Hyper_R |
| `README.md` | This documentation |

## Requirements

- i3wm (or any X11 window manager)
- `xmodmap` (included with `x11-xserver-utils`)
- [Hyper Key setup](../I3wm%20Hyper%20Key/) (recommended, runs first)

## Related

- [I3wm Hyper Key](../I3wm%20Hyper%20Key/) — Caps Lock → Hyper on Mod3
- [I3wm Keybindings](../I3wm%20Keybindings/) — Visual HUD showing all shortcuts (includes RCtrl section)

## License

MIT
