-- =============================================================================
-- Keybindings Configuration
-- Modifier: SUPER (Windows key)
--
-- Every bind has a description "Grupo · Texto": the Quickshell keybinds panel
-- (SUPER + F1) reads them live with `hyprctl binds -j`, so this file is the only
-- source of truth. Binds with the same group and text are shown as one row.
-- =============================================================================

local mainMod = "SUPER"

-- hl.bind with a description (merged into the flags table)
local function bind(keys, dispatcher, description, flags)
    flags = flags or {}
    flags.description = description
    return hl.bind(keys, dispatcher, flags)
end

-- Core applications
bind(mainMod .. " + Return", hl.dsp.exec_cmd("ghostty"),                            "Aplicaciones · Terminal (Ghostty)")
bind(mainMod .. " + E",      hl.dsp.exec_cmd("dolphin"),                            "Aplicaciones · Archivos (Dolphin)")
bind(mainMod .. " + Space",  hl.dsp.exec_cmd("qs ipc call shell toggle launcher"),  "Aplicaciones · Lanzador")

-- Keyboard layout: next one in kb_layout (also Alt+Shift through kb_options, and the bar capsule)
bind(mainMod .. " + ALT + Space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), "Teclado · Cambiar distribución (US / LA)")

-- Window management
bind(mainMod .. " + Q",         hl.dsp.window.close(),                                                "Ventanas · Cerrar")
bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),  "Ventanas · Maximizar / restaurar")
bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "Ventanas · Pantalla completa")
bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }),                           "Ventanas · Alternar flotante")

-- Focus movement with arrow keys
bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  "Foco · Mover el foco")
bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), "Foco · Mover el foco")
bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    "Foco · Mover el foco")
bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  "Foco · Mover el foco")

-- Focus movement with vim keys (SUPER + ALT + H/J/K/L, resolving conflict with SUPER + L lock)
bind(mainMod .. " + ALT + H", hl.dsp.focus({ direction = "left" }),  "Foco · Mover el foco (Vim)")
bind(mainMod .. " + ALT + J", hl.dsp.focus({ direction = "down" }),  "Foco · Mover el foco (Vim)")
bind(mainMod .. " + ALT + K", hl.dsp.focus({ direction = "up" }),    "Foco · Mover el foco (Vim)")
bind(mainMod .. " + ALT + L", hl.dsp.focus({ direction = "right" }), "Foco · Mover el foco (Vim)")

-- Move window with SHIFT + arrow keys
bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }),  "Ventanas · Mover la ventana")
bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), "Ventanas · Mover la ventana")
bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }),    "Ventanas · Mover la ventana")
bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }),  "Ventanas · Mover la ventana")

-- Move window with SHIFT + vim keys
bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }),  "Ventanas · Mover la ventana (Vim)")
bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }),  "Ventanas · Mover la ventana (Vim)")
bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }),    "Ventanas · Mover la ventana (Vim)")
bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }), "Ventanas · Mover la ventana (Vim)")

-- Tiling modes: dwindle (default) <-> scrolling (native columns on a horizontal tape), per workspace.
-- scripts/tiling.sh does the work (Quickshell's `tiling` IPC first: chip + notch notice; the script if it does not answer).
bind(mainMod .. " + T", hl.dsp.exec_cmd("qs ipc call tiling toggle || $HOME/.local/bin/dragon-tiling toggle"), "Ventanas · Alternar modo Dwindle / Scrolling")

-- Scrolling-only binds (layout messages, hl.dsp.layout): they do nothing on a dwindle workspace.
-- Left / right (and SUPER + SHIFT + arrows) already change column / move the window in both modes.
local function scrolling_only(msg)
    return function()
        local ws = hl.get_active_workspace()
        if ws and ws.tiled_layout == "scrolling" then hl.dispatch(hl.dsp.layout(msg)) end
    end
end
bind(mainMod .. " + CTRL + left",  scrolling_only("swapcol l"),                "Scrolling · Mover la columna a la izquierda")
bind(mainMod .. " + CTRL + right", scrolling_only("swapcol r"),                "Scrolling · Mover la columna a la derecha")
bind(mainMod .. " + comma",        scrolling_only("consume_or_expel prev"),    "Scrolling · Unir la ventana a la columna anterior / sacarla de la columna")
bind(mainMod .. " + period",       scrolling_only("consume_or_expel next"),    "Scrolling · Unir la ventana a la columna siguiente / sacarla de la columna")
bind(mainMod .. " + P",            scrolling_only("promote"),                  "Scrolling · Ventana a su propia columna")
bind(mainMod .. " + R",            scrolling_only("colresize +conf"),          "Scrolling · Ancho de columna (1/3, 1/2, 2/3, completo)")
bind(mainMod .. " + C",            scrolling_only("center"),                   "Scrolling · Centrar la columna")

-- Workspace switching (1-5) and move window to workspace (SHIFT + 1-5)
for i = 1, 5 do
    bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }),       "Escritorios · Ir al escritorio")
    bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), "Escritorios · Enviar la ventana al escritorio")
