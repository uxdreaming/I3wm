#!/bin/bash
# Hyper Key Uninstaller

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo ./uninstall.sh"
    exit 1
fi

USER_HOME=$(eval echo ~$SUDO_USER)
USERNAME=$SUDO_USER

echo "Removing Hyper Key configuration..."

rm -f /usr/local/bin/hyper-key-fix
rm -f /etc/udev/rules.d/99-hyper-key.rules
rm -f "$USER_HOME/.config/autostart/hyper-key.desktop"

# Remove systemd resume service if installed
systemctl disable hyper-key-resume.service 2>/dev/null || true
rm -f /etc/systemd/system/hyper-key-resume.service
systemctl daemon-reload 2>/dev/null || true

udevadm control --reload-rules 2>/dev/null || true

# Clear any xkb options
su - $USERNAME -c "gsettings reset org.gnome.desktop.input-sources xkb-options" 2>/dev/null || true

echo "✓ Hyper Key configuration removed"
echo ""
echo "To restore Caps Lock, logout/login or run:"
echo "  setxkbmap -option"
