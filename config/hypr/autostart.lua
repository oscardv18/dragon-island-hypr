-- =============================================================================
-- Autostart Services & Daemons
-- =============================================================================

hl.on("hyprland.start", function()
    -- Shell (bar, Dynamic Island, notifications daemon) and desktop components
    hl.exec_cmd("quickshell")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")

    -- Polkit agent (Arch ships a systemd user unit; Plasma's agent only autostarts in Plasma)
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Clipboard history (text & images)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Load enabled hyprpm plugins, then reload the config so plugin options and
    -- hyprbars buttons (guarded in plugins.lua) are applied now that the plugins exist.
    hl.exec_cmd("hyprpm reload -n && hyprctl reload")

    -- First session only: build/enable plugins with hyprpm in a visible terminal
    -- (hyprpm may ask for the sudo password to install headers). No-op once the marker exists.
    local state = "${XDG_STATE_HOME:-$HOME/.local/state}/dragon-island"
    hl.exec_cmd("test -f " .. state .. "/firstrun.done || { test -x " .. state .. "/firstrun.sh && "
        .. "kitty --class dragon-island-setup --title 'dragon-island: primer arranque' " .. state .. "/firstrun.sh; }")
end)
