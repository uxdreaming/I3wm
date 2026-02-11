#!/bin/bash
# =============================================================================
# HYPER KEY SETUP - Caps Lock → Hyper (Mod3)
# =============================================================================
# Caps Lock queda COMPLETAMENTE deshabilitado como toggle de mayúsculas.
# Se convierte en Hyper key asignada a Mod3.
#
# Este script debe ejecutarse:
# - Al iniciar i3 (exec en config)
# - Después de conectar/desconectar monitores
# - Si se resetea el teclado por cualquier razón
# =============================================================================

# Limpiar TODAS las opciones de xkb previas
setxkbmap -layout latam -option

# Configurar Caps Lock como Hyper (esto solo lo convierte, no elimina lock)
setxkbmap -option caps:hyper

# Esperar a que se aplique
sleep 0.2

# Eliminar COMPLETAMENTE la funcionalidad de Caps Lock
xmodmap -e "clear lock"
xmodmap -e "keycode 66 = Hyper_L"

# Mover Hyper de mod4 a mod3
xmodmap -e "remove mod4 = Hyper_L"
xmodmap -e "add mod3 = Hyper_L"

# Matar instancias previas de xcape
pkill -f "xcape.*Hyper_L" 2>/dev/null || true
sleep 0.1

# xcape: cuando Hyper se presiona sola (sin combinar), genera F20
# Esto permite detectar "tap" de la hyper key
if command -v xcape &> /dev/null; then
    xcape -e "Hyper_L=F20" -t 200
fi

# Verificación (para debug)
# xmodmap -pm | grep -E "lock|mod3|mod4"
