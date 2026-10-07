# dragon-island — visual spec (from the approved mockup)

Everything here goes into `Theme.qml`. Components read from `Theme`, never hard-code.

## Palette (Sweet / Garuda Dragonized)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#0b0c14` | wallpaper fallback / deepest background |
| `surface0` | `#161925` | islands (at 72–86 % opacity), hyprbars bar |
| `surface1` | `#12131e` | cards inside panels |
| `surface2` | `#1d2031` | capsules, list rows, off toggles |
| `surface3` | `#22243a` | inactive pills, progress tracks |
| `surfaceHi` | `#34385a` | capsule while its popover is open |
| `outline` | `#262838` | inactive window border |
| `muted` | `#3a3d55` | inactive hyprbars buttons, empty dots |
| `text` | `#e6e8ef` | primary text |
| `textSoft` | `#c3c7d1` | body text |
| `textDim` | `#8a8fa3` | captions, empty workspaces |
| `accent` | `#c50ed2` | magenta, brand accent |
| `violet` | `#7c3aed` | gradient end |
| `violetSoft` | `#a855f7` | RAM, secondary accents |
| `cyan` | `#00c1e4` | CPU, links, info |
| `ok` | `#06c993` | battery, success, maximize-float button |
| `warn` | `#f9ae58` | warnings, fullscreen button, temperature |
| `error` | `#ed254e` | errors, close button |
| `island` | `#000000` | Dynamic Island & dashboard background |

Gradients:
- `brand`: 135°, `accent → violet` (active workspace, clock capsule, on-toggles, primary buttons).
- `border`: 135°, `accent → violet → cyan` (active window border in Hyprland: `{ colors = {"rgba(c50ed2ff)","rgba(7c3aedff)","rgba(00c1e4ff)"}, angle = 135 }`).
- Island border: 1 px `accent` at 30–35 % alpha; glow: `accent` at ~18 % alpha, 22–40 px blur.

## Typography
- UI: **Outfit** 400/500/600/700. Sizes: 11 (captions, uppercase +0.08em tracking), 12.5 (bar), 13–14 (body), 16 (popover titles), 22 (dashboard greeting), 40 (battery big number).
- Numbers, clock, terminal: **JetBrains Mono Nerd Font** 400/600.
- Icons: Nerd Font glyphs or inline SVG stroke icons, 2 px stroke, 14–18 px. No emoji.

## Geometry

| Element | Size / radius |
|---|---|
| Bar | floating 10 px from top, 14 px from sides, height 40; three islands |
| Island (left/right) | radius 14, padding 0 6, inner gap 4–6, 1 px border white 7 % |
| Capsule | height 28, radius 9, padding 0 10, gap 6 icon–text |
| Workspace pill | height 22, radius 8; active: brand gradient + name + glow; occupied: `surface3` + 4 px colored dot; empty: `textDim`, no background |
| Dynamic Island (closed) | height 36, radius 18, centered, `y` = 10 |
| Dashboard (open) | width 860, attached to the screen top (`y` = 0), top radii 0, bottom radii 34, padding 22 24 24 |
| Popover | width 320–380, radius 22, padding 18, 8 px below its capsule, `surface0` at 94 % + blur |
| Cards in panels | radius 18–20, `surface1` |
| Toggle tile | min-height 64, radius 18 |
| Buttons | min 44×44 touch target |
| Windows | gaps_in 6, gaps_out 12, rounding 14, border 2 px |
| hyprbars | height 30, buttons 12 px on the left: close `error`, fullscreen `warn`, float `ok`; inactive `muted` |

## Components

**Left island:** launcher button (30×30, radius 9, brand gradient) · workspace pills 1–5 · divider (1×18, white 10 %) · active window: app icon + class + title (dim).

**Right island:** CPU capsule (cyan icon, `NN%`) · RAM capsule (violet icon, `N.NG`) · grouped capsule [Wi-Fi | Bluetooth | volume `NN` | battery `NN%` green] — each is its own button · bell (dot = unread, accent with glow) · clock capsule (brand gradient, `lun 5 oct  16:23`, Spanish locale).

**Island, closed (priority order):** OSD > incoming notification > workspace change > now playing (art 24×24 radius 7, title, `· app`, 4-bar equalizer) > clock with status dot.

