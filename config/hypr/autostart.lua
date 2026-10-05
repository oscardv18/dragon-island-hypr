-- =============================================================================
-- Autostart Services & Daemons
-- =============================================================================

hl.on("hyprland.start", function()
    -- Shell and desktop components
    hl.exec_cmd("quickshell")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")

    -- Authentication agent (hyprpolkitagent in Arch/EndeavourOS)
    hl.exec_cmd("/usr/lib/hyprpolkitagent || /usr/libexec/hyprpolkitagent")

    -- Clipboard management (text & image history)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- First-run script for hyprpm plugin setup (executed once on initial session)
    hl.exec_cmd("test -x ~/.local/state/dragon-island/firstrun.sh && ~/.local/state/dragon-island/firstrun.sh")

    -- Reload hyprpm plugins with desktop notification
    hl.exec_cmd("hyprpm reload -n")
end)
