#!/bin/bash
# Actualiza el lockscreen con el wallpaper actual de nitrogen

NITROGEN_CFG="$HOME/.config/nitrogen/bg-saved.cfg"
LOCKSCREEN="$HOME/.lockscreen.png"

# Obtener wallpaper actual
WALLPAPER=$(grep "^file=" "$NITROGEN_CFG" | cut -d'=' -f2)

# Obtener resolución
RESOLUTION=$(xrandr | grep '*' | awk '{print $1}')

if [ -f "$WALLPAPER" ]; then
    python3 << EOF
from PIL import Image

img = Image.open("$WALLPAPER")
res = "$RESOLUTION".split('x')
screen_w, screen_h = int(res[0]), int(res[1])

img_ratio = img.width / img.height
screen_ratio = screen_w / screen_h

if img_ratio > screen_ratio:
    new_h = screen_h
    new_w = int(new_h * img_ratio)
else:
    new_w = screen_w
    new_h = int(new_w / img_ratio)

img_resized = img.resize((new_w, new_h), Image.LANCZOS)
final = Image.new('RGB', (screen_w, screen_h), (0, 0, 0))
x = (screen_w - new_w) // 2
y = (screen_h - new_h) // 2
final.paste(img_resized, (x, y))
final.save("$LOCKSCREEN", "PNG")
EOF
fi
