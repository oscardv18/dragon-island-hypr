// =============================================================================
// dragon-island — CaptureWindow.qml (namespace "dragon-capture", layer Overlay, no blur) · docs/design/13-capturas.png
// The capture overlay on the monitor of Capture.screenName while Capture.active:
//   · the screen FROZEN (ScreencopyView of the monitor, live: false) under a 62 % dim
//   · the mode bar where the island is: Región · Ventana · Pantalla │ ● grabar · 3 s (it covers the island, so it is
//     drawn here, with the island's look)
//   region  drag to draw; cyan 1.5 px frame, rule-of-thirds grid, handles on the corners and side centres, the size
//           in mono; drag a handle to resize, Space + drag to move
//   window  the window under the pointer is highlighted (HyprlandToplevel geometry); click picks it
//   screen  the whole monitor
//   then    an action bar under the selection: Copiar (primary, cyan) · Guardar · Anotar (satty / swappy) · Texto
//           (tesseract) — the optional ones only when installed; ● records that area
// Keys: 1–3 mode · Enter copy · Esc close. Shooting is Capture.shoot (it unmaps this window, then grim -g).
// =============================================================================
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""
    readonly property bool open: Capture.active && Capture.screenName === screenName

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    visible: open
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-capture"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // selection in window coordinates; has = something chosen (the action bar shows)
    property real sx: 0
    property real sy: 0
    property real sw: 0
    property real sh: 0
    property bool has: false
    property bool spaceDown: false
    readonly property real gx: modelData?.x ?? 0
    readonly property real gy: modelData?.y ?? 0

    function reset(): void {
        win.has = false;
        if (Capture.mode === "screen") { win.sx = 0; win.sy = 0; win.sw = win.width; win.sh = win.height; win.has = true; }
        else { win.sw = 0; win.sh = 0; }
    }
    onOpenChanged: if (open) { reset(); Qt.callLater(() => keys.forceActiveFocus()); }
    Connections { target: Capture; function onModeChanged() { win.reset(); } }

    function geometry(): string {
        return `${Math.round(win.gx + win.sx)},${Math.round(win.gy + win.sy)} ${Math.round(win.sw)}x${Math.round(win.sh)}`;
    }
    function act(action: string): void { if (win.has && win.sw >= 2 && win.sh >= 2) Capture.shoot(win.geometry(), action); }

    // windows of the visible workspace on this monitor (window mode), topmost first
    readonly property var wins: {
        if (!open) return [];
        const mon = Hyprland.monitorFor(win.screen);
        const ws = mon?.activeWorkspace;
        if (!ws) return [];
        return ws.toplevels.values.map(t => t.lastIpcObject).filter(o => o && o.at && o.size && !o.hidden)
            .map(o => ({ x: o.at[0] - win.gx, y: o.at[1] - win.gy, w: o.size[0], h: o.size[1], floating: o.floating }))
            .sort((a, b) => (b.floating ? 1 : 0) - (a.floating ? 1 : 0));
    }
    property var hoverWin: null

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { Capture.close(); e.accepted = true; }
            else if (e.key === Qt.Key_1) { Capture.setMode("region"); e.accepted = true; }
            else if (e.key === Qt.Key_2) { Capture.setMode("window"); e.accepted = true; }
            else if (e.key === Qt.Key_3) { Capture.setMode("screen"); e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.act("copy"); e.accepted = true; }
            else if (e.key === Qt.Key_Space && !e.isAutoRepeat) { win.spaceDown = true; e.accepted = true; }
        }
        Keys.onReleased: e => { if (e.key === Qt.Key_Space && !e.isAutoRepeat) win.spaceDown = false; }
    }

    // ---- the frozen screen ----
    ScreencopyView {
        anchors.fill: parent
        captureSource: win.open ? win.screen : null
        live: false
    }

    // ---- dim outside the selection (62 %) ----
    Rectangle { x: 0; y: 0; width: parent.width; height: win.has || win.sw > 0 ? win.sy : parent.height; color: Theme.captureDim }
    Rectangle { visible: win.has || win.sw > 0; x: 0; y: win.sy + win.sh; width: parent.width; height: parent.height - y; color: Theme.captureDim }
    Rectangle { visible: win.has || win.sw > 0; x: 0; y: win.sy; width: win.sx; height: win.sh; color: Theme.captureDim }
    Rectangle { visible: win.has || win.sw > 0; x: win.sx + win.sw; y: win.sy; width: parent.width - x; height: win.sh; color: Theme.captureDim }

    // ---- window mode: the window under the pointer ----
    Rectangle {
        visible: Capture.mode === "window" && win.hoverWin !== null && !win.has
        x: win.hoverWin?.x ?? 0
        y: win.hoverWin?.y ?? 0
        width: win.hoverWin?.w ?? 0
        height: win.hoverWin?.h ?? 0
        color: Theme.alpha(Theme.cyan, 0.10)
        border.width: 2
        border.color: Theme.cyan
        radius: 6
    }

    // ---- mouse: draw / resize / move (region), pick (window) ----
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Capture.mode === "window" ? Qt.PointingHandCursor : (win.spaceDown ? Qt.SizeAllCursor : Qt.CrossCursor)
        property real ox: 0
        property real oy: 0
        property real bx: 0
        property real by: 0
        property string drag: ""      // "new" | "move" | a handle: "tl" "t" "tr" "r" "br" "b" "bl" "l"
        onPositionChanged: m => {
            if (Capture.mode === "window" && !win.has) {
                win.hoverWin = win.wins.find(w => m.x >= w.x && m.x < w.x + w.w && m.y >= w.y && m.y < w.y + w.h) ?? null;
                return;
            }
            if (!pressed) return;
            const dx = m.x - ox, dy = m.y - oy;
            if (drag === "move") {
                win.sx = Math.max(0, Math.min(win.width - win.sw, bx + dx));
                win.sy = Math.max(0, Math.min(win.height - win.sh, by + dy));
            } else if (drag === "new") {
                win.sx = Math.min(ox, m.x); win.sy = Math.min(oy, m.y);
                win.sw = Math.abs(m.x - ox); win.sh = Math.abs(m.y - oy);
            } else if (drag.length > 0) {
                let x0 = bx, y0 = by, x1 = bx + area.bw, y1 = by + area.bh;
                if (drag.includes("l")) x0 = Math.min(x1 - 4, bx + dx);
                if (drag.includes("r")) x1 = Math.max(x0 + 4, bx + area.bw + dx);
                if (drag.includes("t")) y0 = Math.min(y1 - 4, by + dy);
                if (drag.includes("b")) y1 = Math.max(y0 + 4, by + area.bh + dy);
                win.sx = x0; win.sy = y0; win.sw = x1 - x0; win.sh = y1 - y0;
            }
        }
        property real bw: 0
        property real bh: 0
        onPressed: m => {
            ox = m.x; oy = m.y; bx = win.sx; by = win.sy; bw = win.sw; bh = win.sh;
            if (Capture.mode === "window") { drag = ""; return; }
            if (Capture.mode === "screen") { drag = ""; return; }
            const inSel = win.has && m.x >= win.sx && m.x <= win.sx + win.sw && m.y >= win.sy && m.y <= win.sy + win.sh;
            drag = win.spaceDown && inSel ? "move" : "new";
            if (drag === "new") win.has = false;
        }
        onReleased: m => {
            if (Capture.mode === "window") {
                const w = win.hoverWin;
                if (w) { win.sx = w.x; win.sy = w.y; win.sw = w.w; win.sh = w.h; win.has = true; }
                return;
            }
            if (drag !== "" && win.sw > 3 && win.sh > 3) win.has = true;
            drag = "";
        }
    }

    // ---- the selection frame: cyan 1.5 px, thirds, handles, size ----
    Item {
        visible: Capture.mode !== "window" && win.sw > 0 && win.sh > 0 || (Capture.mode === "window" && win.has)
        x: win.sx
        y: win.sy
        width: win.sw
        height: win.sh

        Rectangle { anchors.fill: parent; color: Theme.transparent; border.width: 1.5; border.color: Theme.cyan }
        Repeater {
            model: [1, 2]
            delegate: Item {
                required property int modelData
                anchors.fill: parent
                Rectangle { x: parent.width * modelData / 3; width: 1; height: parent.height; color: Theme.alpha(Theme.text, 0.22) }
                Rectangle { y: parent.height * modelData / 3; height: 1; width: parent.width; color: Theme.alpha(Theme.text, 0.22) }
            }
        }
        Repeater {
            model: Capture.mode === "region" ? [["tl", 0, 0], ["t", 0.5, 0], ["tr", 1, 0], ["r", 1, 0.5], ["br", 1, 1], ["b", 0.5, 1], ["bl", 0, 1], ["l", 0, 0.5]] : []
            delegate: Rectangle {
                required property var modelData
                width: 12
                height: 12
                radius: 3
                x: parent.width * modelData[1] - width / 2
                y: parent.height * modelData[2] - height / 2
                color: Theme.text
                border.width: 1.5
                border.color: Theme.cyan
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: modelData[0] === "t" || modelData[0] === "b" ? Qt.SizeVerCursor
                               : (modelData[0] === "l" || modelData[0] === "r" ? Qt.SizeHorCursor
                               : (modelData[0] === "tl" || modelData[0] === "br" ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor))
                    preventStealing: true
                    onPressed: m => {
                        const p = mapToItem(area, m.x, m.y);
                        area.ox = p.x; area.oy = p.y; area.bx = win.sx; area.by = win.sy; area.bw = win.sw; area.bh = win.sh;
                        area.drag = modelData[0];
                    }
                    onPositionChanged: m => {
                        const p = mapToItem(area, m.x, m.y);
                        const dx = p.x - area.ox, dy = p.y - area.oy, d = area.drag;
                        let x0 = area.bx, y0 = area.by, x1 = area.bx + area.bw, y1 = area.by + area.bh;
                        if (d.includes("l")) x0 = Math.min(x1 - 4, area.bx + dx);
                        if (d.includes("r")) x1 = Math.max(x0 + 4, area.bx + area.bw + dx);
                        if (d.includes("t")) y0 = Math.min(y1 - 4, area.by + dy);
                        if (d.includes("b")) y1 = Math.max(y0 + 4, area.by + area.bh + dy);
                        win.sx = x0; win.sy = y0; win.sw = x1 - x0; win.sh = y1 - y0;
                    }
                    onReleased: { area.drag = ""; win.has = win.sw > 3 && win.sh > 3; }
                }
            }
        }
        // size label above the frame (inside it when there is no room)
        Rectangle {
            x: 0
            y: parent.y > 30 ? -height - 6 : 6
            width: sizeText.implicitWidth + 16
            height: 24
            radius: 6
            color: Theme.alpha(Theme.islandInk, 0.85)
            UiText { id: sizeText; anchors.centerIn: parent; text: `${Math.round(win.sw)} × ${Math.round(win.sh)}`; mono: true; size: Theme.sizeCaption + 1 }
        }
    }

    // ---- actions under the selection ----
    Rectangle {
        id: actions
        visible: win.has
        readonly property real below: win.sy + win.sh + 12
        x: Math.max(12, Math.min(win.width - width - 12, win.sx + win.sw / 2 - width / 2))
        y: below + height + 12 < win.height ? below : Math.max(12, win.sy + win.sh - height - 12)
        width: actRow.implicitWidth + 12
        height: 44
        radius: 12
        color: Theme.alpha(Theme.islandInk, 0.92)
        border.width: 1
        border.color: Theme.glassBorder
        Row {
            id: actRow
            anchors.centerIn: parent
            spacing: 4
            CaptureAction { icon: Icons.copy; label: "Copiar"; primary: true; onPressed: win.act("copy") }
            CaptureAction { icon: Icons.download; label: "Guardar"; onPressed: win.act("save") }
            CaptureAction { visible: Capture.canAnnotate; icon: Icons.pencil; label: "Anotar"; onPressed: win.act("annotate") }
            CaptureAction { visible: Capture.canOcr; icon: Icons.textRecognition; label: "Texto"; onPressed: win.act("ocr") }
        }
    }

    // ---- the mode bar where the island is ----
    Rectangle {
        id: modeBar
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.notchAttached ? 0 : Theme.notchTop
        height: Theme.barHeight + 12
        width: modeRow.implicitWidth + 16
        radius: Theme.notchAttached ? 0 : height / 2
        bottomLeftRadius: height / 2
        bottomRightRadius: height / 2
        color: Theme.islandInk
        Row {
            id: modeRow
            anchors.centerIn: parent
            spacing: 4
            CaptureAction { icon: Icons.selection; label: "Región"; checked: Capture.mode === "region"; onPressed: Capture.setMode("region") }
            CaptureAction { icon: Icons.window; label: "Ventana"; checked: Capture.mode === "window"; onPressed: Capture.setMode("window") }
            CaptureAction { icon: Icons.desktop; label: "Pantalla"; checked: Capture.mode === "screen"; onPressed: Capture.setMode("screen") }
            Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.divider }
            // ● record the selection (the whole screen when nothing is selected yet)
            Rectangle {
                width: 34
                height: 34
                radius: 17
                anchors.verticalCenter: parent.verticalCenter
                color: recMouse.containsMouse ? Theme.hoverOverlay : Theme.transparent
                Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: Theme.error }
                MouseArea {
                    id: recMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!win.has) { win.sx = 0; win.sy = 0; win.sw = win.width; win.sh = win.height; win.has = true; }
                        win.act("record");
                    }
                }
            }
            CaptureAction { label: Capture.delay > 0 ? `${Capture.delay} s` : "0 s"; checked: Capture.delay > 0; onPressed: Capture.toggleDelay() }
        }
    }

    // ---- keys hint ----
    Row {
        x: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 6
        KeyCombo { keys: ["Espacio"] }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "MOVER ·"; mono: true; size: Theme.sizeCaption; color: Theme.textSoft }
        KeyCombo { keys: ["1–3"] }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "MODO ·"; mono: true; size: Theme.sizeCaption; color: Theme.textSoft }
        KeyCombo { keys: ["Esc"] }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "CANCELAR"; mono: true; size: Theme.sizeCaption; color: Theme.textSoft }
    }
}
