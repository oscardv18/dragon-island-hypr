-- =============================================================================
-- Keybindings Configuration
-- Modifier: SUPER (Windows key)
-- =============================================================================

local mainMod = "SUPER"

-- Core applications
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("dolphin"))
hl.bind(mainMod .. " + Space",  hl.dsp.exec_cmd("qs ipc call shell toggle launcher"))

-- Window management
hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))

-- Focus movement with arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Focus movement with vim keys (SUPER + ALT + H/J/K/L, resolving conflict with SUPER + L lock)
hl.bind(mainMod .. " + ALT + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + ALT + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + ALT + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + ALT + L", hl.dsp.focus({ direction = "right" }))

-- Move window with SHIFT + arrow keys
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Move window with SHIFT + vim keys
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- Workspace switching (1-5) and move window to workspace (SHIFT + 1-5)
for i = 1, 5 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Mouse binds: drag and resize windows
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Quickshell interactive panels (via qs ipc)
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd("qs ipc call shell toggle dashboard"))
hl.bind(mainMod .. " + N",      hl.dsp.exec_cmd("qs ipc call shell toggle notifications"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qs ipc call shell toggle power"))

-- Session lock & system
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))

-- Screenshots (grimblast / grim + slurp)
hl.bind("Print",                   hl.dsp.exec_cmd("grimblast --notify copysave output"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grimblast --notify copysave area"))

-- Clipboard history (cliphist, shown by the Quickshell clipboard panel)
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs ipc call shell toggle clipboard"))

-- Hardware & Multimedia keys (audio, mic, brightness, player)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                    { locked = true, repeating = true })

hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
