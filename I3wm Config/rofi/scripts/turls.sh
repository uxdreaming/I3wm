#!/bin/bash
# URL - Turbo URLs
# Automatización de navegación web con rofi

URL_DIR="$HOME/.config/rofi/turls"
SAVED_DIR="$URL_DIR/saved"
THEME="$HOME/.config/rofi/turls-theme.rasi"

mkdir -p "$SAVED_DIR"

# ============================================================================
# UTILIDADES
# ============================================================================

ROFI_OPTS="-theme $THEME -normal-window"

rofi_menu() {
    local prompt="$1"
    local mesg="$2"
    shift 2
    if [[ -n "$mesg" ]]; then
        printf '%s\n' "$@" | rofi -dmenu -i -p "$prompt" -mesg "$mesg" $ROFI_OPTS
    else
        printf '%s\n' "$@" | rofi -dmenu -i -p "$prompt" $ROFI_OPTS
    fi
}

rofi_input() {
    local prompt="$1"
    local mesg="$2"
    if [[ -n "$mesg" ]]; then
        rofi -dmenu -p "$prompt" -mesg "$mesg" -lines 0 $ROFI_OPTS
    else
        rofi -dmenu -p "$prompt" -lines 0 $ROFI_OPTS
    fi
}

# ============================================================================
# GRABACIÓN
# ============================================================================

record_new_turl() {
    local name=$(rofi_input "Nombre del URL" "Ej: Buscar en Google, Login GitHub...")
    [[ -z "$name" ]] && return 1

    local filename=$(echo "$name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    local filepath="$SAVED_DIR/${filename}.json"

    if [[ -f "$filepath" ]]; then
        local overwrite=$(rofi_menu "Ya existe" "¿Sobrescribir $name?" "Sí" "No")
        [[ "$overwrite" != "Sí" ]] && return 1
    fi

    local url=$(rofi_input "URL inicial" "Ej: https://google.com")
    [[ -z "$url" ]] && return 1
    [[ "$url" != http* ]] && url="https://$url"

    local steps='[]'
    steps=$(echo "$steps" | jq --arg url "$url" '. + [{"type": "url", "value": $url}]')

    xdg-open "$url" &
    sleep 2

    while true; do
        local action=$(rofi_menu "Paso" "Grabando: $name" \
            "click - Click en elemento" \
            "input - Escribir texto" \
            "key - Presionar tecla" \
            "wait - Esperar segundos" \
            "---" \
            "FIN - Guardar y salir" \
            "CANCELAR - Descartar")

        case "$action" in
            "click"*)
                steps=$(record_click "$steps")
                ;;
            "input"*)
                steps=$(record_input "$steps")
                ;;
            "key"*)
                steps=$(record_key "$steps")
                ;;
            "wait"*)
                steps=$(record_wait "$steps")
                ;;
            "FIN"*)
                local json=$(jq -n \
                    --arg name "$name" \
                    --arg date "$(date +%Y-%m-%d)" \
                    --argjson steps "$steps" \
                    '{name: $name, created: $date, steps: $steps}')
                echo "$json" > "$filepath"
                return 0
                ;;
            "CANCELAR"*|"")
                return 1
                ;;
        esac
    done
}

record_click() {
    local steps="$1"

    # Mostrar countdown en rofi
    rofi -e "Posiciona el mouse... (3s)" $ROFI_OPTS &
    local rofi_pid=$!
    sleep 1
    kill $rofi_pid 2>/dev/null

    rofi -e "Posiciona el mouse... (2s)" $ROFI_OPTS &
    rofi_pid=$!
    sleep 1
    kill $rofi_pid 2>/dev/null

    rofi -e "Posiciona el mouse... (1s)" $ROFI_OPTS &
    rofi_pid=$!
    sleep 1
    kill $rofi_pid 2>/dev/null

    local pos=$(xdotool getmouselocation --shell)
    local x=$(echo "$pos" | grep "X=" | cut -d= -f2)
    local y=$(echo "$pos" | grep "Y=" | cut -d= -f2)

    local desc=$(rofi_input "Descripción" "Posición: x=$x y=$y")
    [[ -z "$desc" ]] && desc="Click en $x,$y"

    echo "$steps" | jq --argjson x "$x" --argjson y "$y" --arg desc "$desc" \
        '. + [{"type": "click", "x": $x, "y": $y, "desc": $desc}]'
}

