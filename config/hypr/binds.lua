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
bind(mainMod .. " + grave",  hl.dsp.exec_cmd("$HOME/.local/bin/dragon-dropdown"),   "Aplicaciones · Terminal desplegable")
bind(mainMod .. " + Space",  hl.dsp.exec_cmd("qs ipc call shell toggle launcher"),  "Aplicaciones · Lanzador")

-- Keyboard layout: next one in kb_layout (also the bar capsule). The only key for it since Alt+Shift left kb_options
-- (it fired inside Alt+Shift+Tab), so it is `locked`: it also works on the lock screen, to type the password.
bind(mainMod .. " + ALT + Space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), "Teclado · Cambiar distribución (US / LA)", { locked = true })

-- Window management
bind(mainMod .. " + Q",         hl.dsp.window.close(),                                                "Ventanas · Cerrar")
bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),  "Ventanas · Maximizar / restaurar")
bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "Ventanas · Pantalla completa")
bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }),                       "Ventanas · Alternar flotante")

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
bind(mainMod .. " + Tab",    hl.dsp.exec_cmd("qs ipc call overview toggle"),            "Escritorios · Vista general (arrastrar ventanas entre escritorios)")
bind(mainMod .. " + W",         hl.dsp.exec_cmd("qs ipc call wallpaper orbital"), "Shell · Fondos de pantalla (orbital)")
bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call wallpaper random"), "Shell · Fondo aleatorio")
bind(mainMod .. " + X", hl.dsp.exec_cmd("qs ipc call dock toggle"), "Dock · Fijar / liberar el dock")
bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc call dock minimize"), "Dock · Minimizar la ventana (escritorio especial)")
bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("qs ipc call toggles record"), "Shell · Grabar pantalla (iniciar / parar)")
bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("qs ipc call shell toggle herdrhelp"), "Agentes · Atajos y funciones de herdr (referencia)")
bind(mainMod .. " + I",         hl.dsp.exec_cmd("qs ipc call shell toggle store"), "Shell · Tienda de apps (pacman + AUR)")
bind(mainMod .. " + A",         hl.dsp.exec_cmd("$HOME/.local/bin/dragon-herdr"), "Agentes · Abrir o enfocar herdr (escritorio 5)")
bind(mainMod .. " + ALT + A",   hl.dsp.exec_cmd("qs ipc call shell nook ia"), "Agentes · Ver agentes y comandos en la isla")
bind(mainMod .. " + N",      hl.dsp.exec_cmd("qs ipc call shell toggle notifications"), "Shell · Notificaciones")
bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qs ipc call shell toggle power"),         "Shell · Menú de energía")
bind(mainMod .. " + F1",     hl.dsp.exec_cmd("qs ipc call shell toggle keybinds"),      "Shell · Esta ayuda de atajos")
bind(mainMod .. " + F2",     hl.dsp.exec_cmd("qs ipc call shell toggle settings"),      "Shell · Ajustes")
bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("qs ipc call settings cycleBarStyle"),   "Shell · Cambiar el estilo de la barra")
bind(mainMod .. " + ALT + F", hl.dsp.exec_cmd("qs ipc call focus toggle"),             "Shell · Modo enfoque (45 min)")

-- A boolean of ~/.config/dragon-island/settings.json, read when this file loads (Quickshell reloads Hyprland when the
-- ones used here change, services/Switcher.qml). Missing file / key: the default.
local function dragon_setting(key, default)
    local dir = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
    local f = io.open(dir .. "/dragon-island/settings.json", "r")
    if not f then return default end
    local text = f:read("*a")
    f:close()
    local v = text:match('"' .. key .. '"%s*:%s*(%a+)')
    if v == "true" then return true elseif v == "false" then return false end
    return default
end

-- Alt+Tab orbital (services/Switcher.qml, docs/design/10-alttab.png). Ajustes › Launcher › «Alt+Tab orbital» off:
-- nothing is bound, apps get Alt+Tab. Releasing Alt confirms (release bind; transparent so no other bind shadows it);
-- the switcher window also confirms on its own Alt release once it has the keyboard.
if dragon_setting("switcherOrbital", true) then
    bind("ALT + Tab",         hl.dsp.exec_cmd("qs ipc call switcher next"),    "Ventanas · Alt+Tab orbital: siguiente")
    bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("qs ipc call switcher prev"),    "Ventanas · Alt+Tab orbital: anterior")
    bind("ALT + Alt_L",       hl.dsp.exec_cmd("qs ipc call switcher confirm"), "Ventanas · Alt+Tab orbital: soltar Alt confirma",
         { release = true, transparent = true })
end

-- Session lock & system
bind(mainMod .. " + L", hl.dsp.exec_cmd("qs ipc call lock lock || hyprlock"), "Sistema · Bloquear la sesión")

-- Screenshots from the island (services/Capture.qml: grim, copy + save in the pictures folder)
bind("Print",                   hl.dsp.exec_cmd("qs ipc call capture screen"),      "Capturas · Pantalla completa (copiar y guardar)")
bind("SHIFT + Print",           hl.dsp.exec_cmd("qs ipc call capture open region"), "Capturas · Barra de capturas (región, ventana, pantalla)")
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("qs ipc call capture open region"), "Capturas · Barra de capturas (región, ventana, pantalla)")

-- Clipboard history (cliphist): the Gravity launcher's clipboard ring (Enter pastes into the window that had the focus);
-- with «Launcher Gravedad» off, the previous clipboard panel. SUPER + SHIFT + V stays as an alias (it used to be the key).
bind(mainMod .. " + V",         hl.dsp.exec_cmd("qs ipc call launcher clipboard"), "Shell · Portapapeles (anillo; Enter pega)")
bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs ipc call launcher clipboard"), "Shell · Portapapeles (anillo; Enter pega)")

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
