---
name: hyprland-plugins
description: Installs, configures and troubleshoots Hyprland plugins with hyprpm, especially the official hyprwm/hyprland-plugins (hyprbars title bars, hyprfocus focus animation, borders-plus-plus) on Hyprland 0.56 with the Lua config. Use when the task mentions hyprpm, hyprbars, hyprfocus, borders-plus-plus, plugin title bars, or loading plugins at Hyprland startup.
---

# Hyprland plugins (Hyprland 0.56.x, Lua config)

## What exists today (verified 2026-10-05)

The official repo `https://github.com/hyprwm/hyprland-plugins` contains **only four** plugins:

| Plugin | Does |
|---|---|
| `hyprbars` | Title bars with buttons on windows |
| `hyprfocus` | Flash / shrink / slide animation when focus changes |
| `borders-plus-plus` | One or two extra static borders |
| `csgo-vulkan-fix` | Fix for CS:GO `-vulkan` resolutions (irrelevant here) |

`hyprexpo`, `hyprscrolling`, `hyprtrails`, `hyprwinwrap` and `xtra-dispatchers` were **removed** on 2026-05-12 as unmaintained. Do not suggest or install them. The scrolling layout is **built into** Hyprland 0.56 (`general.layout = "scrolling"`, options under `scrolling`).

## Version pinning (important)

`hyprpm` installs the plugin commit pinned for the running Hyprland version, not the latest code.
For Hyprland **0.56.0–0.56.2** the pin is commit `7644cec` (2026-07-15).
`references/` contains the plugin READMEs **at that pin**: only use options listed there.
Options added later on `main` (e.g. hyprbars `buttons_on_hover`, Sept 2026) do **not** exist in the pinned build.

## Install with hyprpm

Build dependencies (from the wiki): `cpio cmake git meson gcc`. `hyprpm update` fetches and installs the Hyprland headers matching your version.

```sh
hyprpm update                                         # headers for the installed Hyprland version
hyprpm add https://github.com/hyprwm/hyprland-plugins # build the repo
hyprpm enable hyprbars
hyprpm enable hyprfocus
hyprpm list
hyprpm reload -n                                      # load enabled plugins now (-n = notify)
```

- Run as the normal user, inside a running Hyprland session. `hyprpm` may ask for sudo to install headers.
- After every Hyprland update: `hyprpm update` again, or plugins fail to load (version mismatch).
- Load at startup from the Lua config:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload -n")
end)
```

- If Hyprland permission management is enabled, allow hyprpm (from the wiki):
  `hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")`
- Crash after an update → `hyprpm disable <name>` from a TTY, then `hyprpm update`.

## Configure in Lua

Plugins are loaded **after** the config is first parsed, so plugin-specific calls must be guarded. `hl.config({ plugin = { ... } })` for options; `hl.plugin.hyprbars.add_button({...})` only exists once hyprbars is loaded:

```lua
-- plugins.lua  (require("plugins") from hyprland.lua)
hl.config({
    plugin = {
        hyprbars = {
            bar_height = 30,
            bar_color = "rgba(1c1e2ee6)",
            ["col.text"] = "rgb(e6e8ef)",
            bar_text_font = "Outfit",
            bar_text_size = 11,
            bar_text_weight = "medium",
            bar_text_align = "center",
            bar_buttons_alignment = "left",
            bar_blur = true,
            bar_part_of_window = true,
            bar_precedence_over_border = true,
            bar_padding = 12,
            bar_button_padding = 8,
            icon_on_hover = true,
            inactive_button_color = "rgb(3a3d55)",
            on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
        },
        hyprfocus = {
            keyboard_focus_animation = "shrink",
            mouse_focus_animation = "none",
            shrink_percentage = 0.97,
        },
    },
})

if hl.plugin and hl.plugin.hyprbars then
    -- buttons are listed right-to-left in the source docs; with left alignment check the visual order and swap if needed
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(ed254e)", fg_color = "rgb(ffffff)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(f9ae58)", fg_color = "rgb(161925)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']] })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(06c993)", fg_color = "rgb(161925)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })']] })
end

hl.animation({ leaf = "hyprfocusIn",  enabled = true, speed = 1.7, bezier = "easeOutQuint" })
hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 1.7, bezier = "easeOutQuint" })
```

Notes:
- In **Lua mode**, `hyprctl dispatch` takes Lua dispatcher expressions (`'hl.dsp.window.close()'`), not the old `killactive` strings. The pinned README's Lua example still shows the old strings; prefer the form above and test it.
- Keys with dots or colons must be bracketed in Lua tables (`["col.text"]`).
- If bars show default styling after login, the options were applied before the plugin loaded. Run `hyprctl reload` after `hyprpm reload -n` (e.g. chain them in the start hook) and re-check.
- `hyprfocusIn`/`hyprfocusOut` animation leaves only exist when hyprfocus is loaded; if they raise config errors at first parse, move them inside an `if hl.plugin and hl.plugin.hyprfocus then … end` guard.
- Dynamic window rules from hyprbars: `hyprbars:no_bar`, `hyprbars:bar_color`, `hyprbars:title_color`. In Lua, write them as bracketed keys inside `hl.window_rule` (e.g. `["hyprbars:no_bar"] = true`); this form is inferred, not documented, so verify it loads.
- Titles render with `bar_text_font`; button icons need a Nerd Font installed (e.g. `ttf-jetbrains-mono-nerd`) or use plain characters.

## Debug checklist
1. `hyprpm list` shows the plugin enabled.
2. `hyprctl plugin list` shows it loaded.
3. `hyprctl configerrors` is empty.
4. Logs: `journalctl --user -b | grep -i hyprpm` or the Hyprland log in `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log`.
