// =============================================================================
// dragon-island — SwitcherWindow.qml (namespace "dragon-switcher", layer Overlay) · docs/design/10-alttab.png
// The orbital Alt+Tab, one per monitor, mapped only while services/Switcher.qml shows it (ShellState panel
// "switcher"). Exclusive keyboard focus while open; one blur region (the whole layer, alpha mask: the backdrop).
//   chips  Todas · Este escritorio · Por app, with their counts (click)
//   ring   ~470 × 110 ellipse of cards, the chosen one at the front (~440 px), depth from the sine like the launcher;
//          12 at most, the rest turn in with the wheel / Tab
//   under  «App · título» and «Escritorio N · activa hace X»
//   keys   Tab / ⇧Tab (Hyprland's binds while Alt is held) · ← → · Q close the chosen window · 1–5 that workspace only
//          · Enter or releasing Alt confirm · Esc cancels
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-switcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool open: Switcher.shown && (ShellState.panelScreen === "" || ShellState.panelScreen === screenName)
    visible: open || lingering.running
    onOpenChanged: if (open) { keys.forceActiveFocus(); win.pos = Switcher.index; win._last = Switcher.index; } else lingering.restart()
    Timer { id: lingering; interval: Theme.durOut + 60 }
    mask: open ? null : idle
    Region { id: idle }

    readonly property real gs: Math.min(width / Theme.gravityDesignW, height / Theme.gravityDesignH)
    readonly property real cx: width / 2
    readonly property real cy: height * Theme.switcherCenterY
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: win.open ? Theme.durEmerge : Theme.durOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.open ? Theme.curveOrbita : Theme.curveSalida
        }
    }

    // ring position: unbounded, so the ring always turns the short way
    readonly property int count: Switcher.list.length
    readonly property real step: 2 * Math.PI / Math.max(3, Math.min(count, Theme.switcherMax))
    readonly property int chosenIndex: Math.max(0, Math.min(Switcher.index, count - 1))
    property real pos: 0
    property int _last: 0
    Behavior on pos { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita } }
    Connections {
        target: Switcher
        function onIndexChanged() {
            const n = Math.max(1, win.count);
            let delta = Switcher.index - win._last;
            delta -= n * Math.round(delta / n);
            win._last = Switcher.index;
            win.pos += delta;
        }
        function onListChanged() { win.pos = Switcher.index; win._last = Switcher.index; }
    }

    function pick(i: int): void { Switcher.pick(i); }
    function wheel(delta: int): void { if (delta !== 0) Switcher.step(delta < 0 ? 1 : -1); }
    // the title without the app's own name at its end ("design — Dolphin" → "design")
    function cleanTitle(w): string {
        const t = (w.title || "").trim(), name = (w.appName || "").trim();
        if (name.length === 0) return t;
        const parts = t.split(/ [-—–] /);
        return parts.length > 1 && parts[parts.length - 1].toLowerCase() === name.toLowerCase() ? parts.slice(0, -1).join(" — ") : t;
    }
    function shortTitle(w): string {
        const t = cleanTitle(w).split(/ [-—–·|] /)[0].trim();
        return t.length > 28 ? t.slice(0, 27) + "…" : t;
    }
    function ago(ms: real): string {
        if (!ms) return "";
        const s = Math.max(0, (Date.now() - ms) / 1000);
        if (s < 60) return "activa hace un momento";
        if (s < 3600) return `activa hace ${Math.round(s / 60)} min`;
        return `activa hace ${Math.round(s / 3600)} h`;
    }

    // backdrop (the layer's blur region) + click outside cancels
    Rectangle {
        anchors.fill: parent
        color: Theme.gravityBackdrop
        opacity: win.reveal
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Switcher.cancel()
        onWheel: wheel => win.wheel(wheel.angleDelta.y)
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Tab || k === Qt.Key_Right) Switcher.step(1);
            else if (k === Qt.Key_Backtab || k === Qt.Key_Left) Switcher.step(-1);
            else if (k === Qt.Key_Q) Switcher.closeChosen();
            else if (k >= Qt.Key_1 && k <= Qt.Key_5) Switcher.filterTo(k - Qt.Key_0);
            else if (k === Qt.Key_Escape) Switcher.cancel();
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) Switcher.confirm();
            else return;
            e.accepted = true;
        }
        // the window has the keyboard: it sees Alt go up even if Hyprland's release bind did not fire
        Keys.onReleased: e => { if (e.key === Qt.Key_Alt || e.key === Qt.Key_AltGr || e.key === Qt.Key_Meta) Switcher.confirm(); }
    }

    // ---- filter chips ----
    Row {
        z: 50
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.switcherChipsTop * win.gs
        spacing: Theme.spacingSm * win.gs
        opacity: win.reveal
        Repeater {
            model: [
                { key: "all", label: "Todas", n: Switcher.counts.all },
                { key: "workspace", label: Switcher.filter === "workspace" && Switcher.filterWorkspace !== Hypr.focusedWorkspaceId ? `Escritorio ${Switcher.filterWorkspace}` : "Este escritorio",
                  n: Switcher.filter === "workspace" ? Switcher.list.length : Switcher.counts.workspace },
                { key: "app", label: "Por app", n: Switcher.counts.app }
            ]
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: Switcher.filter === modelData.key
                height: Theme.gravityChip * 1.65 * win.gs
                width: chipText.implicitWidth + Theme.spacingLg * 2 * win.gs
                radius: height / 2
                color: on ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.05)
                Row {
                    id: chipText
                    anchors.centerIn: parent
                    spacing: Theme.spacingSm * win.gs
                    UiText { text: chip.modelData.label; size: Theme.sizeBodyLg * Math.max(1, win.gs); weight: chip.on ? Theme.weightSemiBold : Theme.weightRegular; color: chip.on ? Theme.text : Theme.textSoft }
                    UiText { text: `${chip.modelData.n}`; size: Theme.sizeBodyLg * Math.max(1, win.gs); color: Theme.textDim }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Switcher.setFilter(chip.modelData.key) }
            }
        }
    }

    // ---- the ring ----
    Repeater {
        model: win.count
        delegate: SwitcherCard {           // `index` is SwitcherCard's own required property
            ring: win
            item: Switcher.list[index] ?? ({})
        }
    }
    UiText {
        visible: win.count === 0
        anchors.centerIn: parent
        text: "Ninguna ventana en este filtro"
        size: Theme.sizeTitle * Math.max(1, win.gs)
        color: Theme.textDim
        opacity: win.reveal
    }

    // ---- the chosen window ----
    Column {
        z: 60
        visible: Switcher.chosen !== null
        opacity: win.reveal
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.cy + Theme.switcherRingRy * win.gs + Theme.switcherCard * Theme.switcherAspect * win.gs / 2 + Theme.switcherTitleGap * win.gs
        spacing: Theme.spacingXs * win.gs
        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, win.width * 0.7)
            horizontalAlignment: Text.AlignHCenter
            text: Switcher.chosen ? [Switcher.chosen.appName, win.cleanTitle(Switcher.chosen)].filter((x, i, a) => x && a.indexOf(x) === i).join(" · ") : ""
            size: Theme.sizeGreeting * Math.max(1, win.gs)
            weight: Theme.weightSemiBold
        }
        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Switcher.chosen ? [`Escritorio ${Switcher.chosen.workspace}`,
                                     Switcher.chosen.address === Hypr.activeToplevel?.address ? "activa ahora" : win.ago(Switcher.chosen.lastActive)].filter(x => x).join(" · ") : ""
            size: Theme.sizeBodyLg * Math.max(1, win.gs)
            color: Theme.textSoft
        }
    }

    KeyHints {
        z: 60
        opacity: win.reveal
        factor: Math.max(1, win.gs)
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.gravityHintsBottom * win.gs }
        hints: [["ALT+TAB", "siguiente"], ["⇧", "anterior"], ["Q", "cerrar ventana"], ["1–5", "filtrar escritorio"]]
    }
}
