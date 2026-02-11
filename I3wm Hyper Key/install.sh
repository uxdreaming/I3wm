#!/bin/bash
# Hyper Key Installer
# Converts Caps Lock to Hyper key (mod3) - SEPARATE from Super (mod4)
#
# IMPORTANT: We do NOT use setxkbmap -option caps:hyper, gsettings, or localectl
# because they all put Hyper on mod4, making it identical to Super.
# Instead, we use pure xmodmap applied via autostart and udev.

set -e

USER_HOME=$(eval echo ~$SUDO_USER)
USERNAME=$SUDO_USER

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo ./install.sh"
    exit 1
fi

echo "Installing Hyper Key configuration..."
echo ""

# 1. Install the fix script
cp hyper-key-fix /usr/local/bin/hyper-key-fix
chmod +x /usr/local/bin/hyper-key-fix
echo "✓ Script installed to /usr/local/bin/hyper-key-fix"

# 2. Install udev rule (for USB keyboards)
cp 99-hyper-key.rules /etc/udev/rules.d/99-hyper-key.rules
udevadm control --reload-rules
echo "✓ udev rule installed"

# 3. Install autostart for user
mkdir -p "$USER_HOME/.config/autostart"
cp hyper-key.desktop "$USER_HOME/.config/autostart/hyper-key.desktop"
sed -i "s|\$HOME|$USER_HOME|g" "$USER_HOME/.config/autostart/hyper-key.desktop"
chown $USERNAME:$USERNAME "$USER_HOME/.config/autostart/hyper-key.desktop"
echo "✓ Autostart configured"

# 4. Clear any conflicting xkb options (caps:hyper puts Hyper on mod4!)
su - $USERNAME -c "gsettings reset org.gnome.desktop.input-sources xkb-options" 2>/dev/null || true
echo "✓ Cleared conflicting gsettings"

# 5. Clear localectl caps:hyper if set (it also puts Hyper on mod4)
if command -v localectl &> /dev/null; then
    CURRENT_LAYOUT=$(localectl status | grep "X11 Layout" | awk '{print $3}')
    CURRENT_MODEL=$(localectl status | grep "X11 Model" | awk '{print $3}')
    # Set keymap WITHOUT caps:hyper option
    localectl set-x11-keymap "${CURRENT_LAYOUT:-us}" "${CURRENT_MODEL:-pc105}" "" "" 2>/dev/null || true
    echo "✓ Cleared conflicting localectl options"
fi

# 6. Apply immediately using our xmodmap-based script
su - $USERNAME -c "DISPLAY=:0 /usr/local/bin/hyper-key-fix" 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Hyper Key installation complete!"
echo "  Caps Lock → Hyper (mod3) - SEPARATE from Super"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Verify with: xmodmap -pm | grep mod"
echo "  - mod3 should have Hyper_L"
echo "  - mod4 should have Super_L, Super_R (NO Hyper_L)"
echo ""
echo "If it resets, run: hyper-key-fix"