**Dashboard:** header (greeting "Buenas tardes, <name>", date · host · uptime; lock / suspend / power buttons, power in red tint) · 3 columns: [media card + volume & brightness sliders] [2×3 toggle grid: Wi-Fi, Bluetooth, No molestar, Luz nocturna, Captura, Grabar + power-profile segmented control] [CPU/RAM/Temp/Disk mini-bars + last 3 notifications] · grab handle (48×5) at the bottom.

**Popovers:**
- Rendimiento: per-core bars, RAM/GPU/Temp tiles, top 4 processes, profile buttons.
- Wi-Fi: switch, current network card (band, speed, IP), list with signal + security, "Configuración de red…".
- Bluetooth: switch, connected device card with battery bar, paired list, "Buscar dispositivos".
- Sonido: output + mic sliders, output device list (active marked with accent dot), per-app mixer.
- Batería: big %, time remaining, bar, consumption (W), health, brightness slider, profile.
- Notificaciones: DND toggle, cards (icon, title, body, app · time), "Borrar todo".
- Calendario: month grid (Mon first, `L M X J V S D`), today = brand gradient, days with events = cyan ring, clock with seconds, today's agenda.

## Notch Island v2 (replaces the floating pill — NotchNook / MacBook notch style)

- One overlay window per monitor, anchored **top**, `exclusionMode: Ignore`, namespace `dragon-island`. The shape is **attached to the screen's top edge (y = 0)** — it is never a floating pill.
- **Collapsed:** opaque black (`island`), width ≈ 210 (grows with content, max = free gap between bar islands − 2×16), height = bar top margin + bar height (10 + 40 = 50) so its bottom lines up with the bar islands' bottom. Bottom corners radius 18. **Concave "ears"** (inverse fillets, r = 12) on both top corners where it meets the edge, drawn with `QtQuick.Shapes` (`ShapePath` + `PathArc`). Content: art 22 px + title, or clock; eq bars. Never overlaps the bar islands.
- **Hover:** "peek" — grows 8 px down and 16 px wider (spring), shows a second line.
- **Expanded (click / SUPER+D):** grows from the same top-center anchor to ≈ 720 × 230 (fit 1366×768), top edge still at y = 0, ears kept, bottom radii 34. Layout like NotchNook: top row tabs **Nook | Tray** (left) and a settings gear (right); body = media card (art 96 px, title/album/artist, prev/play/next, app badge) · vertical divider · mini calendar strip (month + 5 days, today accent) with "Nada para hoy"/next event · quick toggles row (Wi‑Fi, BT, DND, night light) and system stats. **Tray** tab = system tray items + recent screenshots/downloads drop area (optional).
- Expanded may temporarily cover the bar islands (like NotchNook covers the menu bar); no dark scrim. Close on click outside (`HyprlandFocusGrab`), Esc, mouse leaving for 600 ms (setting), or SUPER+D.
- The island stays **opaque black** (it is the "notch"); glass/blur is for the bar islands, popovers and notifications.

## Motion

| Animation | Spec |
|---|---|
| Island first appearance (v2) | **emerges from the top edge**: height 0 → 50 and width 120 → collapsed width, spring (`SpringAnimation` spring 3.5, damping 0.32), no bounce from above |
| Island first appearance (v1, obsolete) | from `y = -60` (above the screen edge) to `y = 10`, 700 ms, OutBack (overshoot ~1.6) + slight horizontal squash at the start |
| Expand notch (v2) | width & height spring from the top-center anchor (spring 3.0, damping 0.30, ~450 ms perceived), ears scale with it; content fades in after 40 % (220 ms), collapses content-first then shape |
| Open dashboard ("pour", v1 obsolete) | shape grows from a narrow strip at the top edge to full size: width OutBack 420 ms, height OutCubic 480 ms; `y` → 0; corner radii animate to (0,0,34,34) |
| Dashboard content | fade/slide-in starting ~35 % into the open animation, 260 ms |
| Close | reverse, 300 ms OutCubic; content fades out first (120 ms) |
| Scrim | black 45 %, fade 220–250 ms |
| Popover | opacity 0→1 + translateY −10→0 + scale 0.96→1, 280 ms OutBack, origin top-right |
| Transient island states | expand with the same width Behavior, auto-collapse after 2000 ms (notifications: 4000 ms; critical: until dismissed) |
| Workspace pill | width + color 200 ms OutCubic |
| Capsule hover | background to `surfaceHi`, 120 ms |

Respect reduced motion if added later: a single `Theme.motionScale` multiplier on all durations.
