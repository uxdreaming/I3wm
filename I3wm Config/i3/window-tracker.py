#!/usr/bin/env python3
"""
Daemon que trackea el orden de creación de ventanas en i3.
Guarda el orden en un archivo para que close-newest.sh pueda usarlo.
"""

import i3ipc
import json
import os

STACK_FILE = os.path.expanduser("~/.cache/i3-window-stack.json")

def load_stack():
    try:
        with open(STACK_FILE, 'r') as f:
            return json.load(f)
    except:
        return {}

def save_stack(stack):
    os.makedirs(os.path.dirname(STACK_FILE), exist_ok=True)
    with open(STACK_FILE, 'w') as f:
        json.dump(stack, f)

def on_window_new(i3, e):
    """Cuando se crea una ventana, agregarla al stack de su workspace"""
    stack = load_stack()

    con = e.container
    ws = con.workspace()
    if ws:
        ws_name = ws.name
        if ws_name not in stack:
            stack[ws_name] = []

        # Agregar al final (más reciente)
        con_id = con.id
        if con_id and con_id not in stack[ws_name]:
            stack[ws_name].append(con_id)

        save_stack(stack)

def on_window_close(i3, e):
    """Cuando se cierra una ventana, quitarla del stack"""
    stack = load_stack()

    con = e.container
    con_id = con.id

    # Buscar y eliminar de cualquier workspace
    for ws_name in stack:
        if con_id in stack[ws_name]:
            stack[ws_name].remove(con_id)
            break

    save_stack(stack)

def on_window_move(i3, e):
    """Cuando se mueve una ventana a otro workspace, actualizar stacks"""
    stack = load_stack()

    con = e.container
    con_id = con.id

    # Eliminar de todos los workspaces
    for ws_name in stack:
        if con_id in stack[ws_name]:
            stack[ws_name].remove(con_id)

    # Agregar al workspace actual
    ws = con.workspace()
    if ws:
        ws_name = ws.name
        if ws_name not in stack:
            stack[ws_name] = []
        stack[ws_name].append(con_id)

    save_stack(stack)

def init_stack(i3):
    """Inicializar el stack con las ventanas existentes"""
    stack = {}
    tree = i3.get_tree()

    for ws in tree.workspaces():
        ws_name = ws.name
        stack[ws_name] = []
        for con in ws.descendants():
            if con.window:  # Solo containers con ventana real
                stack[ws_name].append(con.id)

    save_stack(stack)

def main():
    i3 = i3ipc.Connection()

    # Inicializar con ventanas existentes
    init_stack(i3)

    # Suscribirse a eventos
    i3.on("window::new", on_window_new)
    i3.on("window::close", on_window_close)
    i3.on("window::move", on_window_move)

    i3.main()

if __name__ == "__main__":
    main()
