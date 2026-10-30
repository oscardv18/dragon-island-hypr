// =============================================================================
// dragon-island — DockWindow.qml (namespace "dragon-dock") · docs/design/27-dock-constelacion.png
// The dock is a CONSTELLATION: apps are round glass nodes on a thread of light, the neural core sits in the middle of
// the screen edge (click = launcher, wheel = workspaces), pinned apps grow to its left (top), open ones to its right
// (bottom). The windows of an app are moons orbiting it, a herdr agent working in an app sends synapses along the
// thread from the core, an agent waiting for an answer makes an amber halo pulse.
//   thread  a continuous curve: a slight inverted smile (ends Theme.dockArc closer to the edge) plus a gaussian lift
//           under the pointer, so it "tightens" towards the cursor and always passes through the node centres;
//           sampled into a Canvas that only repaints when the geometry changes
//   hidden  (tiled windows, Dock.workspaceFree false) the nodes sink and fade; only the thread stays, Theme.dockHiddenLine
//           from the edge, with a dot per open app (cyan with an agent) breathing slowly
//   motion  ONE shared Timer (Theme.dockFps) moves moons, synapses and the breathing; nothing runs every vsync, and
//           nothing runs while hidden-and-idle or with motionScale 0
// One window as long as the edge, of constant thickness (Theme.dockWindow); the frame inside is drawn for the bottom
// edge and turned for left / right (icons and labels turn back). The input mask is made of FIXED items in window
// coordinates (a Region does not follow a moving / rotated ancestor, HANDOFF §7y): the 3 px hot strip always (it is
// part of this same window, §7x), the node band while shown, the whole thickness while hovered (lift + label).
// Kept from the tab dock: pinned + open apps, cycling windows, minimised windows (special:minimized), the app menu and
// the dock menu (position, always visible), dragging pinned apps to reorder, the wheel to scroll, IPC `dock`.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""
    readonly property string pos: Dock.position
    readonly property bool horiz: pos === "bottom"
    readonly property real len: (horiz ? modelData?.width : modelData?.height) ?? 1366
    readonly property real thick: Theme.dockWindow

    anchors {
        bottom: true
        top: !horiz
        left: pos !== "right"
        right: pos !== "left"
    }
    implicitWidth: horiz ? len : thick
    implicitHeight: horiz ? thick : len
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dragon-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ------------------------------------------------------------ model and layout (frame coordinates: bottom edge)
    readonly property var pinned: Dock.pinnedItems
    readonly property var opened: Dock.openItems
    // Theme.dockCapacity nodes in all: half per side, but a side that needs fewer lends the rest to the other
    readonly property int half: Math.floor(Theme.dockCapacity / 2)
    // and never more than fit between the core and the end of the edge (left / right: under the top bar)
    readonly property int fitSide: Math.max(1, Math.floor((len / 2 - Theme.dockCore / 2 - Theme.dockNode / 2 - (horiz ? 16 : Theme.barZone + 16)) / Theme.dockPitch) + 1)
    readonly property int leftCap: Math.min(pinned.length, fitSide, Theme.dockCapacity - Math.min(opened.length, half, fitSide))
    readonly property int rightCap: Math.min(opened.length, fitSide, Theme.dockCapacity - leftCap)
    function capOf(side: int): int { return side < 0 ? leftCap : rightCap; }
    property int leftOff: 0
    property int rightOff: 0
    onLeftCapChanged: leftOff = Math.min(leftOff, Math.max(0, pinned.length - leftCap))
    onRightCapChanged: rightOff = Math.min(rightOff, Math.max(0, opened.length - rightCap))

    readonly property real c: len / 2
    readonly property real pitch: Theme.dockPitch
    readonly property int leftShown: leftCap
    readonly property int rightShown: rightCap
    // the thread: from Theme.dockOverhang beyond the outermost node (or the core) on each side
    // (left / right: never under the top bar; along "left" = up for left, down for right)
    readonly property real edgeA: horiz ? 0 : (pos === "left" ? Theme.barZone : 0)
    readonly property real edgeB: horiz ? len : (pos === "right" ? len - Theme.barZone : len)
    readonly property real x0: Math.max(edgeA, c - (leftShown > 0 ? leftShown * pitch : Theme.dockCore / 2) - Theme.dockOverhang)
    readonly property real x1: Math.min(edgeB, c + (rightShown > 0 ? rightShown * pitch : Theme.dockCore / 2) + Theme.dockOverhang)
    readonly property real spanHalf: Math.max(c - x0, x1 - c)

    // shown 0 → 1 (Emergente in, Salida out)
    property real shownT: Dock.wanted ? 1 : 0
    Behavior on shownT {
        enabled: Theme.animationsEnabled
        NumberAnimation {
            duration: Dock.wanted ? Theme.durEmerge : Theme.durOut * 2
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Dock.wanted ? Theme.curveEmergente : Theme.curveSalida
        }
    }

    // pointer along the dock and how much the thread tightens towards it
    property real hx: c
    property real hoverK: frameHover.hovered && Dock.wanted ? 1 : 0
    Behavior on hoverK { NumberAnimation { duration: Theme.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmergente } }
    Behavior on hx { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }

    function curveY(x: real): real {
        const u = Math.max(-1, Math.min(1, (x - c) / Math.max(1, spanHalf)));
        const d = (x - hx) / (Theme.dockSigma * pitch);
        return thick - Theme.dockCenter + Theme.dockArc * u * u - Theme.dockLift * hoverK * Math.exp(-d * d / 2);
    }
    function threadY(x: real): real { return (thick - Theme.dockHiddenLine) * (1 - shownT) + curveY(x) * shownT; }

    // ------------------------------------------------------------ the shared tick (moons, synapses, breathing)
    property real now: 0
    readonly property bool anyAgent: pinned.concat(opened).some(i => i.agent.length > 0)
    readonly property bool anyMoons: pinned.concat(opened).some(i => i.count > 0)
    Timer {
        // hidden, only the thread's dots breathe: a slow tick is enough
        interval: Math.round(1000 / (win.shownT > 0.01 ? Theme.dockFps : Theme.dockFpsHidden))
        repeat: true
        running: Theme.animationsEnabled && ((win.shownT > 0.01 && (win.anyMoons || win.anyAgent)) || (win.shownT < 0.99 && win.anyMoons))
        onTriggered: win.now += interval
    }
    // the nodes (moons, synapses, halo) follow the clock only while they are shown: hidden, `liveNow` stays put
    readonly property real liveNow: shownT > 0.01 ? now : 0
    readonly property real breath: 0.725 + 0.275 * Math.sin(now / Theme.dockBreath * Math.PI * 2)

    // ------------------------------------------------------------ input mask (fixed items, window coordinates)
    mask: Region {
        Region { item: strip }
        Region { item: Dock.wanted ? (frameHover.hovered ? hitArea : bandArea) : null }
    }
    // a rect given in frame coordinates (along a0..a1, distance from the edge d0..d1) → window coordinates
    function rx(a0: real, a1: real, d0: real, d1: real): real { return pos === "bottom" ? a0 : (pos === "left" ? d0 : thick - d1); }
    function ry(a0: real, a1: real, d0: real, d1: real): real { return pos === "bottom" ? thick - d1 : (pos === "left" ? a0 : len - a1); }
    function rw(a0: real, a1: real, d0: real, d1: real): real { return horiz ? a1 - a0 : d1 - d0; }
    function rh(a0: real, a1: real, d0: real, d1: real): real { return horiz ? d1 - d0 : a1 - a0; }
    readonly property real bandDepth: Theme.dockCenter + Theme.dockNodeFocus / 2 + Theme.dockMoonOrbit
    Item { id: strip;    x: win.rx(0, win.len, 0, Theme.dockEdge); y: win.ry(0, win.len, 0, Theme.dockEdge); width: win.rw(0, win.len, 0, Theme.dockEdge); height: win.rh(0, win.len, 0, Theme.dockEdge) }
    Item { id: bandArea; x: win.rx(win.x0, win.x1, 0, win.bandDepth); y: win.ry(win.x0, win.x1, 0, win.bandDepth); width: win.rw(win.x0, win.x1, 0, win.bandDepth); height: win.rh(win.x0, win.x1, 0, win.bandDepth) }
    Item { id: hitArea;  x: win.rx(win.x0, win.x1, 0, win.thick); y: win.ry(win.x0, win.x1, 0, win.thick); width: win.rw(win.x0, win.x1, 0, win.thick); height: win.rh(win.x0, win.x1, 0, win.thick) }
    HoverHandler { id: stripHover; target: strip }

    readonly property bool overFrame: frameHover.hovered
    readonly property real back: -frame.rotation          // DockNode: icons and labels turn back to stay upright
    readonly property bool pointerOn: stripHover.hovered || frameHover.hovered
    onPointerOnChanged: Dock.hover(pointerOn)

    // ------------------------------------------------------------ the frame (drawn for the bottom edge)
    Item {
        id: frame
        width: win.len
        height: win.thick
        anchors.centerIn: parent
        rotation: win.pos === "bottom" ? 0 : (win.pos === "left" ? 90 : -90)
        readonly property real back: -rotation      // icons and labels turn back to stay upright

        HoverHandler {
            id: frameHover
            onPointChanged: if (hovered) win.hx = point.position.x
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                const step = e.angleDelta.y > 0 ? -1 : 1;
                if (win.hx < win.c - win.pitch / 2) win.leftOff = Math.max(0, Math.min(Math.max(0, win.pinned.length - win.leftCap), win.leftOff + step));
                else if (win.hx > win.c + win.pitch / 2) win.rightOff = Math.max(0, Math.min(Math.max(0, win.opened.length - win.rightCap), win.rightOff + step));
                else Hypr.focusRelative(step);
            }
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: win.openMenu(null, coreItem)
        }

        // ---- the thread: glow (7 px, 18 %) under a 1.6 px line, lavender → pink lavender → cyan, fading at the ends
        Canvas {
            id: thread
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            readonly property var deps: [win.hx, win.hoverK, win.shownT, win.x0, win.x1, win.len, win.thick]
            onDepsChanged: requestPaint()
            function rgba(col, a) { return `rgba(${Math.round(col.r * 255)},${Math.round(col.g * 255)},${Math.round(col.b * 255)},${a})`; }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                const a = win.x0, b = win.x1;
                if (b - a < 2) return;
                const g = ctx.createLinearGradient(a, 0, b, 0);
                g.addColorStop(0, rgba(Theme.lavender, 0));
                g.addColorStop(0.16, rgba(Theme.lavender, 1));
                g.addColorStop(0.5, rgba(Theme.threadPink, 1));
                g.addColorStop(0.84, rgba(Theme.cyan, 1));
                g.addColorStop(1, rgba(Theme.cyan, 0));
                ctx.beginPath();
                for (let x = a; x <= b; x += 4) {
                    const y = win.threadY(x);
                    if (x === a) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.strokeStyle = g;
                ctx.lineCap = "round";
                ctx.globalAlpha = 0.18;
                ctx.lineWidth = Theme.dockThreadGlow;
                ctx.stroke();
                ctx.globalAlpha = 0.55 + 0.45 * win.shownT;
                ctx.lineWidth = Theme.dockThread;
                ctx.stroke();
            }
        }

        // ---- hidden: a dot per open app on the thread, breathing ----
        Repeater {
            model: win.pinned.map((it, k) => ({ it: it, slot: -(k + 1 - win.leftOff), k: k, side: -1 }))
                      .concat(win.opened.map((it, k) => ({ it: it, slot: k + 1 - win.rightOff, k: k, side: 1 })))
                      .filter(n => n.it.count > 0 && (n.side < 0 ? n.k - win.leftOff : n.k - win.rightOff) >= 0
                                   && (n.side < 0 ? n.k - win.leftOff : n.k - win.rightOff) < win.capOf(n.side))
            delegate: Rectangle {
                required property var modelData
                readonly property real nx: win.c + modelData.slot * win.pitch
                width: Theme.dockHiddenDot * 2
                height: width
                radius: width / 2
                x: nx - width / 2
                y: win.threadY(nx) - height / 2
                color: modelData.it.agent.length > 0 ? Theme.cyan : Theme.lavenderInk
                opacity: (1 - win.shownT) * (Theme.animationsEnabled ? win.breath : 1)
                visible: opacity > 0.01
            }
        }

        // ---- the core ----
        Item {
            id: coreItem
            readonly property real cy: win.curveY(win.c) + (1 - win.shownT) * 60
            width: Theme.dockCore
            height: Theme.dockCore
            x: win.c - width / 2
            y: cy - height / 2
            opacity: win.shownT
            visible: opacity > 0.01

            RectangularShadow {
                anchors.fill: parent
                radius: width / 2
                blur: 22
                color: Theme.alpha(Theme.violetBase, 0.35)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.dockNodeBase
                border.width: 1
                border.color: Theme.dockNodeEdge
            }
            NeuralCore {
                identity: Theme.coreIdentity
                anchors.fill: parent
                anchors.margins: 2
                bare: true
                fps: 15
                pointCount: 110
                mood: (Herdr.counts?.working ?? 0) > 0 ? "thinking" : (coreMouse.containsMouse ? "listening" : "calm")
                reducedMotion: !Theme.animationsEnabled
                running: win.shownT > 0.5 && Theme.animationsEnabled
            }
            MouseArea {
                id: coreMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => { if (m.button === Qt.RightButton) win.openMenu(null, coreItem); else ShellState.toggle("launcher", win.screenName); }
            }
        }

        // ---- the app nodes (DockNode.qml) ----
        Repeater {
            model: win.pinned
            delegate: DockNode {
                required property var modelData
                required property int index
                dock: win
                item: modelData
                k: index
                side: -1
            }
        }
        Repeater {
            model: win.opened
            delegate: DockNode {
                required property var modelData
                required property int index
                dock: win
                item: modelData
                k: index
                side: 1
            }
        }
    }

    // ------------------------------------------------------------ app menu, dock menu and window thumbnails
    property var menuItem: null         // app of the open menu; null + menuOpen = the dock settings
    property bool menuOpen: false
    property Item menuAnchor: coreItem
    property var thumbsItem: null
    property bool thumbsOpen: false
    property Item thumbsAnchor: coreItem

    function openMenu(item, anchorItem): void {
        win.thumbsOpen = false;
        win.menuItem = item;
        win.menuAnchor = anchorItem;
        win.menuOpen = true;
    }
    function openThumbs(item, anchorItem): void {
        win.menuOpen = false;
        win.thumbsItem = item;
        win.thumbsAnchor = anchorItem;
        win.thumbsOpen = true;
    }
    function itemClicked(item, m, anchorItem): void {
        if (m.button === Qt.RightButton) win.openMenu(item, anchorItem);
        else if (m.button === Qt.MiddleButton) Dock.newInstance(item);
        else { win.menuOpen = false; win.thumbsOpen = false; Dock.activate(item); }
    }

    Connections {
        target: Dock
        function onWantedChanged() { if (!Dock.wanted) { win.menuOpen = false; win.thumbsOpen = false; } }
    }

    // the popups open away from the edge
    readonly property var popEdge: pos === "bottom" ? Edges.Top : (pos === "left" ? Edges.Right : Edges.Left)

    PopupWindow {
        id: thumbs
        visible: win.thumbsOpen && win.thumbsItem !== null
        anchor.item: win.thumbsAnchor
        anchor.edges: win.popEdge
        anchor.gravity: win.popEdge
        anchor.margins.top: Theme.dockMoonOrbit + 14
        anchor.margins.left: Theme.dockMoonOrbit + 14
        anchor.margins.right: Theme.dockMoonOrbit + 14
        implicitWidth: thumbRow.implicitWidth + Theme.spacingMd * 2
        implicitHeight: thumbRow.implicitHeight + Theme.spacingMd * 2
        color: Theme.transparent
        Rectangle {
            anchors.fill: parent
            radius: Theme.cardRadius
            color: Theme.alpha(Theme.islandInk, 0.92)
            border.width: 1
            border.color: Theme.glassBorder
            HoverHandler { onHoveredChanged: { Dock.hover(hovered); if (!hovered) closeThumbs.restart(); else closeThumbs.stop(); } }
            Timer { id: closeThumbs; interval: 700; onTriggered: win.thumbsOpen = false }
            Row {
                id: thumbRow
                anchors.centerIn: parent
                spacing: Theme.spacingSm
                Repeater {
                    model: win.thumbsOpen ? (win.thumbsItem?.windows ?? []) : []
                    delegate: Column {
                        required property var modelData
                        spacing: 4
                        Rectangle {
                            width: Theme.previewThumbWidth
                            height: width * 0.6
                            radius: 10
                            color: Theme.dockNodeBase
                            border.width: 1
                            border.color: shotMouse.containsMouse ? Theme.alpha(Theme.lavender, 0.7) : Theme.glassBorder
                            clip: true
                            ScreencopyView {
                                anchors.fill: parent
                                anchors.margins: 1
                                captureSource: win.thumbsOpen ? modelData.wayland : null
                                live: false
                                constraintSize: Qt.size(width, height)
                            }
                            MouseArea {
                                id: shotMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Hypr.focusWindow(modelData.address); win.thumbsOpen = false; }
                            }
                        }
                        UiText { width: Theme.previewThumbWidth; text: modelData.title; size: Theme.sizeCaption; color: Theme.textDim }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: menu
        visible: win.menuOpen
        anchor.item: win.menuAnchor
        anchor.edges: win.popEdge
        anchor.gravity: win.popEdge
        anchor.margins.top: Theme.dockMoonOrbit + 10
        anchor.margins.left: Theme.dockMoonOrbit + 10
        anchor.margins.right: Theme.dockMoonOrbit + 10
        implicitWidth: 210
        implicitHeight: menuCol.implicitHeight + Theme.spacingSm * 2
        color: Theme.transparent

        Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius + 4
            color: Theme.alpha(Theme.islandInk, 0.92)
            border.width: 1
            border.color: Theme.glassBorder
            HoverHandler { onHoveredChanged: Dock.hover(hovered) }

            Column {
                id: menuCol
                anchors.fill: parent
                anchors.margins: Theme.spacingSm
                spacing: 2

                component MenuRow: Rectangle {
                    id: mr
                    property string text: ""
                    property bool checked: false
                    signal triggered()
                    width: parent.width
                    height: 28
                    radius: 8
                    color: mr.checked ? Theme.accentTint : (mrMouse.containsMouse ? Theme.hoverOverlay : Theme.transparent)
                    UiText { x: 10; anchors.verticalCenter: parent.verticalCenter; text: mr.text; size: Theme.sizeBody; color: mr.checked ? Theme.lavenderInk : Theme.text }
                    MouseArea { id: mrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { mr.triggered(); win.menuOpen = false; } }
                }

                // ---- an app ----
                MenuRow { visible: win.menuItem !== null; text: win.menuItem?.pinned ? "Quitar del dock" : "Fijar en el dock"; onTriggered: Dock.togglePin(win.menuItem) }
                MenuRow { visible: (win.menuItem?.entry ?? null) !== null; text: "Nueva ventana"; onTriggered: Dock.newInstance(win.menuItem) }
                MenuRow { visible: (win.menuItem?.count ?? 0) > 1; text: "Ver ventanas"; onTriggered: win.openThumbs(win.menuItem, win.menuAnchor) }
                MenuRow { visible: (win.menuItem?.count ?? 0) > 0; text: `Cerrar todas (${win.menuItem?.count ?? 0})`; onTriggered: Dock.closeAll(win.menuItem) }
                Row {
                    visible: (win.menuItem?.count ?? 0) > 0
                    height: 28
                    spacing: 4
                    UiText { anchors.verticalCenter: parent.verticalCenter; text: "Mover a"; size: Theme.sizeCaption + 1; color: Theme.textDim; leftPadding: 10 }
                    Repeater {
                        model: Hypr.workspaceCount
                        delegate: Rectangle {
                            required property int index
                            width: 24; height: 24; radius: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: wsMouse.containsMouse ? Theme.accentTint : Theme.neutralFill
                            border.width: wsMouse.containsMouse ? 1 : 0
                            border.color: Theme.accentEdge
                            UiText { anchors.centerIn: parent; text: `${index + 1}`; mono: true; size: Theme.sizeCaption; color: wsMouse.containsMouse ? Theme.lavenderInk : Theme.textSoft }
                            MouseArea { id: wsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Dock.moveAllTo(win.menuItem, index + 1); win.menuOpen = false; } }
                        }
                    }
                }

                // ---- the dock ----
                UiText { visible: win.menuItem === null; text: "Dock"; caption: true; leftPadding: 10; topPadding: 4 }
                MenuRow { visible: win.menuItem === null; text: "Abajo"; checked: Dock.position === "bottom"; onTriggered: Dock.setPosition("bottom") }
                MenuRow { visible: win.menuItem === null; text: "Izquierda"; checked: Dock.position === "left"; onTriggered: Dock.setPosition("left") }
                MenuRow { visible: win.menuItem === null; text: "Derecha"; checked: Dock.position === "right"; onTriggered: Dock.setPosition("right") }
                MenuRow { visible: win.menuItem === null; text: "Siempre visible"; checked: Dock.alwaysVisible; onTriggered: Dock.togglePinned() }
            }
        }
    }
}
