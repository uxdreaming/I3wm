#!/bin/bash
# Script para cambiar automáticamente entre pantalla de laptop y HDMI

# Verificar si HDMI está conectado
if xrandr | grep "HDMI-1 connected" > /dev/null; then
    # HDMI conectado - usar solo HDMI como principal
    xrandr --output eDP-1 --off --output HDMI-1 --primary --mode 1360x768 --pos 0x0
else
    # HDMI no conectado - usar solo laptop
    xrandr --output HDMI-1 --off --output eDP-1 --primary --auto
fi
