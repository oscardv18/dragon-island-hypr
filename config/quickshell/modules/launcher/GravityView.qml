// =============================================================================
// dragon-island — GravityView.qml: the «Gravedad» launcher (docs/design/02-launcher.png)
// The neural core in the centre with the search field over it; three elliptical rings of apps around it:
//   Favoritos (inner: the launcher's favourites + the apps pinned in the dock) · Frecuentes (dragon-usage frecency,
//   or Apps' launch counts without it) · Todas (the rest, alphabetical; 60 planets drawn at most, the wheel scrolls).
// Each planet: depth from the sine of its angle (smaller, dimmer, blurred at the back, under the core), size from its
// frecency, one moon per open window. The rings turn slowly in alternate directions; they stop while a planet is
// hovered, while the keyboard holds a selection, with «Reducir movimiento» and whenever the view is not shown.
// Keys: ← → rotate the selection along its ring · ↑ ↓ change ring · Enter open · Tab go to its window · Esc close.
// Left click opens, middle click closes. All actions go through services (Apps, Usage, Hypr).
// =============================================================================
import QtQuick
import QtQuick.Shapes
import "../.."
import "../../services"
import "../../components"

Item {
    id: view

    property bool shown: false
    signal launched(string id)
    signal closeRequested()

    readonly property real gs: Math.min(width / Theme.gravityDesignW, height / Theme.gravityDesignH)
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property bool active: shown || reveal > 0.001

    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: view.shown ? Theme.durOrbit : Theme.durOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: view.shown ? Theme.curveOrbita : Theme.curveSalida
        }
    }

    readonly property string query: input.text
    readonly property bool searching: query.trim().length > 0

    // ---------------------------------------------------------------- model
    readonly property var favIds: {
        const out = [];
        for (const id of Apps.favorites.concat(Dock.pinnedIds)) if (out.indexOf(id) < 0) out.push(id);
        return out;
    }
    // built only while the view is up: closed, nothing here follows window titles
    readonly property var entries: !active ? [] : Apps.list.map(e => ({
        id: e.id,
        name: e.name || "",
        subtitle: e.genericName || e.comment || "",
        keywords: e.keywords || [],
        icon: Apps.iconFor(e),
        frec: Usage.frecency(e.id),
        windows: Hypr.windowsByApp[e.id] || []
    }))
    readonly property var byId: {
        const m = {};
        for (const e of entries) m[e.id] = e;
        return m;
    }
    property int allOffset: 0
    readonly property var ring0: favIds.map(id => byId[id]).filter(e => e).slice(0, Theme.gravityRingCap[0])
    readonly property var ring1: {
        const used = {};
        for (const e of ring0) used[e.id] = true;
        return entries.filter(e => !used[e.id] && e.frec > 0).sort((a, b) => b.frec - a.frec).slice(0, Theme.gravityRingCap[1]);
    }
    readonly property var pool: {           // «Todas»: everything else, alphabetical
        const used = {};
        for (const e of ring0.concat(ring1)) used[e.id] = true;
        return entries.filter(e => !used[e.id]);
    }
    readonly property var rings: {
        const room = Math.max(0, Math.min(Theme.gravityRingCap[2], Theme.gravityMaxPlanets - ring0.length - ring1.length));
        let r2 = pool;
        if (pool.length > room) {
            const off = ((view.allOffset % pool.length) + pool.length) % pool.length;
            r2 = pool.slice(off).concat(pool.slice(0, off)).slice(0, room);
        }
        return [ring0, ring1, r2];
    }
    // one flat list of { app, ring, slot, count }; the Repeater only re-creates delegates when its length changes
    readonly property var flat: {
        const out = [];
        for (let r = 0; r < 3; r++)
            for (let i = 0; i < rings[r].length; i++) out.push({ app: rings[r][i], ring: r, slot: i, count: rings[r].length });
        return out;
    }

    // ---------------------------------------------------------------- motion
    property real spinT: 0                 // ms the rings have turned (only advances on a frame)
    property real u0: 0                    // keyboard turn of each ring (radians, animated)
    property real u1: 0
    property real u2: 0
    Behavior on u0 { NumberAnimation { duration: Theme.durOrbit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita } }
    Behavior on u1 { NumberAnimation { duration: Theme.durOrbit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita } }
    Behavior on u2 { NumberAnimation { duration: Theme.durOrbit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita } }
    function ringAngle(r: int): real {
        const dir = r % 2 === 0 ? 1 : -1;
        return dir * 2 * Math.PI * spinT / Theme.gravitySpinPeriod[r] + (r === 0 ? u0 : r === 1 ? u1 : u2);
    }
    readonly property real moonAngle: 2 * Math.PI * spinT / Theme.gravitySpinPeriod[0] * 12

    property string hoverKey: ""
    property bool keyHold: false           // a keyboard selection stops the turn until the pointer takes over
    onHoverKeyChanged: if (hoverKey !== "") keyHold = false

    // one tick moves the three rings and the moons, at the core's rate (Theme.gravityFps): the whole window repaints
    // at that rate, never at 60 Hz. Stopped while closed, hovered, held by the keyboard, searching or calm.
    Timer {
        id: spin
        interval: Math.round(1000 / Theme.gravityFps)
        repeat: true
        running: view.shown && !Settings.calmMotion && view.hoverKey === "" && !view.keyHold && !view.searching
        property real last: 0
        onRunningChanged: last = Date.now()
        onTriggered: { const now = Date.now(); view.spinT += Math.min(now - last, 100); last = now; }
    }

    // search hooks (02 at rest: nothing is pulled)
    function pullOf(id: string): real { return 0; }
    function dockPoint(id: string): point { return Qt.point(cx, cy); }
    function dockSize(id: string): real { return 1; }

    // ---------------------------------------------------------------- selection
    property int selRing: 0
    property int selSlot: 0
    readonly property string selKey: {
        const r = rings[selRing] || [];
        return r.length > 0 ? r[Math.min(selSlot, r.length - 1)].id : "";
    }
    readonly property var focusApp: byId[hoverKey] ?? byId[selKey] ?? null

    function _wrapPi(a: real): real { return a - 2 * Math.PI * Math.round(a / (2 * Math.PI)); }
    function frontSlot(r: int): int {
        const n = rings[r].length;
        let best = 0, bestD = 99;
        for (let i = 0; i < n; i++) {
            const d = Math.abs(_wrapPi(2 * Math.PI * i / n + ringAngle(r) - Math.PI / 2));
            if (d < bestD) { bestD = d; best = i; }
        }
        return best;
    }
    function turnToFront(r: int, slot: int): void {
        const n = rings[r].length;
        if (n === 0) return;
        const delta = _wrapPi(Math.PI / 2 - (2 * Math.PI * slot / n + ringAngle(r)));
        if (r === 0) u0 += delta; else if (r === 1) u1 += delta; else u2 += delta;
    }
    function select(r: int, slot: int): void {
        const n = rings[r].length;
        if (n === 0) return;
        selRing = r;
        selSlot = ((slot % n) + n) % n;
        keyHold = true;
        turnToFront(r, selSlot);
    }
    function changeRing(step: int): void {
        for (let r = selRing + step; r >= 0 && r < 3; r += step) {
            if (rings[r].length > 0) { select(r, frontSlot(r)); return; }
        }
    }

    function wheel(r: int, delta: int): void {
        if (delta === 0) return;
        if (r === 2 && view.pool.length > rings[2].length) {
            view.allOffset += delta < 0 ? 6 : -6;          // «Todas» scrolls through the apps that do not fit
            return;
        }
        const n = Math.max(1, rings[r].length);
        const step = (delta < 0 ? 1 : -1) * 2 * Math.PI / n;
        if (r === 0) u0 += step; else if (r === 1) u1 += step; else u2 += step;
    }

    function launch(id: string): void {
        if (!id) return;
        view.launched(id);
    }
    function goToWindow(id: string): void {
        const w = (byId[id]?.windows || [])[0];
        if (!w) { launch(id); return; }
        view.closeRequested();
        Hypr.focusWindow(w.address);
    }

    function focusInput(): void { input.forceActiveFocus(); }
    function reset(): void {
        input.text = "";
        hoverKey = "";
        keyHold = false;
        allOffset = 0;
        selRing = rings[0].length > 0 ? 0 : (rings[1].length > 0 ? 1 : 2);
        selSlot = 0;
        turnToFront(selRing, 0);
    }
    // later: `entries` follows `active` through a binding that has not been re-evaluated yet inside this handler
    onShownChanged: if (shown) { Usage.refresh(); Qt.callLater(reset); focusInput(); }

    // ---------------------------------------------------------------- backdrop
    Rectangle {
        anchors.fill: parent
        z: -20
        color: Theme.gravityBackdrop
        opacity: view.reveal
    }
    MouseArea {
        anchors.fill: parent
        z: -19
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: view.closeRequested()
        onWheel: wheel => view.wheel(2, wheel.angleDelta.y)
    }

    // ring guides (dashed ellipses) and their labels
    Repeater {
        model: 3
        delegate: Item {
            id: guide
            required property int index
            readonly property real rx: Theme.gravityRingRx[index] * view.gs * view.reveal
            readonly property real ry: Theme.gravityRingRy[index] * view.gs * view.reveal
            anchors.fill: parent
            z: -10
            opacity: view.reveal * (view.searching ? 0.4 : 1)
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.gravityRingStroke
                    strokeWidth: Theme.gravityRingLine
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 4]
                    fillColor: Theme.transparent
                    PathAngleArc { centerX: view.cx; centerY: view.cy; radiusX: guide.rx; radiusY: guide.ry; startAngle: 0; sweepAngle: 360 }
                }
            }
            UiText {
                visible: !view.searching
                x: view.cx + guide.rx + Theme.gravityLabelGap * view.gs
                y: view.cy - height / 2
                text: Theme.gravityRingNames[guide.index].toUpperCase()
                mono: true
                size: Theme.sizeCaption * Math.max(1, view.gs)
                color: Theme.textDim
                font.letterSpacing: 2.6 * view.gs
            }
        }
    }

    // ---------------------------------------------------------------- the core
    NeuralCore {
        id: core
        width: view.height * 0.72
        height: width
        x: view.cx - width / 2
        y: view.cy - height / 2
        z: 0
        scale: 0.6 + 0.4 * view.reveal
        opacity: view.reveal
        identity: Theme.coreIdentity
        reducedMotion: Settings.calmMotion
        fps: Theme.gravityFps
        pointCount: 220
        running: view.reveal > 0.01
        mood: "calm"
        energy: view.searching ? Math.min(0.7, 0.3 + view.query.length * 0.05) : 0.1
    }

    // ---------------------------------------------------------------- planets
    Repeater {
        model: view.flat.length
        delegate: GravityPlanet {
            required property int index
            readonly property var item: view.flat[index] ?? ({ app: ({ id: "" }), ring: 0, slot: 0, count: 1 })
            host: view
            app: item.app
            ring: item.ring
            slot: item.slot
            count: item.count
        }
    }

    // ---------------------------------------------------------------- name + detail under the core
    Column {
        z: 40
        visible: view.focusApp !== null && !view.searching
        opacity: view.reveal
        x: view.cx - width / 2
        y: view.cy + Theme.gravityNameOffset * view.gs
        spacing: Theme.spacingXs * view.gs
        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.focusApp?.name ?? ""
            size: Theme.sizeGreeting * Math.max(1, view.gs)
            weight: Theme.weightSemiBold
        }
        UiText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: view.focusApp ? Usage.detail(view.focusApp.id, view.focusApp.windows.length) : ""
            visible: text.length > 0
            size: Theme.sizeBodyLg * Math.max(1, view.gs)
            color: Theme.textSoft
        }
    }

    // ---------------------------------------------------------------- search field (over the core)
    Rectangle {
        id: field
        z: 50
        width: Theme.gravityFieldWidth * view.gs
        height: Theme.gravityFieldHeight * view.gs
        x: view.cx - width / 2
        y: view.cy - height / 2
        radius: height / 2
        color: Theme.gravityPanel
        border.width: 1
        border.color: view.searching ? Theme.gravitySelectionEdge : Theme.gravityTileEdge
        opacity: view.reveal
        scale: 0.92 + 0.08 * view.reveal

        CoreIcon {
            id: lens
            anchors { left: parent.left; leftMargin: Theme.spacingLg * view.gs; verticalCenter: parent.verticalCenter }
            name: "search"
            size: Theme.iconLg * view.gs
            color: view.searching ? Theme.cyan : Theme.textSoft
        }
        TextInput {
            id: input
            anchors { left: lens.right; right: counter.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.spacingMd * view.gs; rightMargin: Theme.spacingSm * view.gs }
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Math.round(Theme.gravityFieldFont * view.gs)
            selectionColor: Theme.violet
            cursorDelegate: Rectangle { width: 2; color: Theme.cyan }
            clip: true
            focus: true
            UiText {
                visible: !parent.text
                anchors.verticalCenter: parent.verticalCenter
                text: "Escribe para atraer apps…"
                size: Theme.gravityFieldFont * view.gs
                color: Theme.textDim
            }
            Keys.onPressed: event => view.key(event)
        }
        Rectangle {
            id: counter
            anchors { right: parent.right; rightMargin: Theme.spacingSm * view.gs; verticalCenter: parent.verticalCenter }
            height: Theme.gravityChip * view.gs
            width: count.implicitWidth + Theme.spacingLg * view.gs
            radius: Theme.keyCapRadius * view.gs
            color: Theme.alpha(Theme.text, 0.06)
            UiText {
                id: count
                anchors.centerIn: parent
                text: `${view.entries.length} apps`
                mono: true
                size: Theme.sizeCaption * Math.max(1, view.gs) + 1
                color: Theme.textSoft
            }
        }
    }

    function key(event): void {
        const k = event.key;
        if (k === Qt.Key_Escape) { if (input.text !== "") input.text = ""; else view.closeRequested(); }
        else if (k === Qt.Key_Left) select(selRing, selSlot - 1);
        else if (k === Qt.Key_Right) select(selRing, selSlot + 1);
        else if (k === Qt.Key_Up) changeRing(-1);
        else if (k === Qt.Key_Down) changeRing(1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) launch(selKey);
        else if (k === Qt.Key_Tab) goToWindow(selKey);
        else return;
        event.accepted = true;
    }

    // ---------------------------------------------------------------- corners and footer
    Row {
        z: 60
        opacity: view.reveal
        x: Theme.gravityEdge * view.gs
        y: Theme.gravityEdge * view.gs
        spacing: Theme.spacingMd * view.gs
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.gravityDot * view.gs
            height: width
            radius: width / 2
            color: Theme.cyan
        }
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: view.searching ? "GRAVEDAD · BUSCANDO" : "GRAVEDAD"
            mono: true
            size: Theme.sizeBody * Math.max(1, view.gs)
            weight: Theme.weightSemiBold
            color: Theme.textSoft
            font.letterSpacing: 3 * view.gs
        }
    }
    UiText {
        z: 60
        opacity: view.reveal
        anchors { right: parent.right; rightMargin: Theme.gravityEdge * view.gs }
        y: Theme.gravityEdge * view.gs
        text: `${Clock.dateFormatted} · ${Clock.time}`
        mono: true
        size: Theme.sizeBody * Math.max(1, view.gs)
        color: Theme.textSoft
    }
    Column {
        z: 60
        visible: !view.searching
        opacity: view.reveal
        x: Theme.gravityEdge * view.gs
        anchors { bottom: parent.bottom; bottomMargin: Theme.gravityLegendBottom * view.gs }
        spacing: Theme.spacingSm * view.gs
        Row {
            spacing: Theme.spacingSm * view.gs
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Theme.gravityDot * view.gs; height: width; radius: width / 2; color: Theme.cyan }
            UiText { text: "Luna = ventana abierta"; size: Theme.sizeBody * Math.max(1, view.gs); color: Theme.textSoft }
        }
        Row {
            spacing: Theme.spacingSm * view.gs
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.spacingMd * view.gs; height: width; radius: Theme.spacingXs * view.gs
                color: Theme.transparent; border.width: 1; border.color: Theme.textDim
            }
            UiText { text: "Tamaño = cuánto la usas"; size: Theme.sizeBody * Math.max(1, view.gs); color: Theme.textSoft }
        }
    }
    KeyHints {
        z: 60
        opacity: view.reveal
        factor: Math.max(1, view.gs)
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.gravityHintsBottom * view.gs }
        hints: [["← →", "rotar"], ["↑ ↓", "anillo"], ["ENTER", "abrir"], ["TAB", "ir a ventana"], ["ESC", "cerrar"]]
    }
}
