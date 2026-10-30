// NeuralCore.qml — dragon-island "neural core" (original design, AI-core look)
//
// Pure QtQuick (no Quickshell imports) so the same file runs in:
//   - the SDDM greeter theme  (sddm/dragon-core/components/)
//   - the Quickshell lock, launcher and bar (config/quickshell/components/)
//
// API
//   energy: real 0..1          base activity (typing raises it)
//   mood: string               "calm" | "verifying" | "alert" | "ok" | "listening" | "thinking" | "speaking"
//                                listening: breathes ±3.5 % of the radius at ~0.5 Hz, glow ×1.6
//                                thinking:  spin ×5, more links (higher threshold), frequent synapses
//                                speaking:  rings leave the centre every ~0.42 s (fade in 1.4 s), nodes vibrate 5 %
//                              every change is a ~0.3 s blend, never a jump
//   hud: bool                  dial around the sphere (ring 1.56 r, 90 ticks 1.45 r, lavender arcs 1.64 r,
//                              reverse cyan arc 1.72 r, dotted tilted orbit with a cyan satellite), default false
//   reducedMotion: bool        slow breathing, no spin
//   pointCount: int            sphere nodes (lower = cheaper), default 240
//   running: bool              pause rendering when false
//   compact: bool [readonly]   side < 64 px (bar button): 48 nodes, no halos / rings / dial, 12 fps at rest / 24 fps when active
//   bare: bool                 no orbital rings, dial or HUD around the sphere (the dock's 64 px core), default false
//   fps: int                   0 = every vsync (FrameAnimation, default); > 0 = a Timer at that rate (doubled while the
//                              mood is not calm), so a small core does not keep its whole window repainting at 60 Hz
//   pulse(): void              call on every key press
//   radius: real [readonly]    current sphere radius in px (for placing text inside)

import QtQuick

