#!/bin/bash
# Script para lanzar o enfocar Obsidian

LOCKFILE="/tmp/obsidian-launch.lock"

# Verificar si ya hay una instancia del script corriendo
if [ -f "$LOCKFILE" ]; then
    exit 0
fi

# Crear lockfile
touch "$LOCKFILE"

# Verificar si la ventana de Obsidian existe en i3
if i3-msg -t get_tree | grep -q '"class":"[Oo]bsidian"'; then
    # Si existe, cambiar al workspace 3
    i3-msg workspace number 3
elif pgrep -f "md.obsidian.Obsidian" > /dev/null; then
    # Si el proceso existe pero la ventana no, cambiar al workspace 3
    i3-msg workspace number 3
else
    # Si no está corriendo, lanzarlo desde Flatpak
    flatpak run md.obsidian.Obsidian &
fi

# Eliminar lockfile
rm -f "$LOCKFILE"