record_input() {
    local steps="$1"

    local input_type=$(rofi_menu "Tipo de input" "" \
        "variable - Pedir al usuario al ejecutar" \
        "fijo - Texto fijo siempre igual")

    case "$input_type" in
        "variable"*)
            local prompt=$(rofi_input "Prompt" "¿Qué pregunta mostrar al usuario?")
            [[ -z "$prompt" ]] && prompt="Ingresa texto"
            echo "$steps" | jq --arg prompt "$prompt" \
                '. + [{"type": "input", "prompt": $prompt}]'
            ;;
        "fijo"*)
            local value=$(rofi_input "Texto fijo" "Escribe el texto a introducir")
            [[ -z "$value" ]] && { echo "$steps"; return; }
            echo "$steps" | jq --arg value "$value" \
                '. + [{"type": "input", "value": $value}]'
            ;;
        *)
            echo "$steps"
            ;;
    esac
}

record_key() {
    local steps="$1"

    local key=$(rofi_menu "Tecla" "Selecciona la tecla a presionar" \
        "Return" \
        "Tab" \
        "Escape" \
        "BackSpace" \
        "Delete" \
        "space" \
        "Up" \
        "Down" \
        "Left" \
        "Right" \
        "ctrl+a" \
        "ctrl+c" \
        "ctrl+v" \
        "ctrl+Return")

    [[ -z "$key" ]] && { echo "$steps"; return; }

    echo "$steps" | jq --arg key "$key" \
        '. + [{"type": "key", "value": $key}]'
}

record_wait() {
    local steps="$1"

    local seconds=$(rofi_input "Segundos" "¿Cuántos segundos esperar?")
    [[ -z "$seconds" ]] && seconds="1"
    [[ ! "$seconds" =~ ^[0-9]+\.?[0-9]*$ ]] && seconds="1"

    echo "$steps" | jq --argjson secs "$seconds" \
        '. + [{"type": "wait", "seconds": $secs}]'
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

execute_turl() {
    local filepath="$1"
    local steps=$(jq -c '.steps[]' "$filepath")

    while IFS= read -r step; do
        local type=$(echo "$step" | jq -r '.type')

        case "$type" in
            "url")
                local url=$(echo "$step" | jq -r '.value')
                xdg-open "$url" &
                sleep 1.5
                ;;
            "click")
                local x=$(echo "$step" | jq -r '.x')
                local y=$(echo "$step" | jq -r '.y')
                xdotool mousemove "$x" "$y"
                sleep 0.1
                xdotool click 1
                sleep 0.3
                ;;
            "input")
                local prompt=$(echo "$step" | jq -r '.prompt // empty')
                local value=$(echo "$step" | jq -r '.value // empty')

                if [[ -n "$prompt" ]]; then
                    value=$(rofi_input "$prompt" "")
                    [[ -z "$value" ]] && return 1
                fi

                sleep 0.2
                xdotool type --clearmodifiers "$value"
                ;;
            "key")
                local key=$(echo "$step" | jq -r '.value')
                sleep 0.1
                xdotool key --clearmodifiers "$key"
                sleep 0.2
                ;;
            "wait")
                local seconds=$(echo "$step" | jq -r '.seconds')
                sleep "$seconds"
                ;;
        esac
    done <<< "$steps"
}

