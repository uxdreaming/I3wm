#!/bin/bash
# Daemon que monitorea cambios en la conexión de monitores

# Función para detectar el estado del HDMI
get_hdmi_status() {
    xrandr | grep "HDMI-1 connected" > /dev/null && echo "connected" || echo "disconnected"
}

# Estado inicial
previous_status=$(get_hdmi_status)

# Ejecutar el script de cambio inicial
~/.config/i3/monitor-switch.sh

# Monitorear cambios cada 2 segundos
while true; do
    sleep 2
    current_status=$(get_hdmi_status)

    # Si el estado cambió, ejecutar el script de cambio
    if [ "$current_status" != "$previous_status" ]; then
        ~/.config/i3/monitor-switch.sh
        previous_status=$current_status
    fi
done
