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

**On Arch, `hyprpm` is a separate package** (`hyprpm` in `extra`, split from `hyprland`). Install it: `pacman -S --needed hyprpm`. Without it every plugin step fails with `hyprpm: command not found`.

Build dependencies (from the wiki): `cpio cmake git meson gcc`. `hyprpm update` fetches and installs the Hyprland headers matching your version.

```sh
hyprpm update                                         # headers for the installed Hyprland version
hyprpm add https://github.com/hyprwm/hyprland-plugins # build the repo
hyprpm enable hyprbars
hyprpm enable hyprfocus
hyprpm list
hyprpm reload -n                                      # load enabled plugins now (-n = notify)
```

- Run as the normal user, inside a running Hyprland session, **in a terminal**. `hyprpm update` writes to `/var/cache/hyprpm/<user>` through a root helper and asks for the password: it **fails when run non-interactively** (autostart scripts, `gum spin`). The installer must run `hyprpm update/add/enable` in the foreground; autostart only does `hyprpm reload -n && hyprctl reload`.
- Dependencies hyprpm itself checks: `cmake cpio pkgconf git gcc` (plus `meson` for some plugins).
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

Plugins are loaded **after** the config is first parsed. **Everything plugin-related must be guarded**: unloaded plugins make every `plugin.<name>.*` key an `unknown config key` error (confirmed on a real 0.56.2 install), and `hl.plugin.<name>` is nil until the plugin loads. After `hyprpm reload` loads them, run `hyprctl reload` so the guarded block applies.

```lua
-- plugins.lua  (require("plugins") from hyprland.lua)
local loaded = function(name) return hl.plugin ~= nil and hl.plugin[name] ~= nil end

if loaded("hyprbars") then
    hl.config({ plugin = { hyprbars = {
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
    } } })
end

if loaded("hyprfocus") then
    hl.config({ plugin = { hyprfocus = {
        keyboard_focus_animation = "shrink",
        mouse_focus_animation = "none",
        shrink_percentage = 0.97,
    } } })
end

if loaded("hyprbars") then
    -- buttons are listed right-to-left in the source docs; with left alignment check the visual order and swap if needed
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(ed254e)", fg_color = "rgb(ffffff)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(f9ae58)", fg_color = "rgb(161925)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']] })
    hl.plugin.hyprbars.add_button({ bg_color = "rgb(06c993)", fg_color = "rgb(161925)", size = 12, icon = "", action = [[hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })']] })
end

if loaded("hyprfocus") then
    hl.animation({ leaf = "hyprfocusIn",  enabled = true, speed = 1.7, bezier = "easeOutQuint" })
    hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 1.7, bezier = "easeOutQuint" })
end
```

Notes:
- In **Lua mode**, `hyprctl dispatch` takes Lua dispatcher expressions (`'hl.dsp.window.close()'`), not the old `killactive` strings. The pinned README's Lua example still shows the old strings; prefer the form above and test it.
- Keys with dots or colons must be bracketed in Lua tables (`["col.text"]`).
- If bars show default styling after login, the options were applied before the plugin loaded. Run `hyprctl reload` after `hyprpm reload -n` (e.g. chain them in the start hook) and re-check.
- `hyprfocusIn`/`hyprfocusOut` animation leaves only exist when hyprfocus is loaded; if they raise config errors at first parse, move them inside an `if hl.plugin and hl.plugin.hyprfocus then … end` guard.
- Dynamic window rules from hyprbars: `hyprbars:no_bar`, `hyprbars:bar_color`, `hyprbars:title_color`. In Lua, write them as bracketed keys inside `hl.window_rule` (e.g. `["hyprbars:no_bar"] = true`); this form is inferred, not documented, so verify it loads.
- Titles render with `bar_text_font`; button icons need a Nerd Font installed (e.g. `ttf-jetbrains-mono-nerd`) or use plain characters.

## hyprglass (third-party: acrylic / liquid-glass blur)

Repo `https://github.com/hyprnux/hyprglass` (BSD-3). hyprpm pins **v0.9.1 for Hyprland 0.56.2**; `references/hyprglass.md` is its README at that version — use only options listed there.

```sh
hyprpm add https://github.com/hyprnux/hyprglass
hyprpm enable hyprglass
hyprpm reload -n && hyprctl reload
```

Key facts:
- Lua API: guard with `if hl.plugin.hyprglass then local hg = hl.plugin.hyprglass … end`; `hg.config({...})`, `hg.layer("<namespace>", {...})`, `hg.preset("<name>", {...})`. Colors are `0xRRGGBBAA` numbers.
- Layer surfaces (bars) are **off by default**: `hg.config({ layers = { enabled = true } })`, then whitelist each namespace with `hg.layer(...)`.
- For a full-width transparent bar window use `mask_mode = "region"`: glass only where the client requests blur. In Quickshell that is `BackgroundEffect.blurRegion: Region { item: island; radius: 14 }` on each island.
- `layers.manage_blur` (default true) replaces Hyprland's blur on glassed layers (`ignore_alpha` then has no effect; use `mask_threshold`). Windows with glass get `noblur` automatically.
- Auto-enables Hyprland shadows (values can be zero). Disable per window with tags: `hl.window_rule({ match = { fullscreen = true }, tag = "+hyprglass_disabled" })`.
- Built-in presets: `high_contrast`, `subtle`, `clear`, `glass`, `pomme` (Apple-like).
- The layer hook uses a private Hyprland function and can break on Hyprland updates → keep the shell usable without the plugin (native blur fallback).
- Check: `hyprctl getoption plugin:hyprglass:layers:enabled`, `hyprctl hyprglass stats`.
- **Lua mode:** the README's `hyprctl dispatch tagwindow +tag` examples are hyprlang syntax and FAIL on 0.55+. Use `hyprctl dispatch 'hl.dsp.window.tag({ tag = "+hyprglass_preset_clear" })'` and `hl.dsp.window.clear_tags()`. Clearing tags also removes `hyprglass_enabled` (re-add it when using a whitelist).
- Look like the official screenshot = defaults + dark tint; keep `refraction_spread` near 0 (rim-only refraction, flat center) and `lens_distortion` low. High spread/lens/blur gives a smeared, warped look.

## Native blur (no plugin) on 0.56.2
`decoration.blur`: `enabled, size, passes, vibrancy, vibrancy_darkness, noise, contrast, brightness, popups, popups_ignorealpha, special, xray, ignore_opacity, new_optimizations`. Layer rules: `hl.layer_rule({ match = { namespace = "^dragon-bar$" }, blur = true, ignore_alpha = 0.3 })` (effects: `blur, blur_popups, ignore_alpha, xray, dim_around, no_anim, animation, order, above_lock, no_screen_share`). `blur.variant` / acrylic / glass are **hyprland-git only**.

## Debug checklist
1. `hyprpm list` shows the plugin enabled.
2. `hyprctl plugin list` shows it loaded.
3. `hyprctl configerrors` is empty.
4. Logs: `journalctl --user -b | grep -i hyprpm` or the Hyprland log in `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log`.
