-- =============================================================================
-- Autostart Services & Daemons
-- =============================================================================

hl.on("hyprland.start", function()
    -- Keyring: nothing to start here. The display manager's PAM (pam_gnome_keyring) starts
    -- gnome-keyring and unlocks the "login" keyring with the password typed at login.
    -- Shell (bar, Dynamic Island, notifications daemon, system tray host)
    hl.exec_cmd("quickshell")

    -- Desktop components
    -- Wallpapers: awww-daemon (images / GIF); Quickshell restores the saved wallpaper and starts mpvpaper for videos
    hl.exec_cmd("awww-daemon")
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
        .. "ghostty --class=org.dragonisland.Setup --title='dragon-island: primer arranque' -e " .. state .. "/firstrun.sh; }")

    -- Optional "Efecto cristal" component: install hyprglass in a visible terminal while glass.pending exists
    hl.exec_cmd("test -f " .. state .. "/glass.pending && test -x " .. state .. "/glass.sh && "
        .. "ghostty --class=org.dragonisland.Setup --title='dragon-island: efecto cristal' -e " .. state .. "/glass.sh")
end)
