#!/bin/bash
# Script para lanzar o enfocar Logseq

LOCKFILE="/tmp/logseq-launch.lock"

# Verificar si ya hay una instancia del script corriendo
if [ -f "$LOCKFILE" ]; then
    exit 0
fi

# Crear lockfile
touch "$LOCKFILE"

# Verificar si la ventana de Logseq existe en i3
if i3-msg -t get_tree | grep -q '"class":"Logseq"'; then
    # Si existe, cambiar al workspace 0
    i3-msg workspace number 0
elif pgrep -f "com.logseq.Logseq" > /dev/null; then
    # Si el proceso existe pero la ventana no, cambiar al workspace 0
    i3-msg workspace number 0
else
    # Si no está corriendo, lanzarlo desde Flatpak con flags de optimización agresivos
    flatpak run com.logseq.Logseq \
        --no-sandbox \
        --disable-gpu \
        --disable-software-rasterizer \
        --disable-dev-shm-usage \
        --disable-setuid-sandbox \
        --disable-features=VizDisplayCompositor \
        --js-flags="--expose-gc --max-old-space-size=4096" &
fi

# Eliminar lockfile
rm -f "$LOCKFILE"
