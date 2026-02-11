#!/bin/bash
# =============================================================================
# HYPER DOUBLE TAP - Ir a workspace Z con 2 pulsaciones
# =============================================================================
# Detecta 2 pulsaciones de hyper key en menos de 400ms y va a workspace Z
# =============================================================================

LOCK_FILE="/tmp/hyper-tap.lock"
COUNT_FILE="/tmp/hyper-tap-count"
TIME_FILE="/tmp/hyper-tap-time"
TIMEOUT_MS=400

# Obtener timestamp actual en milisegundos
current_time() {
    echo $(($(date +%s%N) / 1000000))
}

# Ir al workspace Z
go_to_workspace_z() {
    i3-msg "workspace Z" > /dev/null
}

# Lock para evitar race conditions
exec 200>"$LOCK_FILE"
flock -n 200 || exit 0

now=$(current_time)

# Leer estado anterior
if [[ -f "$COUNT_FILE" && -f "$TIME_FILE" ]]; then
    count=$(cat "$COUNT_FILE")
    last_time=$(cat "$TIME_FILE")
    elapsed=$((now - last_time))

    if [[ $elapsed -lt $TIMEOUT_MS ]]; then
        # Dentro del timeout, incrementar contador
        count=$((count + 1))

        if [[ $count -ge 2 ]]; then
            # Double tap detectado
            go_to_workspace_z
            # Reset
            echo "0" > "$COUNT_FILE"
            echo "$now" > "$TIME_FILE"
            exit 0
        fi
    else
        # Timeout expirado, reset contador
        count=1
    fi
else
    # Primera pulsación
    count=1
fi

# Guardar estado
echo "$count" > "$COUNT_FILE"
echo "$now" > "$TIME_FILE"