end

-- Mouse binds: drag and resize windows
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   "Ratón · Arrastrar ventana",      { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), "Ratón · Redimensionar ventana", { mouse = true })

-- Quickshell interactive panels (via qs ipc)
bind(mainMod .. " + D",      hl.dsp.exec_cmd("qs ipc call shell toggle dashboard"),     "Shell · Notch (Nook / Tray)")
bind(mainMod .. " + W",         hl.dsp.exec_cmd("qs ipc call wallpaper toggle"), "Shell · Fondos de pantalla")
bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call wallpaper random"), "Shell · Fondo aleatorio")
bind(mainMod .. " + X", hl.dsp.exec_cmd("qs ipc call dock toggle"), "Dock · Fijar / liberar el dock")
bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc call dock minimize"), "Dock · Minimizar la ventana (escritorio especial)")
bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("qs ipc call toggles record"), "Shell · Grabar pantalla (iniciar / parar)")
bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("qs ipc call shell toggle herdrhelp"), "Agentes · Atajos y funciones de herdr (referencia)")
bind(mainMod .. " + I",         hl.dsp.exec_cmd("qs ipc call shell toggle store"), "Shell · Tienda de apps (pacman + AUR)")
bind(mainMod .. " + A",         hl.dsp.exec_cmd("$HOME/.local/bin/dragon-herdr"), "Agentes · Abrir o enfocar herdr (escritorio 5)")
bind(mainMod .. " + N",      hl.dsp.exec_cmd("qs ipc call shell toggle notifications"), "Shell · Notificaciones")
bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qs ipc call shell toggle power"),         "Shell · Menú de energía")
bind(mainMod .. " + F1",     hl.dsp.exec_cmd("qs ipc call shell toggle keybinds"),      "Shell · Esta ayuda de atajos")

-- Session lock & system
bind(mainMod .. " + L", hl.dsp.exec_cmd("qs ipc call lock lock || hyprlock"), "Sistema · Bloquear la sesión")

-- Screenshots (grimblast / grim + slurp)
bind("Print",                   hl.dsp.exec_cmd("grimblast --notify copysave output"), "Capturas · Pantalla completa")
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grimblast --notify copysave area"),   "Capturas · Región")

-- Clipboard history (cliphist, shown by the Quickshell clipboard panel)
bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs ipc call shell toggle clipboard"), "Shell · Historial del portapapeles")

-- Hardware & Multimedia keys (audio, mic, brightness, player)
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), "Multimedia · Subir volumen",       { locked = true, repeating = true })
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        "Multimedia · Bajar volumen",       { locked = true, repeating = true })
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       "Multimedia · Silenciar",           { locked = true, repeating = true })
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     "Multimedia · Silenciar micrófono", { locked = true, repeating = true })
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                    "Multimedia · Subir brillo",        { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                    "Multimedia · Bajar brillo",        { locked = true, repeating = true })

bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), "Multimedia · Reproducir / pausar", { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "Multimedia · Reproducir / pausar", { locked = true })
bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       "Multimedia · Siguiente pista",     { locked = true })
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   "Multimedia · Pista anterior",      { locked = true })
