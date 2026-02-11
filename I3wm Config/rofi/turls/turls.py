#!/usr/bin/env python3
"""TURLS - Turbo URLs - Grabador de navegación"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango
import cairo
import json
import os
import subprocess
import threading
import time
from pathlib import Path
from datetime import date
import math
import base64
from io import BytesIO

# Intentar importar PIL para comparación de imágenes
try:
    from PIL import Image, ImageChops, ImageFilter
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

SAVED_DIR = Path.home() / ".config/rofi/turls/saved"
SAVED_DIR.mkdir(parents=True, exist_ok=True)
SNAP_SIZE = 60  # Tamaño de la captura alrededor del click

CSS = """
* {
    font-family: sans-serif;
    font-size: 14px;
}
window {
    background-color: #1a1a1a;
    border: 2px solid #9683a9;
}
button {
    background: #3d3d3d;
    color: #ffffff;
    border: 1px solid #505050;
    padding: 10px 20px;
    margin: 2px;
}
button:hover {
    background: #9683a9;
    color: #000000;
}
entry {
    background: #2d2d2d;
    color: #ffffff;
    border: 1px solid #505050;
    padding: 10px;
}
label {
    color: #c0c0c0;
    padding: 4px;
}
list {
    background-color: #1a1a1a;
}
list row {
    background-color: #1a1a1a;
    padding: 8px 12px;
}
list row:selected {
    background-color: #9683a9;
}
list row:selected label {
    color: #000000;
}
.title {
    font-size: 16px;
    font-weight: bold;
    color: #9683a9;
    padding: 8px;
}
.info {
    font-size: 13px;
    color: #888888;
}
.recording {
    background-color: #4a1a1a;
}
.icon-btn {
    background: transparent;
    border: none;
    padding: 2px 6px;
    margin: 0;
    min-width: 0;
    opacity: 0.6;
}
.icon-btn:hover {
    opacity: 1;
    background: rgba(150, 131, 169, 0.3);
}
.small-btn {
    padding: 6px 14px;
    font-size: 13px;
}
.step-item {
    font-size: 12px;
    padding: 2px 0;
}
.overlay-window {
    background-color: rgba(26, 26, 26, 0.95);
    border-radius: 12px;
}
.step-label {
    font-size: 18px;
    font-weight: bold;
    color: #9683a9;
}
.step-desc {
    font-size: 14px;
    color: #e0e0e0;
}
.countdown-label {
    font-size: 72px;
    font-weight: bold;
    color: #9683a9;
}
.typing-label {
    font-size: 24px;
    font-family: monospace;
    color: #9683a9;
    letter-spacing: 4px;
}
"""


def get_screen_size():
    """Obtiene el tamaño de la pantalla"""
    try:
        out = subprocess.run(["xdotool", "getdisplaygeometry"],
                            capture_output=True, text=True)
        parts = out.stdout.strip().split()
        return int(parts[0]), int(parts[1])
    except:
        return 1920, 1080  # Fallback


def get_mouse_pos():
    """Obtiene posición actual del mouse"""
    out = subprocess.run(["xdotool", "getmouselocation", "--shell"],
                        capture_output=True, text=True)
    x = y = 0
    for line in out.stdout.split("\n"):
        if line.startswith("X="):
            x = int(line.split("=")[1])
        elif line.startswith("Y="):
            y = int(line.split("=")[1])
    return x, y


def coords_to_percent(x, y):
    """Convierte coordenadas absolutas a porcentajes"""
    sw, sh = get_screen_size()
    return (x / sw, y / sh)


def percent_to_coords(px, py):
    """Convierte porcentajes a coordenadas absolutas"""
    sw, sh = get_screen_size()
    return (int(px * sw), int(py * sh))


def wait_for_click():
    """Espera a que el usuario haga click y retorna la posición"""
    proc = subprocess.Popen(
        ["xinput", "test-xi2", "--root"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    try:
        for line in proc.stdout:
            if "RawButtonPress" in line:
                proc.terminate()
                time.sleep(0.05)
                return get_mouse_pos()
    except:
        pass
    finally:
        proc.terminate()

    return None, None


def capture_region(x, y, size=SNAP_SIZE):
    """Captura una región de la pantalla alrededor de un punto"""
    if not HAS_PIL:
        return None

    half = size // 2
    x1 = max(0, x - half)
    y1 = max(0, y - half)

    try:
        # Usar import de ImageMagick para capturar
        result = subprocess.run(
            ["import", "-window", "root", "-crop", f"{size}x{size}+{x1}+{y1}", "png:-"],
            capture_output=True,
            timeout=2
        )
        if result.returncode == 0:
            return base64.b64encode(result.stdout).decode('utf-8')
    except:
        pass
    return None


def detect_element_properties(x, y):
    """Detecta propiedades del elemento en la posición (texto, color)"""
    props = {}

    # Capturar región más grande para OCR (120x60 píxeles)
    half_w, half_h = 60, 30
    x1 = max(0, x - half_w)
    y1 = max(0, y - half_h)

    try:
        # Capturar imagen para análisis
        result = subprocess.run(
            ["import", "-window", "root", "-crop", f"120x60+{x1}+{y1}", "png:-"],
            capture_output=True,
            timeout=2
        )
        if result.returncode != 0:
            return props

        img_data = result.stdout

        # Detectar texto con OCR
        try:
            ocr_result = subprocess.run(
                ["tesseract", "stdin", "stdout", "-l", "eng+spa", "--psm", "7"],
                input=img_data,
                capture_output=True,
                timeout=3
            )
            text = ocr_result.stdout.decode('utf-8').strip()
            # Limpiar texto (quitar caracteres extraños)
            text = ''.join(c for c in text if c.isalnum() or c.isspace()).strip()
            if text and len(text) >= 2:
                props["text"] = text
        except:
            pass

        # Detectar color dominante
        if HAS_PIL:
            try:
                img = Image.open(BytesIO(img_data))
                # Obtener color del centro
                cx, cy = img.width // 2, img.height // 2
                # Promediar área pequeña del centro
                colors = []
                for dx in range(-3, 4):
                    for dy in range(-3, 4):
                        px = min(max(0, cx + dx), img.width - 1)
                        py = min(max(0, cy + dy), img.height - 1)
                        colors.append(img.getpixel((px, py)))

                # Promediar colores
                if colors:
                    if isinstance(colors[0], tuple):
                        avg_r = sum(c[0] for c in colors) // len(colors)
                        avg_g = sum(c[1] for c in colors) // len(colors)
                        avg_b = sum(c[2] for c in colors) // len(colors)
                        props["color"] = f"#{avg_r:02x}{avg_g:02x}{avg_b:02x}"
            except:
                pass

    except:
        pass

    return props


def verify_element_properties(x, y, saved_props):
    """Verifica si las propiedades actuales coinciden con las guardadas"""
    if not saved_props:
        return True, None

    current = detect_element_properties(x, y)
    mismatches = []

    # Verificar texto
    saved_text = saved_props.get("text", "").lower()
    current_text = current.get("text", "").lower()

    if saved_text and current_text:
        # Comparar si el texto guardado está contenido en el actual o viceversa
        if saved_text not in current_text and current_text not in saved_text:
            # Calcular similitud simple
            common = sum(1 for c in saved_text if c in current_text)
            similarity = common / max(len(saved_text), 1)
            if similarity < 0.5:
                mismatches.append(f"Texto: esperaba '{saved_props['text']}', encontró '{current.get('text', '?')}'")

    # Verificar color (tolerancia de 50 en cada canal)
    saved_color = saved_props.get("color")
    current_color = current.get("color")

    if saved_color and current_color:
        try:
            sr = int(saved_color[1:3], 16)
            sg = int(saved_color[3:5], 16)
            sb = int(saved_color[5:7], 16)
            cr = int(current_color[1:3], 16)
            cg = int(current_color[3:5], 16)
            cb = int(current_color[5:7], 16)

            diff = abs(sr - cr) + abs(sg - cg) + abs(sb - cb)
            if diff > 150:  # Tolerancia total
                mismatches.append(f"Color: esperaba {saved_color}, encontró {current_color}")
        except:
            pass

    if mismatches:
        return False, mismatches

    return True, None


def compare_regions(snap_b64, x, y, threshold=0.75):
    """Compara una captura guardada con la región actual. Retorna True si son similares."""
    if not HAS_PIL or not snap_b64:
        return True  # Si no hay PIL o snapshot, continuar sin verificar

    try:
        # Decodificar imagen guardada
        saved_img = Image.open(BytesIO(base64.b64decode(snap_b64)))

        # Capturar región actual
        current_b64 = capture_region(x, y, saved_img.width)
        if not current_b64:
            return True  # No se pudo capturar, continuar

        current_img = Image.open(BytesIO(base64.b64decode(current_b64)))

        # Asegurar mismo tamaño
        if saved_img.size != current_img.size:
            current_img = current_img.resize(saved_img.size)

        # Convertir a escala de grises para comparación
        saved_gray = saved_img.convert('L')
        current_gray = current_img.convert('L')

        # Calcular diferencia
        diff = ImageChops.difference(saved_gray, current_gray)

        # Calcular similitud (0-1)
        diff_pixels = list(diff.getdata())
        total_diff = sum(diff_pixels)
        max_diff = 255 * len(diff_pixels)
        similarity = 1 - (total_diff / max_diff)

        return similarity >= threshold

    except Exception as e:
        return True  # En caso de error, continuar


# ==================== CLICK INDICATOR WINDOW ====================

class ClickIndicator(Gtk.Window):
    """Ventana transparente que muestra un círculo animado al hacer click"""

    def __init__(self):
        super().__init__(type=Gtk.WindowType.POPUP)
        self.set_app_paintable(True)
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_keep_above(True)
        self.set_accept_focus(False)  # No robar foco

        # Hacer click-through
        self.connect("realize", self._make_click_through)

        # Transparencia
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.set_default_size(80, 80)
        self.connect("draw", self.on_draw)

        self.animation_progress = 0
        self.is_animating = False

    def on_draw(self, widget, cr):
        # Fondo transparente
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)

        if self.is_animating:
            # Centro del círculo
            cx, cy = 40, 40

            # Círculo exterior (anillo que se expande)
            progress = self.animation_progress
            radius = 15 + (25 * progress)
            alpha = 1.0 - progress

            cr.set_source_rgba(0.59, 0.51, 0.66, alpha * 0.8)  # #9683a9
            cr.set_line_width(3)
            cr.arc(cx, cy, radius, 0, 2 * math.pi)
            cr.stroke()

            # Círculo central (punto de click)
            cr.set_source_rgba(0.59, 0.51, 0.66, 0.9)
            cr.arc(cx, cy, 8, 0, 2 * math.pi)
            cr.fill()

            # Efecto de "presión" - círculo más pequeño
            if progress < 0.3:
                inner_alpha = 1.0 - (progress / 0.3)
                cr.set_source_rgba(1, 1, 1, inner_alpha * 0.6)
                cr.arc(cx, cy, 5, 0, 2 * math.pi)
                cr.fill()

        return True

    def show_at(self, x, y):
        """Muestra el indicador en la posición especificada y anima"""
        self.move(x - 40, y - 40)
        self.animation_progress = 0
        self.is_animating = True
        self.show_all()
        GLib.timeout_add(16, self._animate)  # ~60fps

    def _animate(self):
        if not self.is_animating:
            return False

        self.animation_progress += 0.08
        self.queue_draw()

        if self.animation_progress >= 1.0:
            self.is_animating = False
            self.hide()
            return False

        return True

    def _make_click_through(self, widget):
        """Hace la ventana click-through"""
        window = self.get_window()
        if window:
            region = cairo.Region(cairo.RectangleInt(0, 0, 0, 0))
            window.input_shape_combine_region(region, 0, 0)


# ==================== STATUS OVERLAY WINDOW ====================

class StatusOverlay(Gtk.Window):
    """Ventana flotante que muestra el estado actual de la ejecución"""

    def __init__(self):
        super().__init__(type=Gtk.WindowType.POPUP)
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_accept_focus(False)  # No robar foco
        self.set_keep_above(True)

        # Hacer click-through (los clicks pasan a través)
        self.connect("realize", self._make_click_through)

        # Transparencia
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self.connect("draw", self.on_draw_background)

        # Layout principal
        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.vbox.set_margin_top(20)
        self.vbox.set_margin_bottom(20)
        self.vbox.set_margin_start(25)
        self.vbox.set_margin_end(25)

        # Icono de estado
        self.icon_label = Gtk.Label()
        self.icon_label.set_markup('<span font="32">⚡</span>')
        self.vbox.pack_start(self.icon_label, False, False, 0)

        # Título del paso actual
        self.step_label = Gtk.Label()
        self.step_label.get_style_context().add_class("step-label")
        self.vbox.pack_start(self.step_label, False, False, 0)

        # Descripción
        self.desc_label = Gtk.Label()
        self.desc_label.get_style_context().add_class("step-desc")
        self.desc_label.set_line_wrap(True)
        self.desc_label.set_max_width_chars(40)
        self.vbox.pack_start(self.desc_label, False, False, 0)

        # Área para countdown o typing indicator
        self.extra_label = Gtk.Label()
        self.vbox.pack_start(self.extra_label, False, False, 10)

        # Progress bar
        self.progress = Gtk.ProgressBar()
        self.progress.set_size_request(250, 8)
        self.vbox.pack_start(self.progress, False, False, 5)

        self.add(self.vbox)

        # Estado
        self.countdown_remaining = 0
        self.typing_text = ""
        self.typing_index = 0

    def on_draw_background(self, widget, cr):
        """Dibuja fondo con bordes redondeados"""
        width = widget.get_allocated_width()
        height = widget.get_allocated_height()
        radius = 15

        # Fondo semi-transparente con bordes redondeados
        cr.set_source_rgba(0.1, 0.1, 0.1, 0.92)

        # Dibujar rectángulo redondeado
        cr.move_to(radius, 0)
        cr.line_to(width - radius, 0)
        cr.arc(width - radius, radius, radius, -math.pi/2, 0)
        cr.line_to(width, height - radius)
        cr.arc(width - radius, height - radius, radius, 0, math.pi/2)
        cr.line_to(radius, height)
        cr.arc(radius, height - radius, radius, math.pi/2, math.pi)
        cr.line_to(0, radius)
        cr.arc(radius, radius, radius, math.pi, 3*math.pi/2)
        cr.close_path()
        cr.fill()

        # Borde
        cr.set_source_rgba(0.59, 0.51, 0.66, 0.8)  # #9683a9
        cr.set_line_width(2)
        cr.move_to(radius, 0)
        cr.line_to(width - radius, 0)
        cr.arc(width - radius, radius, radius, -math.pi/2, 0)
        cr.line_to(width, height - radius)
        cr.arc(width - radius, height - radius, radius, 0, math.pi/2)
        cr.line_to(radius, height)
        cr.arc(radius, height - radius, radius, math.pi/2, math.pi)
        cr.line_to(0, radius)
        cr.arc(radius, radius, radius, math.pi, 3*math.pi/2)
        cr.close_path()
        cr.stroke()

        return False

    def _make_click_through(self, widget):
        """Hace la ventana click-through (los eventos pasan a través)"""
        window = self.get_window()
        if window:
            # Crear región vacía para input - clicks pasan a través
            region = cairo.Region(cairo.RectangleInt(0, 0, 0, 0))
            window.input_shape_combine_region(region, 0, 0)

    def position_on_screen(self):
        """Posiciona la ventana en la esquina superior derecha"""
        display = Gdk.Display.get_default()
        monitor = display.get_primary_monitor()
        geometry = monitor.get_geometry()

        # Calcular tamaño necesario
        self.set_default_size(300, 180)

        # Posicionar en esquina superior derecha con margen
        x = geometry.x + geometry.width - 320
        y = geometry.y + 20
        self.move(x, y)

    def show_step(self, icon, title, description, current, total):
        """Muestra información del paso actual"""
        self.icon_label.set_markup(f'<span font="32">{icon}</span>')
        self.step_label.set_markup(f'<span color="#9683a9">{title}</span>')
        self.desc_label.set_text(description)
        self.extra_label.set_text("")

        # Actualizar progreso
        progress = current / total if total > 0 else 0
        self.progress.set_fraction(progress)

        self.position_on_screen()
        self.show_all()

        # Procesar eventos GTK
        while Gtk.events_pending():
            Gtk.main_iteration()

    def show_countdown(self, seconds):
        """Muestra countdown animado"""
        self.countdown_remaining = seconds
        self._update_countdown()

    def _update_countdown(self):
        if self.countdown_remaining <= 0:
            return False

        self.extra_label.set_markup(
            f'<span font="48" color="#9683a9">{self.countdown_remaining:.1f}</span>'
        )

        # Procesar eventos GTK
        while Gtk.events_pending():
            Gtk.main_iteration()

        return True

    def show_typing(self, text, is_password=False):
        """Muestra indicador de escritura"""
        if is_password:
            display = "●" * len(text)
        else:
            # Mostrar texto truncado si es muy largo
            display = text[:25] + "..." if len(text) > 25 else text

        self.extra_label.set_markup(
            f'<span font="16" font_family="monospace" color="#9683a9">{display}</span>'
        )

        while Gtk.events_pending():
            Gtk.main_iteration()


# ==================== MAIN APP ====================

class TurlsApp(Gtk.Window):
    def __init__(self):
        super().__init__(title="TURLS")
        self.set_default_size(550, 400)
        self.set_decorated(False)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_keep_above(True)

        self.recording = None
        self.edit_path = None

        # Componentes de visualización
        self.click_indicator = ClickIndicator()
        self.status_overlay = StatusOverlay()

        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.connect("key-press-event", self.on_key)
        self.show_main()

    def on_key(self, w, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
        return False

    def clear(self):
        for c in self.get_children():
            self.remove(c)

    # ==================== PANTALLA PRINCIPAL ====================

    def show_main(self):
        self.clear()
        self.edit_path = None

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        turls = self.get_turls()

        if turls:
            lbl_info = Gtk.Label(label="Click para ejecutar", xalign=0)
            lbl_info.get_style_context().add_class("info")
            vbox.pack_start(lbl_info, False, False, 0)

            listbox = Gtk.ListBox()
            listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)

            for name, path in turls:
                row = Gtk.ListBoxRow()
                row.path = path

                hbox_row = Gtk.Box(spacing=8)

                # Nombre del workflow
                lbl = Gtk.Label(label=name, xalign=0)
                hbox_row.pack_start(lbl, True, True, 0)

                # Botón archivar (icono) - va segundo
                btn_archive = Gtk.Button(label="📦")
                btn_archive.set_relief(Gtk.ReliefStyle.NONE)
                btn_archive.get_style_context().add_class("icon-btn")
                btn_archive.connect("clicked", lambda x, p=path: self.on_archive_clicked(p))
                hbox_row.pack_end(btn_archive, False, False, 0)

                # Botón editar (icono) - va primero
                btn_edit = Gtk.Button(label="✏")
                btn_edit.set_relief(Gtk.ReliefStyle.NONE)
                btn_edit.get_style_context().add_class("icon-btn")
                btn_edit.connect("clicked", lambda x, p=path: self.on_edit_clicked(p))
                hbox_row.pack_end(btn_edit, False, False, 0)

                row.add(hbox_row)
                row.connect("activate", lambda r: self.run_turl(r.path))
                listbox.add(row)

            listbox.connect("row-activated", self.on_run)

            scroll = Gtk.ScrolledWindow()
            scroll.set_min_content_height(250)
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroll.add(listbox)
            vbox.pack_start(scroll, True, True, 0)
        else:
            lbl = Gtk.Label(label="No hay URLs guardadas")
            vbox.pack_start(lbl, True, True, 20)

        # Botón nuevo (más pequeño)
        hbox = Gtk.Box(spacing=6)
        hbox.set_halign(Gtk.Align.END)

        btn_new = Gtk.Button(label="Nuevo")
        btn_new.get_style_context().add_class("small-btn")
        btn_new.connect("clicked", lambda x: self.show_new())
        hbox.pack_start(btn_new, False, False, 0)

        vbox.pack_end(hbox, False, False, 0)

        self.add(vbox)
        self.show_all()

    def on_edit_clicked(self, path):
        """Editar workflow directamente"""
        self.show_edit_steps(path)

    def on_archive_clicked(self, path):
        """Archivar workflow (mover a carpeta archive)"""
        archive_dir = SAVED_DIR / "archive"
        archive_dir.mkdir(exist_ok=True)
        src = Path(path)
        dst = archive_dir / src.name
        src.rename(dst)
        self.show_main()

    def get_turls(self):
        result = []
        for f in sorted(SAVED_DIR.glob("*.json")):
            try:
                data = json.loads(f.read_text())
                result.append((data["name"], str(f)))
            except:
                pass
        return result

    def on_run(self, listbox, row):
        self.run_turl(row.path)

    # ==================== NUEVA URL ====================

    def show_new(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl_title = Gtk.Label(label="Nueva URL")
        lbl_title.get_style_context().add_class("title")
        vbox.pack_start(lbl_title, False, False, 0)

        # Nombre
        lbl1 = Gtk.Label(label="Nombre:", xalign=0)
        vbox.pack_start(lbl1, False, False, 0)

        self.entry_name = Gtk.Entry()
        self.entry_name.set_placeholder_text("Ej: Buscar en Google")
        vbox.pack_start(self.entry_name, False, False, 0)

        # URL
        lbl2 = Gtk.Label(label="URL inicial:", xalign=0)
        vbox.pack_start(lbl2, False, False, 0)

        self.entry_url = Gtk.Entry()
        self.entry_url.set_placeholder_text("https://google.com")
        vbox.pack_start(self.entry_url, False, False, 0)

        # Botones
        hbox = Gtk.Box(spacing=6)
        hbox.set_halign(Gtk.Align.END)

        btn_cancel = Gtk.Button(label="Cancelar")
        btn_cancel.connect("clicked", lambda x: self.show_main())
        hbox.pack_start(btn_cancel, False, False, 0)

        btn_next = Gtk.Button(label="Crear y grabar")
        btn_next.connect("clicked", self.start_recording)
        hbox.pack_start(btn_next, False, False, 0)

        vbox.pack_end(hbox, False, False, 0)

        self.add(vbox)
        self.show_all()
        self.entry_name.grab_focus()

    def start_recording(self, btn):
        name = self.entry_name.get_text().strip()
        url = self.entry_url.get_text().strip()

        if not name or not url:
            return

        if not url.startswith("http"):
            url = "https://" + url

        self.edit_path = None
        self.recording = {
            "name": name,
            "created": str(date.today()),
            "steps": [{"type": "url", "value": url}]
        }

        # Abrir URL
        subprocess.Popen(["xdg-open", url])

        # Esperar a que cargue y mostrar panel de grabación
        GLib.timeout_add(2000, self.show_recording_panel)

    # ==================== PANEL DE GRABACIÓN ====================

    def show_recording_panel(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        # Título
        name = self.recording["name"]
        lbl_title = Gtk.Label(label=f"Grabando: {name}")
        lbl_title.get_style_context().add_class("title")
        vbox.pack_start(lbl_title, False, False, 0)

        # Contador de pasos
        n_steps = len(self.recording["steps"])
        self.lbl_steps = Gtk.Label(label=f"Pasos grabados: {n_steps}")
        self.lbl_steps.get_style_context().add_class("info")
        vbox.pack_start(self.lbl_steps, False, False, 5)

        # Instrucciones
        lbl_info = Gtk.Label(label="Selecciona qué grabar:")
        vbox.pack_start(lbl_info, False, False, 10)

        # Botones de acción
        btn_click = Gtk.Button(label="Grabar CLICK")
        btn_click.connect("clicked", lambda x: self.record_click())
        vbox.pack_start(btn_click, False, False, 0)

        btn_text = Gtk.Button(label="Grabar TEXTO")
        btn_text.connect("clicked", lambda x: self.show_text_options())
        vbox.pack_start(btn_text, False, False, 0)

        btn_key = Gtk.Button(label="Grabar TECLA")
        btn_key.connect("clicked", lambda x: self.show_key_options())
        vbox.pack_start(btn_key, False, False, 0)

        btn_scroll = Gtk.Button(label="Grabar SCROLL")
        btn_scroll.connect("clicked", lambda x: self.show_scroll_options())
        vbox.pack_start(btn_scroll, False, False, 0)

        btn_wait = Gtk.Button(label="Agregar ESPERA")
        btn_wait.connect("clicked", lambda x: self.show_wait_dialog())
        vbox.pack_start(btn_wait, False, False, 0)

        # Separador
        vbox.pack_start(Gtk.Separator(), False, False, 10)

        # Botones finales
        hbox = Gtk.Box(spacing=6)
        hbox.set_halign(Gtk.Align.END)

        btn_cancel = Gtk.Button(label="Cancelar")
        btn_cancel.connect("clicked", lambda x: self.show_main())
        hbox.pack_start(btn_cancel, False, False, 0)

        btn_save = Gtk.Button(label="GUARDAR")
        btn_save.connect("clicked", self.save_recording)
        hbox.pack_start(btn_save, False, False, 0)

        vbox.pack_end(hbox, False, False, 0)

        self.add(vbox)
        self.show_all()
        return False

    def update_step_count(self):
        n = len(self.recording["steps"])
        self.lbl_steps.set_text(f"Pasos grabados: {n}")

    # ==================== GRABAR CLICK ====================

    def record_click(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        vbox.set_valign(Gtk.Align.CENTER)
        vbox.set_halign(Gtk.Align.CENTER)

        lbl = Gtk.Label(label="HAZ CLICK donde quieras")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 10)

        lbl2 = Gtk.Label(label="(en el navegador)")
        lbl2.get_style_context().add_class("info")
        vbox.pack_start(lbl2, False, False, 0)

        self.add(vbox)
        self.show_all()

        # Esperar click en hilo separado
        thread = threading.Thread(target=self._wait_and_record_click)
        thread.daemon = True
        thread.start()

    def _wait_and_record_click(self):
        x, y = wait_for_click()
        if x is not None:
            # Convertir a porcentajes para adaptarse a cambios de resolución
            px, py = coords_to_percent(x, y)
            # Capturar snapshot de la región para verificación
            snap = capture_region(x, y)
            # Detectar propiedades del elemento (texto, color)
            props = detect_element_properties(x, y)

            step = {
                "type": "click",
                "x": x,  # Absoluto (legacy/referencia)
                "y": y,
                "px": px,  # Porcentaje
                "py": py
            }
            if snap:
                step["snap"] = snap
            if props:
                step["props"] = props

            self.recording["steps"].append(step)
            GLib.idle_add(self.show_recording_panel)

    # ==================== GRABAR TEXTO ====================

    def show_text_options(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Tipo de texto")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 0)

        btn_var = Gtk.Button(label="Pedir al ejecutar")
        btn_var.connect("clicked", lambda x: self.show_text_prompt_dialog())
        vbox.pack_start(btn_var, False, False, 0)

        lbl_var = Gtk.Label(label="Te preguntará qué escribir cada vez")
        lbl_var.get_style_context().add_class("info")
        vbox.pack_start(lbl_var, False, False, 0)

        btn_fixed = Gtk.Button(label="Texto fijo")
        btn_fixed.connect("clicked", lambda x: self.show_text_fixed_dialog())
        vbox.pack_start(btn_fixed, False, False, 0)

        lbl_fixed = Gtk.Label(label="Siempre escribirá lo mismo")
        lbl_fixed.get_style_context().add_class("info")
        vbox.pack_start(lbl_fixed, False, False, 0)

        btn_pass = Gtk.Button(label="Contraseña (seguro)")
        btn_pass.connect("clicked", lambda x: self.show_password_dialog())
        vbox.pack_start(btn_pass, False, False, 0)

        lbl_pass = Gtk.Label(label="Pide al ejecutar, NO se guarda")
        lbl_pass.get_style_context().add_class("info")
        vbox.pack_start(lbl_pass, False, False, 0)

        btn_back = Gtk.Button(label="Volver")
        btn_back.connect("clicked", lambda x: self.show_recording_panel())
        vbox.pack_end(btn_back, False, False, 10)

        self.add(vbox)
        self.show_all()

    def show_text_prompt_dialog(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="¿Qué pregunta mostrar?")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 0)

        self.entry_prompt = Gtk.Entry()
        self.entry_prompt.set_placeholder_text("Ej: ¿Qué quieres buscar?")
        vbox.pack_start(self.entry_prompt, False, False, 0)

        hbox = Gtk.Box(spacing=6)
        hbox.set_halign(Gtk.Align.END)

        btn_back = Gtk.Button(label="Cancelar")
        btn_back.connect("clicked", lambda x: self.show_recording_panel())
        hbox.pack_start(btn_back, False, False, 0)

        btn_ok = Gtk.Button(label="Agregar")
        btn_ok.connect("clicked", self.add_text_prompt)
        hbox.pack_start(btn_ok, False, False, 0)

        vbox.pack_end(hbox, False, False, 0)

        self.add(vbox)
        self.show_all()

    def add_text_prompt(self, btn):
        prompt = self.entry_prompt.get_text().strip() or "Escribe texto"
        self.recording["steps"].append({
            "type": "input",
            "prompt": prompt
        })
        self.show_recording_panel()

    def show_text_fixed_dialog(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Texto a escribir:")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 0)

        self.entry_fixed = Gtk.Entry()
        vbox.pack_start(self.entry_fixed, False, False, 0)

        hbox = Gtk.Box(spacing=6)
        hbox.set_halign(Gtk.Align.END)

        btn_back = Gtk.Button(label="Cancelar")
        btn_back.connect("clicked", lambda x: self.show_recording_panel())
        hbox.pack_start(btn_back, False, False, 0)

        btn_ok = Gtk.Button(label="Agregar")
        btn_ok.connect("clicked", self.add_text_fixed)
        hbox.pack_start(btn_ok, False, False, 0)

        vbox.pack_end(hbox, False, False, 0)

        self.add(vbox)
        self.show_all()

    def add_text_fixed(self, btn):
        text = self.entry_fixed.get_text()
        if text:
            self.recording["steps"].append({
                "type": "input",
                "value": text
            })
        self.show_recording_panel()

    def show_password_dialog(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Etiqueta para la contraseña")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 0)

        lbl2 = Gtk.Label(label="Ej: 'Contraseña de Gmail'")
        lbl2.get_style_context().add_class("info")
        vbox.pack_start(lbl2, False, False, 0)

        self.entry_pass_label = Gtk.Entry()
        self.entry_pass_label.set_placeholder_text("Contraseña")
        vbox.pack_start(self.entry_pass_label, False, False, 0)

        hbox = Gtk.Box(spacing=6)
        hbox.set_halign(Gtk.Align.END)

        btn_back = Gtk.Button(label="Cancelar")
        btn_back.connect("clicked", lambda x: self.show_recording_panel())
        hbox.pack_start(btn_back, False, False, 0)

        btn_ok = Gtk.Button(label="Agregar")
        btn_ok.connect("clicked", self.add_password)
        hbox.pack_start(btn_ok, False, False, 0)

        vbox.pack_end(hbox, False, False, 0)

        self.add(vbox)
        self.show_all()

    def add_password(self, btn):
        label = self.entry_pass_label.get_text().strip() or "Contraseña"
        self.recording["steps"].append({
            "type": "password",
            "prompt": label
        })
        self.show_recording_panel()

    # ==================== GRABAR TECLA ====================

    def show_key_options(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Selecciona tecla")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 5)

        keys = [
            ("Enter", "Return"),
            ("Tab", "Tab"),
            ("Escape", "Escape"),
            ("Borrar", "BackSpace"),
            ("Espacio", "space"),
            ("Ctrl+A (Seleccionar todo)", "ctrl+a"),
            ("Ctrl+C (Copiar)", "ctrl+c"),
            ("Ctrl+V (Pegar)", "ctrl+v"),
        ]

        for label, key in keys:
            btn = Gtk.Button(label=label)
            btn.connect("clicked", lambda x, k=key: self.add_key(k))
            vbox.pack_start(btn, False, False, 0)

        btn_back = Gtk.Button(label="Volver")
        btn_back.connect("clicked", lambda x: self.show_recording_panel())
        vbox.pack_end(btn_back, False, False, 10)

        self.add(vbox)
        self.show_all()

    def add_key(self, key):
        self.recording["steps"].append({
            "type": "key",
            "value": key
        })
        self.show_recording_panel()

    # ==================== SCROLL ====================

    def show_scroll_options(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Dirección del scroll")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 5)

        btn_down = Gtk.Button(label="Scroll ABAJO")
        btn_down.connect("clicked", lambda x: self.show_scroll_amount("down"))
        vbox.pack_start(btn_down, False, False, 0)

        btn_up = Gtk.Button(label="Scroll ARRIBA")
        btn_up.connect("clicked", lambda x: self.show_scroll_amount("up"))
        vbox.pack_start(btn_up, False, False, 0)

        btn_back = Gtk.Button(label="Volver")
        btn_back.connect("clicked", lambda x: self.show_recording_panel())
        vbox.pack_end(btn_back, False, False, 10)

        self.add(vbox)
        self.show_all()

    def show_scroll_amount(self, direction):
        self.scroll_direction = direction
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Cantidad de scroll (1-10)")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 0)

        lbl2 = Gtk.Label(label="1 = poco, 5 = medio, 10 = mucho")
        lbl2.get_style_context().add_class("info")
        vbox.pack_start(lbl2, False, False, 0)

        self.entry_scroll = Gtk.Entry()
        self.entry_scroll.set_text("3")
        vbox.pack_start(self.entry_scroll, False, False, 0)

        hbox = Gtk.Box(spacing=6)
        hbox.set_halign(Gtk.Align.END)

        btn_back = Gtk.Button(label="Cancelar")
        btn_back.connect("clicked", lambda x: self.show_recording_panel())
        hbox.pack_start(btn_back, False, False, 0)

        btn_ok = Gtk.Button(label="Agregar")
        btn_ok.connect("clicked", self.add_scroll)
        hbox.pack_start(btn_ok, False, False, 0)

        vbox.pack_end(hbox, False, False, 0)

        self.add(vbox)
        self.show_all()

    def add_scroll(self, btn):
        try:
            amount = int(self.entry_scroll.get_text())
            amount = max(1, min(10, amount))
        except:
            amount = 3

        self.recording["steps"].append({
            "type": "scroll",
            "direction": self.scroll_direction,
            "amount": amount
        })
        self.show_recording_panel()

    # ==================== ESPERA ====================

    def show_wait_dialog(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Segundos a esperar:")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 0)

        self.entry_wait = Gtk.Entry()
        self.entry_wait.set_text("1")
        vbox.pack_start(self.entry_wait, False, False, 0)

        hbox = Gtk.Box(spacing=6)
        hbox.set_halign(Gtk.Align.END)

        btn_back = Gtk.Button(label="Cancelar")
        btn_back.connect("clicked", lambda x: self.show_recording_panel())
        hbox.pack_start(btn_back, False, False, 0)

        btn_ok = Gtk.Button(label="Agregar")
        btn_ok.connect("clicked", self.add_wait)
        hbox.pack_start(btn_ok, False, False, 0)

        vbox.pack_end(hbox, False, False, 0)

        self.add(vbox)
        self.show_all()

    def add_wait(self, btn):
        try:
            secs = float(self.entry_wait.get_text())
        except:
            secs = 1
        self.recording["steps"].append({
            "type": "wait",
            "seconds": secs
        })
        self.show_recording_panel()

    # ==================== GUARDAR ====================

    def save_recording(self, btn):
        name = self.recording["name"]
        fname = "".join(c if c.isalnum() else "-" for c in name.lower())
        path = SAVED_DIR / f"{fname}.json"
        path.write_text(json.dumps(self.recording, indent=2))
        self.show_main()

    # ==================== EDITAR ====================

    def show_edit_select(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Selecciona URL a editar")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 5)

        for name, path in self.get_turls():
            btn = Gtk.Button(label=name)
            btn.connect("clicked", lambda x, p=path: self.show_edit_steps(p))
            vbox.pack_start(btn, False, False, 0)

        btn_back = Gtk.Button(label="Volver")
        btn_back.connect("clicked", lambda x: self.show_main())
        vbox.pack_end(btn_back, False, False, 10)

        self.add(vbox)
        self.show_all()

    def show_edit_steps(self, path):
        self.edit_path = path
        data = json.loads(Path(path).read_text())
        self.recording = data

        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        vbox.set_margin_top(10)
        vbox.set_margin_bottom(10)
        vbox.set_margin_start(12)
        vbox.set_margin_end(12)

        lbl = Gtk.Label(label=f"Editando: {data['name']}")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 2)

        # TreeView con drag and drop
        scroll = Gtk.ScrolledWindow()
        scroll.set_min_content_height(200)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)

        # ListStore: index, descripción
        self.steps_store = Gtk.ListStore(int, str)
        for i, step in enumerate(data["steps"]):
            desc = self._step_description(i, step)
            self.steps_store.append([i, desc])

        self.steps_tree = Gtk.TreeView(model=self.steps_store)
        self.steps_tree.set_headers_visible(False)
        self.steps_tree.set_reorderable(True)  # Drag and drop nativo
        self.steps_store.connect("row-deleted", self.on_steps_reordered)

        renderer = Gtk.CellRendererText()
        column = Gtk.TreeViewColumn("Paso", renderer, text=1)
        self.steps_tree.append_column(column)

        scroll.add(self.steps_tree)
        vbox.pack_start(scroll, True, True, 0)

        # Botones
        hbox_btns = Gtk.Box(spacing=4)
        hbox_btns.set_halign(Gtk.Align.END)

        btn_add = Gtk.Button(label="+ Paso")
        btn_add.get_style_context().add_class("small-btn")
        btn_add.connect("clicked", lambda x: self.add_step_to_edit())
        hbox_btns.pack_start(btn_add, False, False, 0)

        btn_back = Gtk.Button(label="Guardar")
        btn_back.get_style_context().add_class("small-btn")
        btn_back.connect("clicked", lambda x: self.save_edit())
        hbox_btns.pack_start(btn_back, False, False, 0)

        vbox.pack_end(hbox_btns, False, False, 0)

        self.add(vbox)
        self.show_all()

    def _step_description(self, i, step):
        """Genera descripción compacta de un paso"""
        t = step["type"]
        if t == "url":
            return f"{i+1}. 🌐 {step['value'][:30]}"
        elif t == "click":
            return f"{i+1}. 👆 ({step['x']}, {step['y']})"
        elif t == "input":
            if "prompt" in step:
                return f"{i+1}. ✏ [{step['prompt'][:15]}]"
            else:
                return f"{i+1}. ✏ \"{step.get('value', '')[:15]}\""
        elif t == "key":
            return f"{i+1}. ⌨ {step['value']}"
        elif t == "password":
            return f"{i+1}. 🔐 [{step['prompt'][:15]}]"
        elif t == "scroll":
            dir_txt = "↓" if step["direction"] == "down" else "↑"
            return f"{i+1}. {dir_txt} x{step['amount']}"
        elif t == "wait":
            return f"{i+1}. ⏳ {step['seconds']}s"
        return f"{i+1}. {t}"

    def on_steps_reordered(self, model, path):
        """Cuando se reordena con drag and drop"""
        # Reconstruir el orden de pasos según el nuevo orden del ListStore
        new_steps = []
        for row in self.steps_store:
            idx = row[0]
            if idx < len(self.recording["steps"]):
                new_steps.append(self.recording["steps"][idx])

        if len(new_steps) == len(self.recording["steps"]):
            self.recording["steps"] = new_steps
            Path(self.edit_path).write_text(json.dumps(self.recording, indent=2))
            # Refrescar descripciones
            GLib.idle_add(self._refresh_step_numbers)

    def _refresh_step_numbers(self):
        """Actualiza los números de paso después de reordenar"""
        for i, row in enumerate(self.steps_store):
            row[0] = i
            row[1] = self._step_description(i, self.recording["steps"][i])

    def delete_selected_step(self):
        """Elimina el paso seleccionado"""
        selection = self.steps_tree.get_selection()
        model, treeiter = selection.get_selected()
        if treeiter:
            idx = model[treeiter][0]
            if idx > 0:  # No eliminar URL inicial
                del self.recording["steps"][idx]
                Path(self.edit_path).write_text(json.dumps(self.recording, indent=2))
                self.show_edit_steps(self.edit_path)

    def delete_step(self, idx):
        del self.recording["steps"][idx]
        Path(self.edit_path).write_text(json.dumps(self.recording, indent=2))
        self.show_edit_steps(self.edit_path)

    def move_step_up(self, idx):
        if idx > 1:
            steps = self.recording["steps"]
            steps[idx], steps[idx-1] = steps[idx-1], steps[idx]
            Path(self.edit_path).write_text(json.dumps(self.recording, indent=2))
            self.show_edit_steps(self.edit_path)

    def move_step_down(self, idx):
        steps = self.recording["steps"]
        if idx < len(steps) - 1:
            steps[idx], steps[idx+1] = steps[idx+1], steps[idx]
            Path(self.edit_path).write_text(json.dumps(self.recording, indent=2))
            self.show_edit_steps(self.edit_path)

    def add_step_to_edit(self):
        # Guardar y ir al panel de grabación
        Path(self.edit_path).write_text(json.dumps(self.recording, indent=2))
        self.show_recording_panel()

    def save_edit(self):
        Path(self.edit_path).write_text(json.dumps(self.recording, indent=2))
        self.show_main()

    # ==================== ARCHIVAR ====================

    def show_delete(self):
        self.clear()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        vbox.set_margin_top(15)
        vbox.set_margin_bottom(15)
        vbox.set_margin_start(15)
        vbox.set_margin_end(15)

        lbl = Gtk.Label(label="Selecciona URL a archivar")
        lbl.get_style_context().add_class("title")
        vbox.pack_start(lbl, False, False, 5)

        for name, path in self.get_turls():
            btn = Gtk.Button(label=name)
            btn.connect("clicked", lambda x, p=path: self.confirm_delete(p))
            vbox.pack_start(btn, False, False, 0)

        btn_back = Gtk.Button(label="Volver")
        btn_back.connect("clicked", lambda x: self.show_main())
        vbox.pack_end(btn_back, False, False, 10)

        self.add(vbox)
        self.show_all()

    def confirm_delete(self, path):
        """Archivar workflow"""
        archive_dir = SAVED_DIR / "archive"
        archive_dir.mkdir(exist_ok=True)
        src = Path(path)
        dst = archive_dir / src.name
        src.rename(dst)
        self.show_main()

    # ==================== EJECUTAR CON VISUALIZACIÓN ====================

    def run_turl(self, path):
        self.hide()
        self._process_gtk_events()
        time.sleep(0.1)  # Dar tiempo a que se oculte

        data = json.loads(Path(path).read_text())
        steps = data["steps"]
        total_steps = len(steps)

        browser_window = None

        for i, step in enumerate(steps):
            t = step["type"]

            if t == "url":
                # Mostrar overlay: Abriendo navegador
                self.status_overlay.show_step(
                    "🌐", "Abriendo navegador",
                    step["value"][:50],
                    i + 1, total_steps
                )
                subprocess.Popen(["xdg-open", step["value"]])

                # Espera con countdown visual
                self._visual_wait(2.5)

                # Obtener ventana activa (debería ser el navegador)
                try:
                    result = subprocess.run(["xdotool", "getactivewindow"],
                                          capture_output=True, text=True)
                    browser_window = result.stdout.strip()
                except:
                    pass

            elif t == "click":
                # Usar porcentajes si están disponibles, sino absolutos (legacy)
                if "px" in step and "py" in step:
                    x, y = percent_to_coords(step["px"], step["py"])
                else:
                    x, y = step["x"], step["y"]

                snap = step.get("snap")
                props = step.get("props", {})

                # Verificar propiedades del elemento (texto, color)
                props_ok, mismatches = verify_element_properties(x, y, props)
                if not props_ok:
                    self.status_overlay.show_step(
                        "⚠️", "Verificando elemento",
                        "Propiedades no coinciden",
                        i + 1, total_steps
                    )
                    if not self._show_props_mismatch_dialog(x, y, i + 1, props, mismatches):
                        self.status_overlay.hide()
                        Gtk.main_quit()
                        return

                # Verificar que el contexto visual coincide (snapshot)
                elif snap and not compare_regions(snap, x, y):
                    self.status_overlay.show_step(
                        "⚠️", "Workflow pausado",
                        "El contexto ha cambiado",
                        i + 1, total_steps
                    )
                    if not self._show_mismatch_dialog(x, y, i + 1):
                        self.status_overlay.hide()
                        Gtk.main_quit()
                        return

                # Mostrar overlay: Click
                click_desc = f"({x}, {y})"
                if props.get("text"):
                    click_desc = f"'{props['text'][:20]}'"
                self.status_overlay.show_step(
                    "👆", "Click",
                    click_desc,
                    i + 1, total_steps
                )

                # Activar ventana del navegador si la tenemos
                if browser_window:
                    subprocess.run(["xdotool", "windowactivate", "--sync", browser_window],
                                 capture_output=True)
                    self._sleep(0.1)

                # Mover mouse y click
                subprocess.run(["xdotool", "mousemove", "--sync", str(x), str(y)])
                self._sleep(0.1)

                # Mostrar indicador de click animado
                GLib.idle_add(self.click_indicator.show_at, x, y)

                # Hacer click
                subprocess.run(["xdotool", "click", "1"])
                self._sleep(0.4)

            elif t == "input":
                if "prompt" in step:
                    # Mostrar overlay: Solicitando input
                    self.status_overlay.show_step(
                        "✏️", "Esperando input",
                        step["prompt"],
                        i + 1, total_steps
                    )

                    # Pedir input al usuario
                    self.show()
                    dialog = Gtk.Dialog(title=step["prompt"], parent=self)
                    dialog.set_default_size(350, 100)

                    entry = Gtk.Entry()
                    entry.set_margin_top(10)
                    entry.set_margin_bottom(10)
                    entry.set_margin_start(10)
                    entry.set_margin_end(10)
                    dialog.get_content_area().add(entry)

                    dialog.add_button("Cancelar", Gtk.ResponseType.CANCEL)
                    dialog.add_button("OK", Gtk.ResponseType.OK)
                    dialog.show_all()

                    response = dialog.run()
                    value = entry.get_text()
                    dialog.destroy()
                    self.hide()

                    if response != Gtk.ResponseType.OK:
                        self.status_overlay.hide()
                        Gtk.main_quit()
                        return
                else:
                    value = step.get("value", "")

                # Mostrar overlay: Escribiendo
                self.status_overlay.show_step(
                    "⌨️", "Escribiendo",
                    f"{len(value)} caracteres",
                    i + 1, total_steps
                )
                self.status_overlay.show_typing(value, is_password=False)

                # Activar ventana del navegador
                if browser_window:
                    subprocess.run(["xdotool", "windowactivate", "--sync", browser_window],
                                 capture_output=True)
                    self._sleep(0.1)

                subprocess.run(["xdotool", "type", "--clearmodifiers", value])
                self._sleep(0.2)

            elif t == "password":
                # Mostrar overlay: Solicitando contraseña
                self.status_overlay.show_step(
                    "🔐", "Contraseña requerida",
                    step["prompt"],
                    i + 1, total_steps
                )

                # Pedir contraseña
                self.show()
                dialog = Gtk.Dialog(title=step["prompt"], parent=self)
                dialog.set_default_size(350, 100)

                entry = Gtk.Entry()
                entry.set_visibility(False)
                entry.set_margin_top(10)
                entry.set_margin_bottom(10)
                entry.set_margin_start(10)
                entry.set_margin_end(10)
                dialog.get_content_area().add(entry)

                dialog.add_button("Cancelar", Gtk.ResponseType.CANCEL)
                dialog.add_button("OK", Gtk.ResponseType.OK)
                dialog.show_all()

                response = dialog.run()
                value = entry.get_text()
                dialog.destroy()
                self.hide()

                if response != Gtk.ResponseType.OK:
                    self.status_overlay.hide()
                    Gtk.main_quit()
                    return

                # Mostrar overlay: Escribiendo contraseña
                self.status_overlay.show_step(
                    "🔑", "Ingresando contraseña",
                    "●●●●●●●●",
                    i + 1, total_steps
                )
                self.status_overlay.show_typing(value, is_password=True)

                # Activar ventana del navegador
                if browser_window:
                    subprocess.run(["xdotool", "windowactivate", "--sync", browser_window],
                                 capture_output=True)
                    self._sleep(0.1)

                subprocess.run(["xdotool", "type", "--clearmodifiers", value])
                self._sleep(0.2)

            elif t == "key":
                key_name = step["value"]
                key_display = {
                    "Return": "Enter ↵",
                    "Tab": "Tab ⇥",
                    "Escape": "Escape",
                    "BackSpace": "Borrar ⌫",
                    "space": "Espacio",
                    "ctrl+a": "Ctrl+A",
                    "ctrl+c": "Ctrl+C",
                    "ctrl+v": "Ctrl+V",
                }.get(key_name, key_name)

                # Mostrar overlay: Presionando tecla
                self.status_overlay.show_step(
                    "⌨️", "Tecla",
                    key_display,
                    i + 1, total_steps
                )

                # Activar ventana del navegador
                if browser_window:
                    subprocess.run(["xdotool", "windowactivate", "--sync", browser_window],
                                 capture_output=True)
                    self._sleep(0.1)

                subprocess.run(["xdotool", "key", "--clearmodifiers", key_name])
                self._sleep(0.2)

            elif t == "scroll":
                direction = step["direction"]
                amount = step["amount"]

                dir_icon = "⬇️" if direction == "down" else "⬆️"
                dir_text = "abajo" if direction == "down" else "arriba"

                # Mostrar overlay: Scroll
                self.status_overlay.show_step(
                    dir_icon, f"Scroll {dir_text}",
                    f"Cantidad: {amount}",
                    i + 1, total_steps
                )

                # Activar ventana del navegador
                if browser_window:
                    subprocess.run(["xdotool", "windowactivate", "--sync", browser_window],
                                 capture_output=True)
                    self._sleep(0.1)

                btn = "5" if direction == "down" else "4"
                for _ in range(amount):
                    subprocess.run(["xdotool", "click", btn])
                    self._sleep(0.1)
                self._sleep(0.3)

            elif t == "wait":
                seconds = step["seconds"]

                # Mostrar overlay: Esperando con countdown
                self.status_overlay.show_step(
                    "⏳", "Esperando",
                    f"{seconds} segundos",
                    i + 1, total_steps
                )

                self._visual_wait(seconds)

        # Finalizar
        self.status_overlay.show_step(
            "✅", "Completado",
            data["name"],
            total_steps, total_steps
        )
        self._sleep(0.8)
        self.status_overlay.hide()

        Gtk.main_quit()

    def _visual_wait(self, seconds):
        """Espera con countdown visual"""
        start = time.time()
        remaining = seconds

        while remaining > 0:
            self.status_overlay.show_countdown(remaining)
            self._process_gtk_events()
            time.sleep(0.05)
            remaining = seconds - (time.time() - start)

        self.status_overlay.show_countdown(0)

    def _process_gtk_events(self):
        """Procesa eventos GTK pendientes"""
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)

    def _sleep(self, seconds):
        """Sleep que procesa eventos GTK"""
        start = time.time()
        while (time.time() - start) < seconds:
            self._process_gtk_events()
            time.sleep(0.02)

    def _show_mismatch_dialog(self, x, y, step_num):
        """Muestra diálogo cuando el contexto no coincide. Retorna True para continuar."""
        self.show()
        dialog = Gtk.Dialog(title="Workflow Pausado", parent=self)
        dialog.set_default_size(400, 150)

        content = dialog.get_content_area()
        content.set_margin_top(15)
        content.set_margin_bottom(10)
        content.set_margin_start(15)
        content.set_margin_end(15)

        lbl = Gtk.Label()
        lbl.set_markup(
            f"<b>⚠️ El contexto ha cambiado</b>\n\n"
            f"Paso {step_num}: Click en ({x}, {y})\n\n"
            f"La pantalla no coincide con lo grabado.\n"
            f"Esto puede ocurrir si ya estás logueado\n"
            f"o si la página cambió."
        )
        lbl.set_line_wrap(True)
        content.add(lbl)

        dialog.add_button("Cancelar workflow", Gtk.ResponseType.CANCEL)
        dialog.add_button("Continuar de todos modos", Gtk.ResponseType.OK)
        dialog.show_all()

        response = dialog.run()
        dialog.destroy()
        self.hide()

        return response == Gtk.ResponseType.OK

    def _show_props_mismatch_dialog(self, x, y, step_num, saved_props, mismatches):
        """Muestra diálogo cuando las propiedades del elemento no coinciden."""
        self.show()
        dialog = Gtk.Dialog(title="Verificación de elemento", parent=self)
        dialog.set_default_size(450, 200)

        content = dialog.get_content_area()
        content.set_margin_top(15)
        content.set_margin_bottom(10)
        content.set_margin_start(15)
        content.set_margin_end(15)

        # Construir mensaje
        saved_text = saved_props.get("text", "?")
        saved_color = saved_props.get("color", "?")

        mismatch_text = "\n".join(f"• {m}" for m in mismatches) if mismatches else ""

        lbl = Gtk.Label()
        lbl.set_markup(
            f"<b>⚠️ El elemento puede haber cambiado</b>\n\n"
            f"Paso {step_num}: Click en ({x}, {y})\n\n"
            f"<b>Esperaba:</b>\n"
            f"  Texto: '{saved_text}'\n"
            f"  Color: {saved_color}\n\n"
            f"<b>Diferencias:</b>\n{mismatch_text}\n\n"
            f"¿Es este el botón correcto?"
        )
        lbl.set_line_wrap(True)
        lbl.set_xalign(0)
        content.add(lbl)

        dialog.add_button("Cancelar workflow", Gtk.ResponseType.CANCEL)
        dialog.add_button("Sí, continuar", Gtk.ResponseType.OK)
        dialog.show_all()

        response = dialog.run()
        dialog.destroy()
        self.hide()

        return response == Gtk.ResponseType.OK


if __name__ == "__main__":
    app = TurlsApp()
    app.connect("destroy", Gtk.main_quit)
    app.show_all()
    Gtk.main()
