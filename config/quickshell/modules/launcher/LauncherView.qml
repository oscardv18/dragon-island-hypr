// LauncherView.qml — "orbital launcher" built on the neural core (pure QtQuick, no Quickshell imports)
//
// The core is the planet; the search field sits in its centre; apps orbit on a tilted ring (Saturn).
// Typing filters the list (matches stay on the ring, best match comes to the front). The core reacts:
// pulses on every key, turns red when nothing matches, expands in green when an app launches.
//
// In:   apps: [{ id, name, subtitle, icon }]   icon = image url ("" → initial letter), pre-sorted by
//             the caller (frecency); the view only re-orders by match quality.
//       open: bool (animates in/out), query is internal (TextInput)
// Out:  activated(string id), closeRequested(), queryChanged(string text)
// Info: settled (true when fully closed → the wrapper may hide the window)

import QtQuick
import QtQuick.Shapes
import "../../components"

Item {
    id: view

    property var apps: []
    property bool open: true
    property string uiFont: "Outfit"
    property string monoFont: "JetBrains Mono"
    property bool reducedMotion: false
    property int pointCount: 220
    property int capacity: 12                 // slots on the ring
    property string placeholder: "Buscar apps…"
    property var coreIdentity: undefined        // Launcher.qml passes Theme.coreIdentity; undefined = NeuralCore's Dragon default

    signal activated(string id)
    signal closeRequested()

    readonly property bool settled: reveal < 0.001 && !open
    readonly property string query: input.text

    // ── design tokens: every colour and duration from `tokens` (Launcher.qml passes Theme.launcherTokens; pulido: the
    // old violet / magenta of the classic launcher are gone, it uses the identity's lavender and cyan) ──
    required property var tokens
    readonly property color cText: tokens.text
    readonly property color cDim: tokens.dim
    readonly property color cLine: tokens.line
    readonly property color cSurface: tokens.surface
    readonly property color cAccent: tokens.lavender
    readonly property color cCyan: tokens.cyan
    readonly property color cAlert: tokens.alert
    readonly property real s: Math.max(0.8, Math.min(1.6, height / 900))

    // ── state ──
    property int target: 0                      // unbounded index → the ring is circular
    property real pos: 0                        // animated copy of target
    readonly property int n: filtered.length
    readonly property int sel: n > 0 ? ((target % n) + n) % n : 0
    onTargetChanged: pos = target
    Behavior on pos { NumberAnimation { duration: view.reducedMotion ? 0 : 380; easing.type: Easing.OutCubic } }
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: view.reducedMotion ? 0 : 560; easing.type: Easing.OutCubic } }
    property bool launching: false

    // ── filtering ──
    function score(app, q) {
        const n = (app.name || "").toLowerCase()
        const g = (app.subtitle || "").toLowerCase()
        if (n === q) return 100
        if (n.startsWith(q)) return 90
        if (n.indexOf(" " + q) >= 0) return 80
        if (n.indexOf(q) >= 0) return 70
        if (g.indexOf(q) >= 0) return 50
        // subsequence ("ffx" → firefox)
        let i = 0
        for (let k = 0; k < n.length && i < q.length; k++) if (n[k] === q[i]) i++
        return i === q.length ? 30 : 0
    }
    readonly property var filtered: {
        const q = input.text.trim().toLowerCase()
        const list = apps || []
        if (q === "") return list
        const out = []
        for (let i = 0; i < list.length; i++) {
            const sc = score(list[i], q)
            if (sc > 0) out.push({ a: list[i], sc: sc, i: i })
        }
        out.sort((x, y) => y.sc - x.sc || x.i - y.i)
        return out.map(o => o.a)
    }
    onFilteredChanged: { target = 0; pos = 0 }
    readonly property bool noMatch: input.text.trim() !== "" && filtered.length === 0

    function move(delta) { if (n > 0) target += delta }
    function launch(idx) {
        if (launching || idx < 0 || idx >= filtered.length) return
        launching = true
        launchId = filtered[idx].id
        launchTimer.restart()
    }
    property string launchId: ""
    Timer { id: launchTimer; interval: view.tokens.durLaunch; onTriggered: { view.activated(view.launchId); view.launching = false } }

    function focusInput() { input.forceActiveFocus() }
    function reset() { input.text = ""; target = 0; pos = 0; launching = false }
    onOpenChanged: if (open) { reset(); focusInput() }

    // ── backdrop ──
    Rectangle { anchors.fill: parent; color: view.tokens.backdrop; opacity: 0.88 * view.reveal; z: -10 }
    Shape {
        anchors.fill: parent; z: -9; opacity: view.reveal
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: view.width / 2; centerY: view.height * 0.46
                focalX: centerX; focalY: centerY
                centerRadius: Math.max(view.width, view.height) * 0.7
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: view.tokens.vignette }
            }
            PathRectangle { width: view.width; height: view.height }
        }
    }
    MouseArea { anchors.fill: parent; z: -8; onClicked: view.closeRequested(); onWheel: wheel => view.move(wheel.angleDelta.y < 0 ? 1 : -1) }

    // ── the planet ──
    readonly property real cx: width / 2
    readonly property real cy: height * 0.46

    NeuralCore {
        id: core
        palette: view.tokens.core ?? null
        width: view.height * 0.72; height: width
        x: view.cx - width / 2; y: view.cy - height / 2
        z: 0
        scale: 0.6 + 0.4 * view.reveal
        opacity: view.reveal
        identity: view.coreIdentity
        pointCount: view.pointCount
        reducedMotion: view.reducedMotion
        running: view.reveal > 0.01
        mood: view.launching ? "ok" : (view.noMatch ? "alert" : "calm")
        energy: input.text.length > 0 ? Math.min(0.7, 0.3 + input.text.length * 0.05) : 0.1
    }

    // ── ring of apps ──
    readonly property real ringRx: Math.min(view.width * 0.36, core.radius * 2.15)
    readonly property real ringRy: ringRx * 0.30
    readonly property int slots: Math.max(3, Math.min(n, capacity))   // apps share the full ring evenly
    readonly property real step: 2 * Math.PI / slots
    readonly property real iconSize: 60 * s

    // ring guide (back half under the planet, front half over it)
    Shape {
        z: -1; opacity: view.reveal
        ShapePath {
            strokeColor: view.tokens.ringBack; strokeWidth: 1.2
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: view.cx; centerY: view.cy; radiusX: view.ringRx * view.reveal; radiusY: view.ringRy * view.reveal; startAngle: 180; sweepAngle: 180 }
        }
    }
    Shape {
        z: 4; opacity: view.reveal
        ShapePath {
            strokeColor: view.tokens.ringFront; strokeWidth: 1.4
            fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: view.cx; centerY: view.cy; radiusX: view.ringRx * view.reveal; radiusY: view.ringRy * view.reveal; startAngle: 0; sweepAngle: 180 }
        }
    }

    Repeater {
        model: view.filtered.length
        delegate: Item {
            id: slot
            required property int index
            readonly property var app: view.filtered[index]
            readonly property real raw: index - view.pos
            readonly property real d: raw - view.n * Math.round(raw / view.n)   // wrapped distance to the front
            readonly property real theta: Math.PI / 2 + d * view.step
            readonly property real depth: Math.sin(theta)                    // +1 front, −1 back
            readonly property real edge: Math.max(0, Math.min(1, view.slots / 2 + 0.5 - Math.abs(d)))
            readonly property bool current: index === view.sel
            readonly property real sc: (0.58 + 0.42 * (depth + 1) / 2) * (current ? 1.22 : 1)

            visible: edge > 0.01 && view.reveal > 0.01
            // sized (not scaled) so borders/text/icons stay crisp at every depth
            width: view.iconSize * sc; height: width
            x: view.cx + Math.cos(theta) * view.ringRx * view.reveal - width / 2
            y: view.cy + Math.sin(theta) * view.ringRy * view.reveal - height / 2
            z: depth >= 0 ? 5 + depth : -2 + depth
            opacity: (0.30 + 0.70 * (depth + 1) / 2) * edge * view.reveal * (view.launching && !current ? 0.25 : 1)
            Behavior on opacity { enabled: view.launching; NumberAnimation { duration: view.tokens.durFade } }

            // glow for the selected app
            Rectangle {
                visible: slot.current
                anchors.centerIn: parent
                width: parent.width + 14; height: width; radius: width * 0.34
                antialiasing: true
                color: "transparent"; border.width: 6
                border.color: view.tokens.cyanFaint
            }
            Rectangle {
                id: tile
                anchors.fill: parent
                radius: width * 0.30
                antialiasing: true
                color: view.cSurface
                border.width: slot.current ? 2 : 1
                border.color: slot.current ? view.cCyan : view.cLine
                gradient: Gradient {
                    GradientStop { position: 0; color: view.tokens.shine }
                    GradientStop { position: 1; color: view.tokens.clear }
                }
                Text {
                    anchors.centerIn: parent
                    visible: img.status !== Image.Ready
                    text: (slot.app.name || "?").charAt(0).toUpperCase()
                    color: slot.current ? view.cText : view.cDim
                    font.family: view.uiFont; font.pixelSize: parent.width * 0.42; font.weight: Font.DemiBold
                }
                Image {
                    id: img
                    anchors.centerIn: parent
                    width: parent.width * 0.62; height: width
                    source: slot.app.icon || ""
                    sourceSize: Qt.size(128, 128)   // fixed high-res source: crisp at any depth, no re-decode while animating
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                    asynchronous: true
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: slot.current ? view.launch(slot.index) : (view.target += Math.round(slot.d))
                onWheel: wheel => view.move(wheel.angleDelta.y < 0 ? 1 : -1)
            }
        }
    }

    // selected app label (below the front of the ring)
    Column {
        visible: view.filtered.length > 0
        opacity: view.reveal * (view.launching ? 0 : 1)
        Behavior on opacity { NumberAnimation { duration: view.tokens.durFade } }
        x: view.cx - width / 2
        y: view.cy + view.ringRy + view.iconSize * 0.95
        z: 8
        spacing: 2 * view.s
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.filtered.length > 0 ? (view.filtered[view.sel] ? view.filtered[view.sel].name : "") : ""
            color: view.cText; font.family: view.uiFont; font.pixelSize: 20 * view.s; font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.filtered.length > 0 && view.filtered[view.sel] ? (view.filtered[view.sel].subtitle || "") : ""
            color: view.cDim; font.family: view.uiFont; font.pixelSize: 13 * view.s
        }
    }

    // ── search field (centre of the planet) ──
    Rectangle {
        id: field
        z: 10
        width: 340 * view.s; height: 50 * view.s
        x: view.cx - width / 2; y: view.cy - height / 2 - 6 * view.s
        radius: height / 2
        color: view.tokens.field
        border.width: 1
        border.color: view.noMatch ? view.tokens.alertEdge : (input.activeFocus ? view.tokens.cyanEdge : view.cLine)
        Behavior on border.color { ColorAnimation { duration: view.tokens.durFade } }
        opacity: view.reveal
        scale: 0.9 + 0.1 * view.reveal

        Rectangle {
            anchors.fill: parent; anchors.margins: -4; radius: height / 2; color: "transparent"; border.width: 4
            border.color: view.noMatch ? view.tokens.alertFaint : view.tokens.cyanFaint
            visible: input.activeFocus || view.noMatch
        }
        CoreIcon {
            id: lens
            anchors { left: parent.left; leftMargin: 18 * view.s; verticalCenter: parent.verticalCenter }
            name: "search"; size: 18 * view.s; color: view.cDim
        }
        TextInput {
            id: input
            objectName: "q"
            anchors { left: lens.right; right: counter.left; verticalCenter: parent.verticalCenter; leftMargin: 12 * view.s; rightMargin: 8 * view.s }
            color: view.cText
            font.family: view.uiFont; font.pixelSize: 17 * view.s
            selectionColor: view.tokens.selection
            clip: true
            focus: true
            enabled: !view.launching
            onTextEdited: core.pulse()
            Text {
                visible: !parent.text
                text: view.placeholder
                color: view.cDim; font: parent.font
                anchors.verticalCenter: parent.verticalCenter
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) { if (text !== "") text = ""; else view.closeRequested(); event.accepted = true }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { view.move(-1); event.accepted = true }
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) { view.move(1); event.accepted = true }
                else if (event.key === Qt.Key_Backtab) { view.move(-1); event.accepted = true }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { view.launch(view.sel); event.accepted = true }
            }
        }
        Text {
            id: counter
            anchors { right: parent.right; rightMargin: 18 * view.s; verticalCenter: parent.verticalCenter }
            text: view.noMatch ? "0" : (input.text !== "" ? view.filtered.length : "")
            color: view.noMatch ? view.cAlert : view.cDim
            font.family: view.monoFont; font.pixelSize: 12 * view.s
        }
    }

    // hints
    Text {
        z: 10
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 * view.s }
        opacity: view.reveal * 0.85
        text: view.noMatch ? "Sin resultados" : "←  →  navegar      ⏎  abrir      esc  cerrar"
        color: view.noMatch ? view.cAlert : view.tokens.hint
        font.family: view.monoFont; font.pixelSize: 11 * view.s; font.letterSpacing: 1.5 * view.s
        font.capitalization: Font.AllUppercase
    }
}
