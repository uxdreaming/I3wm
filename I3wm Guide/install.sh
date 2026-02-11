#!/bin/bash
# i3wm Setup Installation Script
# Ejecutar con: bash install.sh

set -e

echo "=== i3wm Setup Installation ==="
echo ""

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función para imprimir pasos
step() {
    echo -e "${BLUE}[*]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# 1. Actualizar sistema
step "Actualizando sistema..."
sudo apt update && sudo apt upgrade -y
success "Sistema actualizado"

# 2. Instalar paquetes base
step "Instalando paquetes base..."
sudo apt install -y \
    i3 \
    i3lock \
    i3status \
    rofi \
    dunst \
    picom \
    nitrogen \
    thunar \
    flameshot \
    alacritty \
    feh \
    xdotool \
    xclip \
    playerctl \
    pavucontrol \
    network-manager-gnome \
    lxappearance \
    arandr \
    papirus-icon-theme \
    breeze-cursor-theme \
    python3-pip \
    git \
    curl \
    wget
success "Paquetes base instalados"

# 3. Instalar herramientas Python
step "Instalando autotiling y swallow..."
pip3 install autotiling i3-swallow
success "Herramientas Python instaladas"

# 4. Crear directorios de configuración
step "Creando directorios de configuración..."
mkdir -p ~/.config/{i3,alacritty,dunst,picom,nitrogen,rofi,gtk-3.0}
mkdir -p ~/downloads/walls
mkdir -p ~/apps
success "Directorios creados"

# 5. Copiar configuraciones
step "Copiando configuraciones..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp -r "$SCRIPT_DIR/configs/i3/"* ~/.config/i3/
cp "$SCRIPT_DIR/configs/alacritty/alacritty.toml" ~/.config/alacritty/
cp "$SCRIPT_DIR/configs/dunst/dunstrc" ~/.config/dunst/
cp "$SCRIPT_DIR/configs/picom/picom.conf" ~/.config/picom/
cp "$SCRIPT_DIR/configs/gtk-3.0/settings.ini" ~/.config/gtk-3.0/
cp "$SCRIPT_DIR/configs/gtk-2.0/.gtkrc-2.0" ~/.gtkrc-2.0

# Hacer scripts ejecutables
chmod +x ~/.config/i3/*.sh
success "Configuraciones copiadas"

# 6. Instalar Google Chrome
step "Instalando Google Chrome..."
wget -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i /tmp/chrome.deb || sudo apt install -f -y
success "Google Chrome instalado"

# 7. Instalar VS Code
step "Instalando VS Code..."
wget -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
sudo dpkg -i /tmp/vscode.deb || sudo apt install -f -y
success "VS Code instalado"

echo ""
echo "=== Instalación completada ==="
echo ""
echo "Pasos manuales pendientes:"
echo "  1. Descargar Obsidian AppImage a ~/apps/"
echo "  2. Descargar Logseq AppImage a ~/apps/"
echo "  3. Instalar Flatpaks: flatpak install flathub com.rtosta.zapzap com.github.flxzt.rnote"
echo "  4. Descargar wallpapers a ~/downloads/walls/"
echo "  5. Reiniciar y seleccionar i3 en el login"
echo ""
