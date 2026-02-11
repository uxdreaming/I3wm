#!/bin/bash
# Forzar dark mode en todas las aplicaciones

# GTK
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Qt
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=Adwaita-Dark

# Electron/Chromium apps (VSCode, Discord, etc)
export GTK_THEME=Adwaita:dark
