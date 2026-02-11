#!/bin/bash
# Convertir Caps Lock en Hyper key (Mod3) y deshabilitar Caps Lock

# Limpiar el lock modifier (deshabilita Caps Lock completamente)
xmodmap -e "clear lock"

# Convertir keycode 66 (Caps Lock) en Hyper_L
spare_modifier="Hyper_L"
xmodmap -e "keycode 66 = $spare_modifier"
xmodmap -e "remove mod4 = $spare_modifier"
xmodmap -e "add mod3 = $spare_modifier"