list_turls() {
    shopt -s nullglob
    for f in "$SAVED_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local name=$(jq -r '.name' "$f")
        local steps=$(jq '.steps | length' "$f")
        echo "$name ($steps pasos)|$f"
    done
    shopt -u nullglob
}

select_and_execute() {
    local turls=$(list_turls)

    if [[ -z "$turls" ]]; then
        rofi_menu "URL" "No hay URLs guardados" "Crear nuevo URL"
        [[ $? -eq 0 ]] && record_new_turl
        return
    fi

    local options=$(echo "$turls" | cut -d'|' -f1)
    local selected=$(echo "$options" | rofi -dmenu -i -p "URL" -mesg "Selecciona un URL" $ROFI_OPTS)

    [[ -z "$selected" ]] && return

    local filepath=$(echo "$turls" | grep "^$selected|" | cut -d'|' -f2)

    [[ -f "$filepath" ]] && execute_turl "$filepath"
}

# ============================================================================
# GESTIÓN
# ============================================================================

delete_turl() {
    local turls=$(list_turls)
    [[ -z "$turls" ]] && return

    local options=$(echo "$turls" | cut -d'|' -f1)
    local selected=$(echo "$options" | rofi -dmenu -i -p "Eliminar" -mesg "Selecciona URL a eliminar" $ROFI_OPTS)

    [[ -z "$selected" ]] && return

    local filepath=$(echo "$turls" | grep "^$selected|" | cut -d'|' -f2)

    local confirm=$(rofi_menu "Confirmar" "¿Eliminar '$selected'?" "Sí" "No")
    [[ "$confirm" == "Sí" ]] && rm -f "$filepath"
}

view_turl() {
    local turls=$(list_turls)
    [[ -z "$turls" ]] && return

    local options=$(echo "$turls" | cut -d'|' -f1)
    local selected=$(echo "$options" | rofi -dmenu -i -p "Ver" -mesg "Selecciona URL" $ROFI_OPTS)

    [[ -z "$selected" ]] && return

    local filepath=$(echo "$turls" | grep "^$selected|" | cut -d'|' -f2)

    if [[ -f "$filepath" ]]; then
        local info=""
        local i=1
        while IFS= read -r step; do
            local type=$(echo "$step" | jq -r '.type')
            local detail=""
            case "$type" in
                "url") detail=$(echo "$step" | jq -r '.value') ;;
                "click") detail=$(echo "$step" | jq -r '.desc // "click"') ;;
                "input")
                    local p=$(echo "$step" | jq -r '.prompt // empty')
                    [[ -n "$p" ]] && detail="Pedir: $p" || detail="Fijo"
                    ;;
                "key") detail=$(echo "$step" | jq -r '.value') ;;
                "wait") detail="$(echo "$step" | jq -r '.seconds')s" ;;
            esac
            info+="$i. [$type] $detail\n"
            ((i++))
        done <<< "$(jq -c '.steps[]' "$filepath")"

        rofi_menu "$selected" "$(echo -e "$info")" "OK"
    fi
}

# ============================================================================
# MENÚ PRINCIPAL
# ============================================================================

main_menu() {
    local choice=$(rofi_menu "URL" "" \
        "Ejecutar URL" \
        "Nuevo URL" \
        "Ver pasos" \
        "Eliminar URL")

    case "$choice" in
        "Ejecutar"*) select_and_execute ;;
        "Nuevo"*) record_new_turl ;;
        "Ver"*) view_turl ;;
        "Eliminar"*) delete_turl ;;
    esac
}

# ============================================================================
# ENTRY POINT
# ============================================================================

if [[ -n "$1" ]]; then
    shopt -s nullglob
    for f in "$SAVED_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        name=$(jq -r '.name' "$f")
        if [[ "$name" == "$1" ]] || [[ "$(basename "$f" .json)" == "$1" ]]; then
            execute_turl "$f"
            exit 0
        fi
    done
    shopt -u nullglob
    echo "URL no encontrado: $1"
    exit 1
fi

main_menu