Item {
    id: core

    property real energy: 0.15
    property string mood: "calm"
    property bool hud: false
    property bool bare: false
    property int fps: 0
    property bool reducedMotion: false
    property int pointCount: 240
    property bool running: visible
    readonly property bool compact: Math.min(width, height) < 64
    readonly property real radius: Math.min(width, height) * (compact ? 0.3 : 0.25) * _expand * _breath

    function pulse() { _kick = Math.min(1.0, _kick + 0.32) }

    // ── internal state ───────────────────────────────────────────────
    // [node A (pink lavender), node B (lavender), node C / live accent (cyan)]
    readonly property var _identity: ["#e896ec", "#c8b6e6", "#67e8f9"]
    readonly property var _palettes: ({
        alert:     ["#ed254e", "#ff4d73", "#f9ae58"],
        ok:        ["#06c993", "#00c1e4", "#7cf5c9"]
    })
    property color _a: _identity[0]
    property color _b: _identity[1]
    property color _c: _identity[2]
    Behavior on _a { ColorAnimation { duration: 420 } }
    Behavior on _b { ColorAnimation { duration: 420 } }
    Behavior on _c { ColorAnimation { duration: 420 } }

    property real _energy: Math.max(0, Math.min(1, energy + (mood === "verifying" ? 0.45 : 0) + (mood === "alert" ? 0.35 : 0)))
    Behavior on _energy { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    property real _expand: mood === "ok" ? 1.22 : 1.0
    Behavior on _expand { NumberAnimation { duration: 750; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

    // per-state blend factors (0..1), 0.3 s so states melt into each other
    property real _listen: mood === "listening" ? 1 : 0
    property real _think: mood === "thinking" ? 1 : 0
    property real _speak: mood === "speaking" ? 1 : 0
    Behavior on _listen { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
    Behavior on _think { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
    Behavior on _speak { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }

    // listening: ±3.5 % of the radius at ~0.5 Hz
    readonly property real _breath: 1 + 0.035 * _listen * Math.sin(_t * Math.PI)

    property real _kick: 0
    property real _flash: 0
    property real _t: 0
    property real _ry: 0
    property real _rx: 0
    property real _nextWave: 0

    property var _pts: []      // [x,y,z, colour index 0..2] unit sphere
    property var _links: []    // [i, j, extra] extra = only drawn while thinking
    property var _pulses: []   // {l: linkIndex, p: progress, s: speed}
    property var _waves: []    // speaking: birth times

    function _applyPalette() {
        const p = _palettes[mood] || _identity
        _a = p[0]; _b = p[1]; _c = p[2]
        if (mood === "alert") _flash = 1.0
    }
    onMoodChanged: _applyPalette()

    function _build() {
        const n = compact ? 48 : Math.max(40, pointCount)
        const pts = []
        const golden = Math.PI * (3 - Math.sqrt(5))
        for (let i = 0; i < n; i++) {
            const y = 1 - (i / (n - 1)) * 2
            const r = Math.sqrt(1 - y * y)
            const th = golden * i
            // small organic jitter so it reads as a "brain", not a ball
            const j = 1 + 0.06 * Math.sin(i * 12.9898) * Math.cos(i * 4.1414)
            // colour: one in five is cyan (alive), the rest pink lavender / lavender
            const col = i % 5 === 0 ? 2 : (i % 2 === 0 ? 0 : 1)
            pts.push([Math.cos(th) * r * j, y * j, Math.sin(th) * r * j, col])
        }
        // neighbour links: up to 3 per node within the base threshold, up to 2 more within the "thinking" one
        const thr = 20 / n          // ≈ (1.5 × mean node spacing)², tuned for 160–400 nodes
        const thrThink = thr * 1.9
        const links = []
        const deg = new Array(n).fill(0)
        const degX = new Array(n).fill(0)
        for (let i = 0; i < n; i++) {
            const cand = []
            for (let k = i + 1; k < n; k++) {
                const dx = pts[i][0] - pts[k][0], dy = pts[i][1] - pts[k][1], dz = pts[i][2] - pts[k][2]
                const d2 = dx * dx + dy * dy + dz * dz
                if (d2 < thrThink) cand.push([d2, k])
            }
            cand.sort((a, b) => a[0] - b[0])
            for (let c = 0; c < cand.length; c++) {
                const k = cand[c][1]
                if (cand[c][0] < thr && deg[i] < 3 && deg[k] < 3) { links.push([i, k, 0]); deg[i]++; deg[k]++ }
                else if (degX[i] < 2 && degX[k] < 2) { links.push([i, k, 1]); degX[i]++; degX[k]++ }
            }
        }
        const pulses = []
        for (let q = 0; q < 60; q++)
            pulses.push({ l: Math.floor(Math.random() * links.length), p: Math.random(), s: 0.5 + Math.random() * 0.9 })
        _pts = pts; _links = links; _pulses = pulses
    }
    onPointCountChanged: _build()
    onCompactChanged: _build()
    Component.onCompleted: { _build(); _applyPalette(); canvas.requestPaint() }

    function _step(dt) {
        dt = Math.min(dt, 0.05)
        _t += dt
        const e = Math.min(1, _energy + _kick * 0.6)
        if (!reducedMotion) {
            _ry += dt * (0.12 + e * 0.9) * (1 + 4 * _think)
            _rx = Math.sin(_t * 0.13) * 0.38
        }
        _kick = Math.max(0, _kick - dt * 1.4)
        _flash = Math.max(0, _flash - dt * 1.1)
        const pulseRate = (0.35 + e * 1.6) * (1 + 1.5 * _think)
        for (let i = 0; i < _pulses.length; i++) {
            const pu = _pulses[i]
            pu.p += dt * pu.s * pulseRate
            if (pu.p >= 1) { pu.p = 0; pu.l = Math.floor(Math.random() * _links.length); pu.s = 0.5 + Math.random() * 0.9 }
        }
        // speaking: a new ring every ~0.42 s; each lives 1.4 s
        if (_speak > 0.01 && mood === "speaking" && _t >= _nextWave) {
            _waves.push(_t)
            _nextWave = _t + 0.42
        }
        while (_waves.length && _t - _waves[0] > 1.4) _waves.shift()
        canvas.requestPaint()
    }

    readonly property bool _timed: compact || fps > 0
    FrameAnimation {
        running: core.running && !core.reducedMotion && !core._timed
        onTriggered: core._step(frameTime)
    }
    // compact (bar button): a timer, NOT a FrameAnimation, which keeps the whole window repainting every vsync.
    // 12 fps at rest (a slow spin), 24 fps while it reacts (listening / thinking / speaking): the Canvas is painted
    // in JS and costs CPU on every frame (measured: ~6 % of a core at 20 fps on an AMD Lucienne laptop)
    Timer {
        readonly property int fps: (core.fps > 0 ? core.fps : 12) * (core.mood === "calm" ? 1 : 2)
        running: core.running && !core.reducedMotion && core._timed
        interval: Math.round(1000 / fps); repeat: true
        onTriggered: core._step(interval / 1000)
    }
    Timer {   // reduced motion: slow breathing at 12 fps
        running: core.running && core.reducedMotion
        interval: 83; repeat: true
        onTriggered: core._step(0.083)
    }

    Canvas {
        id: canvas
        // only the square around the core is repainted each frame (cheaper than full screen)
        readonly property real side: Math.min(core.width, core.height) * (core.compact ? 1.0 : 1.3)   // room for the expanded (ok) dial
        width: side; height: side
        anchors.centerIn: parent
        renderStrategy: Canvas.Cooperative
        onSideChanged: requestPaint()

        function rgba(c, a) {
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + Math.max(0, Math.min(1, a)).toFixed(3) + ")"
        }
        function mix(c1, c2, k) {
            return Qt.rgba(c1.r + (c2.r - c1.r) * k, c1.g + (c2.g - c1.g) * k, c1.b + (c2.b - c1.b) * k, 1)
        }

        onPaint: {
            const ctx = getContext("2d")
            const W = width, H = height, cx = W / 2, cy = H / 2
            ctx.reset()
            ctx.clearRect(0, 0, W, H)
            const pts = core._pts, links = core._links
            if (!pts.length) return

            const small = core.compact
            const R = core.radius
            const e = Math.min(1, core._energy + core._kick * 0.6)
            const t = core._t
            const A = core._a, B = core._b, C = core._c
            const fl = core._flash
            const glowK = 1 + 0.6 * core._listen      // listening: glow ×1.6
            const think = core._think, speak = core._speak

            // ── ambient glow (soft lavender) ──
            if (!small) {
                let g = ctx.createRadialGradient(cx, cy, R * 0.2, cx, cy, R * 2.0)
                g.addColorStop(0, rgba(B, (0.16 + 0.14 * e + 0.25 * fl) * glowK))
                g.addColorStop(0.55, rgba(A, (0.05 + 0.05 * e) * glowK))
                g.addColorStop(1, rgba(B, 0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, W, H)
            }

            // ── heartbeat core ──
            const beatRate = 0.9 + e * 1.4
            const beat = Math.pow(Math.abs(Math.sin(t * Math.PI * beatRate)), 8)
            const coreR = R * (0.42 + 0.10 * beat + 0.06 * e)
            let g2 = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR)
            g2.addColorStop(0, rgba(Qt.lighter(B, 1.25), Math.min(1, (0.38 + 0.30 * beat) * glowK)))
            g2.addColorStop(0.4, rgba(B, (0.18 + 0.18 * beat) * glowK))
            g2.addColorStop(1, rgba(B, 0))
            ctx.fillStyle = g2
            ctx.beginPath(); ctx.arc(cx, cy, coreR, 0, Math.PI * 2); ctx.fill()

            // ── speaking: rings leaving the centre ──
            if (speak > 0.01) {
                ctx.lineWidth = small ? 1 : 1.4
                const waves = core._waves
                for (let w = 0; w < waves.length; w++) {
                    const age = (t - waves[w]) / 1.4      // 0 → 1
                    ctx.strokeStyle = rgba(w % 2 ? C : B, 0.55 * (1 - age) * speak)
                    ctx.beginPath(); ctx.arc(cx, cy, R * (0.3 + 1.3 * age), 0, Math.PI * 2); ctx.stroke()
                }
            }

            // ── project sphere ──
            const cy_ = Math.cos(core._ry), sy_ = Math.sin(core._ry)
            const cx_ = Math.cos(core._rx), sx_ = Math.sin(core._rx)
            const breathe = core.reducedMotion ? 1 + 0.02 * Math.sin(t * 0.8) : 1
            const P = new Array(pts.length)
            for (let i = 0; i < pts.length; i++) {
                const p = pts[i]
                const x1 = p[0] * cy_ + p[2] * sy_
                const z1 = -p[0] * sy_ + p[2] * cy_
                const y2 = p[1] * cx_ - z1 * sx_
                const z2 = p[1] * sx_ + z1 * cx_
                const persp = 1 / (1.9 - z2 * 0.55)
                // speaking: nodes vibrate ±5 %
                const vib = speak > 0.01 ? 1 + 0.05 * speak * Math.sin(t * 31 + i * 1.7) : 1
                const rr = R * breathe * 1.9 * persp * vib
                P[i] = [cx + x1 * rr, cy + y2 * rr, z2, p[3]]   // z2: -1 back … +1 front
            }

            // ── links, batched in 3 depth buckets: lavender at the back, lavender → cyan towards the front ──
            ctx.lineWidth = small ? 0.6 : 1
            const buckets = [[], [], []], extra = [[], [], []]
            for (let k = 0; k < links.length; k++) {
                const L = links[k]
                const z = (P[L[0]][2] + P[L[1]][2]) / 2
                const b = z < -0.3 ? 0 : (z < 0.35 ? 1 : 2)
                if (L[2]) { if (think > 0.01) extra[b].push(L) } else buckets[b].push(L)
            }
            const linkAlpha = [0.07, 0.16, 0.30]
            const linkCol = [B, mix(B, C, 0.35), mix(B, C, 0.7)]
            for (let b = 0; b < 3; b++) {
                for (let pass = 0; pass < 2; pass++) {
                    const arr = pass === 0 ? buckets[b] : extra[b]
                    if (!arr.length) continue
                    const a = linkAlpha[b] * (0.65 + 0.7 * e) + 0.2 * fl
                    ctx.strokeStyle = rgba(linkCol[b], pass === 0 ? a : a * think)
                    ctx.beginPath()
                    for (let k = 0; k < arr.length; k++) {
                        const p1 = P[arr[k][0]], p2 = P[arr[k][1]]
                        ctx.moveTo(p1[0], p1[1]); ctx.lineTo(p2[0], p2[1])
                    }
                    ctx.stroke()
                }
            }

            // ── nodes: 3 depth buckets × 3 colours ──
            const cols = [A, B, C]
            const nodeA = [0.35, 0.7, 0.95]
            const nodeR = small ? [0.5, 0.75, 1.0] : [1.1, 1.6, 2.2]
            const nb = [[[], [], []], [[], [], []], [[], [], []]]
            for (let i = 0; i < P.length; i++) nb[P[i][2] < -0.3 ? 0 : (P[i][2] < 0.35 ? 1 : 2)][P[i][3]].push(P[i])
            // halos around the front nodes (not in the compact core)
            if (!small) {
                for (let c = 0; c < 3; c++) {
                    const arr = nb[2][c]
                    ctx.fillStyle = rgba(cols[c], 0.14 * glowK)
                    ctx.beginPath()
                    const r = nodeR[2] * 2.6
                    for (let i = 0; i < arr.length; i++) { ctx.moveTo(arr[i][0] + r, arr[i][1]); ctx.arc(arr[i][0], arr[i][1], r, 0, Math.PI * 2) }
                    ctx.fill()
                }
            }
            for (let b = 0; b < 3; b++) {
                const r = nodeR[b] * (1 + 0.4 * e)
                for (let c = 0; c < 3; c++) {
                    const arr = nb[b][c]
                    if (!arr.length) continue
                    ctx.fillStyle = rgba(b === 2 ? Qt.lighter(cols[c], 1.15) : cols[c], nodeA[b])
                    ctx.beginPath()
                    for (let i = 0; i < arr.length; i++) {
                        ctx.moveTo(arr[i][0] + r, arr[i][1])
                        ctx.arc(arr[i][0], arr[i][1], r, 0, Math.PI * 2)
                    }
                    ctx.fill()
                }
            }

            // ── synapse pulses (thinking: up to 60 at once) ──
            const pulses = core._pulses
            const nPulses = Math.round((small ? 8 : 26) + (small ? 10 : 34) * think)
            for (let q = 0; q < nPulses && q < pulses.length; q++) {
                const pu = pulses[q]
                const L = links[pu.l]; if (!L) continue
                if (L[2] && think < 0.01) continue
                const a = P[L[0]], c = P[L[1]]
                if ((a[2] + c[2]) / 2 < -0.4) continue
                const x = a[0] + (c[0] - a[0]) * pu.p, y = a[1] + (c[1] - a[1]) * pu.p
                const fade = Math.sin(pu.p * Math.PI)
                if (!small) {
                    ctx.fillStyle = rgba(C, 0.18 * fade * (0.5 + e))
                    ctx.beginPath(); ctx.arc(x, y, 6, 0, Math.PI * 2); ctx.fill()
                }
                ctx.fillStyle = rgba(Qt.lighter(C, 1.3), 0.9 * fade)
                ctx.beginPath(); ctx.arc(x, y, small ? 0.9 : 1.8, 0, Math.PI * 2); ctx.fill()
            }

            if (small || core.bare) return

            if (core.hud) {
                // ── HUD: everything turns slowly ──
                const rot = core.reducedMotion ? 0 : t * 0.05
                // faint ring at 1.56 r
                ctx.lineWidth = 1
                ctx.strokeStyle = rgba(B, 0.14)
                ctx.beginPath(); ctx.arc(cx, cy, R * 1.56, 0, Math.PI * 2); ctx.stroke()
                // 90 dial ticks at 1.45 r, every 5th longer
                ctx.strokeStyle = rgba(B, 0.22 + 0.12 * e)
                ctx.beginPath()
                for (let i = 0; i < 90; i++) {
                    const ang = rot + i / 90 * Math.PI * 2
                    const len = i % 5 === 0 ? R * 0.07 : R * 0.03
                    ctx.moveTo(cx + Math.cos(ang) * R * 1.45, cy + Math.sin(ang) * R * 1.45)
                    ctx.lineTo(cx + Math.cos(ang) * (R * 1.45 + len), cy + Math.sin(ang) * (R * 1.45 + len))
                }
                ctx.stroke()
                // two lavender arcs at 1.64 r (0.9 rad and 0.35 rad) one way, a cyan arc at 1.72 r the other way
                const arcRot = core.reducedMotion ? 0 : t * (0.16 + 0.4 * e) * (1 + 2 * think)
                ctx.lineWidth = 2
                ctx.strokeStyle = rgba(B, 0.7 + 0.25 * fl)
                ctx.beginPath(); ctx.arc(cx, cy, R * 1.64, arcRot - 2.4, arcRot - 2.4 + 0.9, false); ctx.stroke()
                ctx.beginPath(); ctx.arc(cx, cy, R * 1.64, arcRot + 0.9, arcRot + 0.9 + 0.35, false); ctx.stroke()
                ctx.strokeStyle = rgba(C, 0.7)
                ctx.beginPath(); ctx.arc(cx, cy, R * 1.72, -arcRot - 0.2, -arcRot + 0.45, false); ctx.stroke()
                // dotted elliptical orbit (rx 1.38 r, ry 0.34 r, tilted −0.18 rad) with a cyan satellite
                const tilt = -0.18, ct = Math.cos(tilt), st = Math.sin(tilt)
                const rx = R * 1.38, ry = R * 0.34
                ctx.fillStyle = rgba(C, 0.35)
                ctx.beginPath()
                for (let d = 0; d < 120; d++) {
                    const ang = d / 120 * Math.PI * 2
                    const ex = Math.cos(ang) * rx, ey = Math.sin(ang) * ry
                    const X = cx + ex * ct - ey * st, Y = cy + ex * st + ey * ct
                    ctx.moveTo(X + 0.7, Y); ctx.arc(X, Y, 0.7, 0, Math.PI * 2)
                }
                ctx.fill()
                const sa = core.reducedMotion ? 2.6 : t * 0.45 + 2.6
                const sx = Math.cos(sa) * rx, sy = Math.sin(sa) * ry
                const SX = cx + sx * ct - sy * st, SY = cy + sx * st + sy * ct
                ctx.fillStyle = rgba(C, 0.25)
                ctx.beginPath(); ctx.arc(SX, SY, 5, 0, Math.PI * 2); ctx.fill()
                ctx.fillStyle = rgba(Qt.lighter(C, 1.2), 0.95)
                ctx.beginPath(); ctx.arc(SX, SY, 2.2, 0, Math.PI * 2); ctx.fill()
                return
            }

            // ── tilted dashed orbital rings (lock / launcher / SDDM look) ──
            const rings = [
                { tilt: 0.28, rot: 0.35,  speed: 0.20, r: 1.28, col: C, dash: 48 },
                { tilt: 0.42, rot: -0.85, speed: -0.14, r: 1.38, col: A, dash: 36 },
                { tilt: 0.16, rot: 1.45,  speed: 0.09, r: 1.46, col: B, dash: 64 }
            ]
            for (let r = 0; r < rings.length; r++) {
                const ring = rings[r]
                const rad = R * ring.r
                const off = t * ring.speed * (1 + e * 1.5)
                ctx.strokeStyle = rgba(ring.col, 0.28 + 0.25 * e + 0.3 * fl)
                ctx.lineWidth = 1.2
                ctx.beginPath()
                const cr = Math.cos(ring.rot), sr = Math.sin(ring.rot)
                const n = ring.dash
                for (let d = 0; d < n; d++) {
                    // dash = 55% of segment, drawn as polyline of 4 sub-steps (ellipse in rotated frame)
                    const a0 = off + d / n * Math.PI * 2
                    const a1 = a0 + (Math.PI * 2 / n) * 0.55
                    for (let s = 0; s <= 4; s++) {
                        const ang = a0 + (a1 - a0) * s / 4
                        const ex = Math.cos(ang) * rad, ey = Math.sin(ang) * rad * ring.tilt
                        const X = cx + ex * cr - ey * sr, Y = cy + ex * sr + ey * cr
                        if (s === 0) ctx.moveTo(X, Y); else ctx.lineTo(X, Y)
                    }
                }
                ctx.stroke()
            }

            // ── outer HUD dial ──
            const dialR = R * 1.62
            const dialRot = core.reducedMotion ? 0 : t * 0.05
            ctx.lineWidth = 1
            ctx.strokeStyle = rgba(C, 0.22 + 0.15 * e)
            ctx.beginPath()
            for (let i = 0; i < 120; i++) {
                const ang = dialRot + i / 120 * Math.PI * 2
                const len = i % 10 === 0 ? 10 : (i % 5 === 0 ? 6 : 3)
                ctx.moveTo(cx + Math.cos(ang) * dialR, cy + Math.sin(ang) * dialR)
                ctx.lineTo(cx + Math.cos(ang) * (dialR + len), cy + Math.sin(ang) * (dialR + len))
            }
            ctx.stroke()

            const arcR = dialR + 18
            const arcRot2 = core.reducedMotion ? 0 : -t * (0.18 + 0.6 * e)
            ctx.lineWidth = 2.2
            ctx.strokeStyle = rgba(B, 0.55 + 0.3 * e + 0.3 * fl)
            const segs = [[0.0, 0.55], [1.9, 2.25], [3.4, 4.6], [5.2, 5.5]]
            for (let s = 0; s < segs.length; s++) {
                ctx.beginPath()
                ctx.arc(cx, cy, arcR, arcRot2 + segs[s][0], arcRot2 + segs[s][1], false)
                ctx.stroke()
            }
            ctx.lineWidth = 1
            ctx.strokeStyle = rgba(B, 0.25)
            ctx.beginPath(); ctx.arc(cx, cy, arcR + 8, 0, Math.PI * 2); ctx.stroke()
        }
    }
}
