#!/bin/bash
# =============================================================================
# RIGHT CTRL SETUP - Right Ctrl → Hyper_R (Mod5 exclusive)
# =============================================================================
# Right Ctrl se convierte en un modificador independiente (Mod5).
# AltGr se quita de mod5 pero sigue produciendo caracteres especiales
# (@, #, {, }) porque eso lo maneja XKB a nivel de keysym.
#
# Debe ejecutarse DESPUÉS de setup-hyper.sh
# =============================================================================

# Limpiar mod5 (quita AltGr/ISO_Level3_Shift de mod5)
xmodmap -e "clear mod5"

# Quitar Right Ctrl del modifier control
xmodmap -e "remove control = Control_R"

# Reasignar keycode 105 (Right Ctrl) a Hyper_R
xmodmap -e "keycode 105 = Hyper_R"

# Asignar solo Hyper_R a mod5
xmodmap -e "add mod5 = Hyper_R"
