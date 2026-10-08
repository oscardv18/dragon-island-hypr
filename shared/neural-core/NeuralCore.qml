// NeuralCore.qml — dragon-island "neural core" (original design, AI-core look)
//
// Pure QtQuick (no Quickshell imports) so the same file runs in:
//   - the SDDM greeter theme  (sddm/dragon-core/components/)
//   - the Quickshell lock     (config/quickshell/components/)
//
// API
//   energy: real 0..1          base activity (typing raises it)
//   mood: string               "calm" | "verifying" | "alert" | "ok"
//   reducedMotion: bool        slow breathing, no spin
//   pointCount: int            sphere nodes (lower = cheaper), default 240
//   running: bool              pause rendering when false
//   pulse(): void              call on every key press
//   radius: real [readonly]    current sphere radius in px (for placing text inside)

import QtQuick

Item {
    id: core

    property real energy: 0.15
    property string mood: "calm"
    property bool reducedMotion: false
    property int pointCount: 240
    property bool running: visible
    readonly property real radius: Math.min(width, height) * 0.25 * _expand

    function pulse() { _kick = Math.min(1.0, _kick + 0.32) }

    // ── internal state ───────────────────────────────────────────────
    readonly property var _palettes: ({
        calm:      ["#c50ed2", "#7c3aed", "#00c1e4"],
        verifying: ["#a855f7", "#7c3aed", "#00c1e4"],
        alert:     ["#ed254e", "#ff4d73", "#f9ae58"],
        ok:        ["#06c993", "#00c1e4", "#7cf5c9"]
    })
    property color _a: "#c50ed2"
    property color _b: "#7c3aed"
    property color _c: "#00c1e4"
    Behavior on _a { ColorAnimation { duration: 420 } }
    Behavior on _b { ColorAnimation { duration: 420 } }
    Behavior on _c { ColorAnimation { duration: 420 } }

    property real _energy: Math.max(0, Math.min(1, energy + (mood === "verifying" ? 0.45 : 0) + (mood === "alert" ? 0.35 : 0)))
    Behavior on _energy { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    property real _expand: mood === "ok" ? 1.22 : 1.0
    Behavior on _expand { NumberAnimation { duration: 750; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

    property real _kick: 0
    property real _flash: 0
    property real _t: 0
    property real _ry: 0
    property real _rx: 0

    property var _pts: []      // [x,y,z] unit sphere
    property var _links: []    // [i,j]
    property var _pulses: []   // {l: linkIndex, p: progress, s: speed}

    function _applyPalette() {
        const p = _palettes[mood] || _palettes.calm
        _a = p[0]; _b = p[1]; _c = p[2]
        if (mood === "alert") _flash = 1.0
    }
    onMoodChanged: _applyPalette()

    function _build() {
        const n = Math.max(40, pointCount)
        const pts = []
        const golden = Math.PI * (3 - Math.sqrt(5))
        for (let i = 0; i < n; i++) {
            const y = 1 - (i / (n - 1)) * 2
            const r = Math.sqrt(1 - y * y)
            const th = golden * i
            // small organic jitter so it reads as a "brain", not a ball
            const j = 1 + 0.06 * Math.sin(i * 12.9898) * Math.cos(i * 4.1414)
            pts.push([Math.cos(th) * r * j, y * j, Math.sin(th) * r * j])
        }
        // neighbour links: up to 3 per node, distance threshold scales with density
        const thr = 20 / n          // ≈ (1.5 × mean node spacing)², tuned for 160–400 nodes
        const links = []
        const deg = new Array(n).fill(0)
        for (let i = 0; i < n; i++) {
            const cand = []
            for (let k = i + 1; k < n; k++) {
                const dx = pts[i][0] - pts[k][0], dy = pts[i][1] - pts[k][1], dz = pts[i][2] - pts[k][2]
                const d2 = dx * dx + dy * dy + dz * dz
                if (d2 < thr) cand.push([d2, k])
            }
            cand.sort((a, b) => a[0] - b[0])
            for (let c = 0; c < cand.length && deg[i] < 3; c++) {
                const k = cand[c][1]
                if (deg[k] >= 3) continue
                links.push([i, k]); deg[i]++; deg[k]++
            }
        }
        const pulses = []
        for (let q = 0; q < 26; q++)
            pulses.push({ l: Math.floor(Math.random() * links.length), p: Math.random(), s: 0.5 + Math.random() * 0.9 })
        _pts = pts; _links = links; _pulses = pulses
    }
    onPointCountChanged: _build()
    Component.onCompleted: { _build(); _applyPalette() }

    function _step(dt) {
        dt = Math.min(dt, 0.05)
        _t += dt
        const e = Math.min(1, _energy + _kick * 0.6)
        if (!reducedMotion) {
            _ry += dt * (0.12 + e * 0.9)
            _rx = Math.sin(_t * 0.13) * 0.38
        }
        _kick = Math.max(0, _kick - dt * 1.4)
        _flash = Math.max(0, _flash - dt * 1.1)
        for (let i = 0; i < _pulses.length; i++) {
            const pu = _pulses[i]
            pu.p += dt * pu.s * (0.35 + e * 1.6)
            if (pu.p >= 1) { pu.p = 0; pu.l = Math.floor(Math.random() * _links.length); pu.s = 0.5 + Math.random() * 0.9 }
        }
        canvas.requestPaint()
    }

    FrameAnimation {
        running: core.running && !core.reducedMotion
        onTriggered: core._step(frameTime)
    }
    Timer {   // reduced motion: slow breathing at 12 fps
        running: core.running && core.reducedMotion
        interval: 83; repeat: true
        onTriggered: core._step(0.083)
    }

    Canvas {
        id: canvas
        // only the square around the core is repainted each frame (cheaper than full screen)
        readonly property real side: Math.min(core.width, core.height) * 1.3   // room for the expanded (ok) dial
        width: side; height: side
        anchors.centerIn: parent
        renderStrategy: Canvas.Cooperative

        function rgba(c, a) {
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + Math.max(0, Math.min(1, a)).toFixed(3) + ")"
        }

        onPaint: {
            const ctx = getContext("2d")
            const W = width, H = height, cx = W / 2, cy = H / 2
            ctx.reset()
            ctx.clearRect(0, 0, W, H)
            const pts = core._pts, links = core._links
            if (!pts.length) return

            const R = core.radius
            const e = Math.min(1, core._energy + core._kick * 0.6)
            const t = core._t
            const A = core._a, B = core._b, C = core._c
            const fl = core._flash

            // ── ambient glow ──
            let g = ctx.createRadialGradient(cx, cy, R * 0.2, cx, cy, R * 2.0)
            g.addColorStop(0, rgba(B, 0.20 + 0.18 * e + 0.25 * fl))
            g.addColorStop(0.55, rgba(A, 0.06 + 0.06 * e))
            g.addColorStop(1, rgba(B, 0))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, W, H)

            // ── heartbeat core ──
            const beatRate = 0.9 + e * 1.4
            const beat = Math.pow(Math.abs(Math.sin(t * Math.PI * beatRate)), 8)
            const coreR = R * (0.42 + 0.10 * beat + 0.06 * e)
            g = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR)
            g.addColorStop(0, rgba(Qt.lighter(A, 1.6), 0.55 + 0.35 * beat))
            g.addColorStop(0.35, rgba(A, 0.30 + 0.25 * beat))
            g.addColorStop(1, rgba(B, 0))
            ctx.fillStyle = g
            ctx.beginPath(); ctx.arc(cx, cy, coreR, 0, Math.PI * 2); ctx.fill()

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
                const rr = R * breathe * 1.9 * persp
                P[i] = [cx + x1 * rr, cy + y2 * rr, z2]   // z2: -1 back … +1 front
            }

            // ── links, batched in 3 depth buckets ──
            ctx.lineWidth = 1
            const buckets = [[], [], []]
            for (let k = 0; k < links.length; k++) {
                const L = links[k]
                const z = (P[L[0]][2] + P[L[1]][2]) / 2
                buckets[z < -0.3 ? 0 : (z < 0.35 ? 1 : 2)].push(L)
            }
            const linkAlpha = [0.07, 0.16, 0.32]
            const linkCol = [B, B, C]
            for (let b = 0; b < 3; b++) {
                ctx.strokeStyle = rgba(linkCol[b], linkAlpha[b] * (0.65 + 0.7 * e) + 0.2 * fl)
                ctx.beginPath()
                const arr = buckets[b]
                for (let k = 0; k < arr.length; k++) {
                    const a = P[arr[k][0]], c = P[arr[k][1]]
                    ctx.moveTo(a[0], a[1]); ctx.lineTo(c[0], c[1])
                }
                ctx.stroke()
            }

            // ── nodes ──
            const nodeBuckets = [[], [], []]
            for (let i = 0; i < P.length; i++) nodeBuckets[P[i][2] < -0.3 ? 0 : (P[i][2] < 0.35 ? 1 : 2)].push(P[i])
            const nodeCol = [B, A, Qt.lighter(A, 1.5)]
            const nodeA = [0.35, 0.7, 0.95]
            const nodeR = [1.1, 1.6, 2.2]
            for (let b = 0; b < 3; b++) {
                ctx.fillStyle = rgba(nodeCol[b], nodeA[b])
                ctx.beginPath()
                const arr = nodeBuckets[b]
                const r = nodeR[b] * (1 + 0.4 * e)
                for (let i = 0; i < arr.length; i++) {
                    ctx.moveTo(arr[i][0] + r, arr[i][1])
                    ctx.arc(arr[i][0], arr[i][1], r, 0, Math.PI * 2)
                }
                ctx.fill()
            }

            // ── synapse pulses ──
            const pulses = core._pulses
            for (let q = 0; q < pulses.length; q++) {
                const pu = pulses[q]
                const L = links[pu.l]; if (!L) continue
                const a = P[L[0]], c = P[L[1]]
                if ((a[2] + c[2]) / 2 < -0.4) continue
                const x = a[0] + (c[0] - a[0]) * pu.p, y = a[1] + (c[1] - a[1]) * pu.p
                const fade = Math.sin(pu.p * Math.PI)
                ctx.fillStyle = rgba(C, 0.18 * fade * (0.5 + e))
                ctx.beginPath(); ctx.arc(x, y, 6, 0, Math.PI * 2); ctx.fill()
                ctx.fillStyle = rgba(Qt.lighter(C, 1.5), 0.9 * fade)
                ctx.beginPath(); ctx.arc(x, y, 1.8, 0, Math.PI * 2); ctx.fill()
            }

            // ── tilted dashed orbital rings ──
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
            const arcRot = core.reducedMotion ? 0 : -t * (0.18 + 0.6 * e)
            ctx.lineWidth = 2.2
            ctx.strokeStyle = rgba(A, 0.55 + 0.3 * e + 0.3 * fl)
            const segs = [[0.0, 0.55], [1.9, 2.25], [3.4, 4.6], [5.2, 5.5]]
            for (let s = 0; s < segs.length; s++) {
                ctx.beginPath()
                ctx.arc(cx, cy, arcR, arcRot + segs[s][0], arcRot + segs[s][1], false)
                ctx.stroke()
            }
            ctx.lineWidth = 1
            ctx.strokeStyle = rgba(B, 0.25)
            ctx.beginPath(); ctx.arc(cx, cy, arcR + 8, 0, Math.PI * 2); ctx.stroke()
        }
    }
}
