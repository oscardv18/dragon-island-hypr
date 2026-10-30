// =============================================================================
// dragon-island — ClipOrbit.qml: the Gravity launcher's clipboard ring, mode «/» and SUPER + V
// (docs/design/12-portapapeles.png). The search field moves to the top (GravityView); under it the kind filters
// (Todo · Texto · Imágenes · Enlaces · Colores), then a ~470 × 125 ring of cards (ClipCard) with the chosen one at the
// front (~400 × 170) and, under it, «Comando · copiado desde Ghostty» / «hace 2 min · 48 caracteres»
// (dragon-clip meta; without it, no «copiado desde»).
// Keys (GravityView forwards them): ← → walk · Enter pastes into the window that had the focus · Ctrl+P pins ·
// Supr deletes · Espacio shows a masked secret.
// =============================================================================
import Quickshell
import QtQuick
import "../.."
import "../../services"
import "../../components"

Item {
    id: orbit

    property real gs: 1
    property string query: ""
    property string pasteAddress: ""       // the window that had the focus when the launcher opened
    property string pasteClass: ""
    signal closeRequested()

    readonly property real cx: width / 2
    readonly property real cy: height * Theme.clipCenterY

    property string filter: "all"
    readonly property var filters: [
        { key: "all", label: "Todo" }, { key: "text", label: "Texto" }, { key: "image", label: "Imágenes" },
        { key: "link", label: "Enlaces" }, { key: "color", label: "Colores" }
    ]
    function _inFilter(e): bool {
        if (filter === "all") return true;
        const k = Clipboard.info(e).kind;
        return filter === "text" ? ["text", "command", "path"].indexOf(k) >= 0 : k === filter;
    }
    // pinned first, then the most recent
    readonly property var list: {
        const found = Clipboard.search(query).filter(e => _inFilter(e));
        return found.filter(e => Clipboard.isPinned(e)).concat(found.filter(e => !Clipboard.isPinned(e)));
    }
    readonly property int count: list.length
    readonly property real step: 2 * Math.PI / Math.max(3, Math.min(count, Theme.clipMax))
    property int index: 0
    readonly property int chosenIndex: Math.max(0, Math.min(index, count - 1))
    readonly property var chosen: count > 0 ? list[chosenIndex] : null
    property bool revealed: false
    onChosenChanged: { revealed = false; if (chosen) Clipboard.requestMeta(chosen); }
    onQueryChanged: { index = 0; pos = 0; _last = 0; }
    onFilterChanged: { index = 0; pos = 0; _last = 0; }

    property real pos: 0
    property int _last: 0
    Behavior on pos { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita } }
    function choose(i: int): void {
        if (count === 0) return;
        const n = count;
        i = ((i % n) + n) % n;
        let delta = i - _last;
        delta -= n * Math.round(delta / n);
        _last = i;
        index = i;
        pos += delta;
    }
    function move(delta: int): void { choose(chosenIndex + delta); }
    function wheel(delta: int): void { if (delta !== 0) move(delta < 0 ? 1 : -1); }
    function reset(): void { filter = "all"; index = 0; pos = 0; _last = 0; revealed = false; Clipboard.refresh(); }

    function paste(): void {
        if (!chosen) return;
        const e = chosen;
        orbit.closeRequested();
        Clipboard.paste(e, pasteAddress, pasteClass);
    }
    function togglePin(): void { if (chosen) Clipboard.togglePin(chosen); }
    function remove(): void {
        if (!chosen) return;
        Clipboard.remove(chosen);
        if (index >= count - 1) index = Math.max(0, count - 2);
    }
    // keys from GravityView: true when used
    function key(event): bool {
        const k = event.key;
        if (k === Qt.Key_Left) move(-1);
        else if (k === Qt.Key_Right) move(1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) paste();
        else if (k === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) togglePin();
        else if (k === Qt.Key_Delete) remove();
        else if (k === Qt.Key_Space && chosen && Clipboard.info(chosen).secret && !revealed) revealed = true;
        else return false;
        return true;
    }

    function kindIcon(kind: string): string {
        switch (kind) {
            case "command": return Icons.terminal;
            case "link": return Icons.link;
            case "path": return Icons.folder;
            case "color": return Icons.palette;
            case "image": return Icons.image;
            default: return Icons.textLines;
        }
    }
    function appName(cls: string): string { return DesktopEntries.heuristicLookup(cls)?.name || cls; }
    function ago(t: real): string {
        if (!t) return "";
        const s = Math.max(0, Date.now() / 1000 - t);
        if (s < 60) return "hace un momento";
        if (s < 3600) return `hace ${Math.round(s / 60)} min`;
        if (s < 86400) return `hace ${Math.round(s / 3600)} h`;
        return `hace ${Math.round(s / 86400)} d`;
    }

    // ---- kind filters ----
    Row {
        z: 50
        anchors.horizontalCenter: parent.horizontalCenter
        y: (Theme.clipFieldTop + Theme.gravityFieldHeight + Theme.spacingLg + 6) * orbit.gs
        spacing: Theme.spacingSm * orbit.gs
        Repeater {
            model: orbit.filters
            delegate: Rectangle {
                id: f
                required property var modelData
                readonly property bool on: orbit.filter === modelData.key
                height: Theme.gravityChip * 1.5 * orbit.gs
                width: fl.implicitWidth + Theme.spacingLg * 2 * orbit.gs
                radius: height / 2
                color: on ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.05)
                UiText {
                    id: fl
                    anchors.centerIn: parent
                    text: f.modelData.label
                    size: Theme.sizeBodyLg * Math.max(1, orbit.gs)
                    weight: f.on ? Theme.weightSemiBold : Theme.weightRegular
                    color: f.on ? Theme.text : Theme.textSoft
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: orbit.filter = f.modelData.key }
            }
        }
    }

    // ---- the ring ----
    Repeater {
        model: orbit.count
        delegate: ClipCard {              // `index` is ClipCard's own required property
            ring: orbit
            entry: orbit.list[index] ?? ({ id: "", text: "", isImage: false, meta: "" })
        }
    }
    UiText {
        visible: orbit.count === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: orbit.cy
        text: !Clipboard.available ? "Falta cliphist" : (orbit.query.length > 0 ? "Nada coincide" : "El portapapeles está vacío")
        size: Theme.sizeTitle * Math.max(1, orbit.gs)
        color: Theme.textDim
    }

    // ---- the chosen entry ----
    Column {
        z: 60
        visible: orbit.chosen !== null
        anchors.horizontalCenter: parent.horizontalCenter
        y: orbit.cy + Theme.clipRingRy * orbit.gs + Theme.clipCardH * orbit.gs / 2 + Theme.spacingLg * orbit.gs
        spacing: Theme.spacingXs * orbit.gs
        readonly property var info: Clipboard.info(orbit.chosen)
        readonly property var meta: orbit.chosen ? (Clipboard.meta[orbit.chosen.id] ?? {}) : {}
        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: [parent.info.label, parent.meta.app ? `copiado desde ${orbit.appName(parent.meta.app)}` : ""].filter(x => x).join(" · ")
            size: Theme.sizeTitle * Math.max(1, orbit.gs)
            weight: Theme.weightSemiBold
            color: Theme.textSoft
        }
        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: orbit.chosen ? [orbit.ago(parent.meta.time ?? 0),
                                  orbit.chosen.isImage ? orbit.chosen.meta : `${(orbit.chosen.text || "").length} caracteres`].filter(x => x).join(" · ") : ""
            size: Theme.sizeBodyLg * Math.max(1, orbit.gs)
            color: Theme.textDim
        }
    }
}
