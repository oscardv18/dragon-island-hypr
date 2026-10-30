// One app of the dock constellation (DockWindow.qml): a round glass node on the thread with its moons (windows), the
// planet halo when focused, the synapses of a working herdr agent, the amber halo of a waiting one, the unread badge,
// the label and the mouse (click cycles the windows, middle = new window, right = menu, hold = thumbnails, drag a
// pinned app to reorder). Everything is placed in the dock frame's coordinates (bottom edge); the frame turns for
// left / right and the icon, badge and label turn back (dock.back).
import Quickshell
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

Item {
    id: node
    required property var dock
    required property var item
    required property int k          // index on its side (0 = next to the core)
    required property int side       // -1 pinned (left), +1 open (right)
    readonly property int off: side < 0 ? dock.leftOff : dock.rightOff
    readonly property real rel: k - off                       // 0 .. cap-1 when on screen
    readonly property real fade: Math.max(0, Math.min(1, 1 - Math.max(-rel, rel - (dock.capOf(side) - 1)) / 0.8))
    property real slotPos: side * (rel + 1)
    Behavior on slotPos { enabled: Theme.animationsEnabled; NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
    property real dragOffset: 0
    readonly property real nx: dock.c + slotPos * dock.pitch + dragOffset
    readonly property real ny: dock.curveY(nx) + (1 - dock.shownT) * 60
    readonly property bool hovered: dock.overFrame && Math.abs(dock.hx - nx) < dock.pitch / 2 && dock.shownT > 0.5
    readonly property bool busy: item.agent === "working"
    readonly property color tint: Dock.tints[item.icon] ?? Theme.lavender
    property real size: (item.focused ? Theme.dockNodeFocus : Theme.dockNode) + (hovered ? Theme.dockNodeGrow : 0)
    Behavior on size { NumberAnimation { duration: Theme.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmergente } }
    readonly property bool iconOnly: Theme.dockNodeStyle === "icon"

    anchors.fill: parent
    opacity: dock.shownT * fade
    visible: opacity > 0.01

    // the colour of the app, once per icon (only icon FILES: ColorQuantizer cannot read image://icon/ URLs → lavender)
    Loader {
        active: Dock.tints[node.item.icon] === undefined && /^(file:|\/)/.test(node.item.icon)
        sourceComponent: ColorQuantizer {
            source: node.item.icon
            depth: 2
            rescaleSize: 32
            onColorsChanged: {
                let best = null, score = -1;
                for (const c of colors) {
                    const s = c.hsvSaturation * (0.35 + c.hsvValue);
                    if (s > score) { score = s; best = c; }
                }
                if (best) Dock.setTint(node.item.icon, best);
            }
        }
    }

    // agent waiting for an answer: an amber halo that pulses (1.4 s)
    Rectangle {
        visible: node.item.agent === "blocked"
        width: Theme.dockHalo
        height: width
        radius: width / 2
        x: node.nx - width / 2
        y: node.ny - height / 2
        color: Theme.alpha(Theme.warn, 0.10)
        border.width: 2
        border.color: Theme.alpha(Theme.warn, 0.75)
        opacity: Theme.animationsEnabled ? 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(dock.liveNow / 1400 * Math.PI * 2)) : 1
        scale: Theme.animationsEnabled ? 0.94 + 0.08 * (0.5 + 0.5 * Math.sin(dock.liveNow / 1400 * Math.PI * 2)) : 1
    }

    // synapses: two cyan particles travelling the thread from the core to this app, 0.9 s apart
    Repeater {
        model: node.busy && Theme.animationsEnabled ? 2 : 0
        delegate: Item {
            required property int index
            readonly property real p: ((dock.liveNow + index * Theme.dockSynapseLife / 2) % Theme.dockSynapseLife) / Theme.dockSynapseLife
            readonly property real sx: dock.c + (node.nx - dock.c) * p
            width: Theme.dockSynapse * 3
            height: width
            x: sx - width / 2
            y: dock.threadY(sx) - height / 2
            opacity: Math.sin(p * Math.PI)
            Rectangle { anchors.centerIn: parent; width: parent.width; height: width; radius: width / 2; color: Theme.alpha(Theme.cyan, 0.22) }
            Rectangle { anchors.centerIn: parent; width: Theme.dockSynapse; height: width; radius: width / 2; color: Theme.cyan }
        }
    }

    // moons: the orbit (node + 18) and up to 3 windows going round
    Rectangle {
        visible: node.item.count > 0
        width: node.size + Theme.dockMoonOrbit
        height: width
        radius: width / 2
        x: node.nx - width / 2
        y: node.ny - height / 2
        color: Theme.transparent
        border.width: 1
        border.color: node.hovered || node.item.focused ? Theme.dockOrbitHi : Theme.dockOrbit
        Behavior on border.color { ColorAnimation { duration: Theme.durStd } }
    }
    Repeater {
        model: node.item.moons
        delegate: Item {
            id: moon
            required property var modelData
            required property int index
            readonly property real r: (node.size + Theme.dockMoonOrbit) / 2
            readonly property real period: node.busy ? Theme.dockMoonPeriodBusy : Theme.dockMoonPeriod
            readonly property real ang: -Math.PI / 2 + index * Math.PI * 2 / node.item.moons.length + (Theme.animationsEnabled ? dock.liveNow / period * Math.PI * 2 : 0)
            readonly property color col: modelData.minimized ? Theme.muted : (modelData.active ? Theme.lavender : (node.busy ? Theme.cyan : Theme.text))
            width: Theme.dockMoon * 2.4
            height: width
            x: node.nx + Math.cos(ang) * r - width / 2
            y: node.ny + Math.sin(ang) * r - height / 2
            Rectangle {   // glow of the focused window's moon
                visible: moon.modelData.active
                anchors.fill: parent
                radius: width / 2
                color: Theme.alpha(Theme.lavender, 0.3)
            }
            Rectangle { anchors.centerIn: parent; width: Theme.dockMoon; height: width; radius: width / 2; color: moon.col }
        }
    }

    // the planet halo of the focused app
    RectangularShadow {
        visible: node.item.focused
        width: node.size
        height: node.size
        x: node.nx - width / 2
        y: node.ny - height / 2
        radius: width / 2
        blur: 26
        color: Theme.alpha(Theme.lavender, 0.45)
    }

    // ---- the glass node ----
    Item {
        id: body
        width: node.size
        height: node.size
        x: node.nx - width / 2
        y: node.ny - height / 2
        opacity: node.item.minimizedOnly ? 0.4 : 1

        RectangularShadow {
            visible: !node.iconOnly
            anchors.fill: parent
            anchors.topMargin: 3
            radius: width / 2
            blur: 12
            color: Theme.alpha(Theme.islandInk, 0.6)
        }
        Shape {
            visible: !node.iconOnly
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1
                strokeColor: Theme.dockNodeEdge
                fillGradient: RadialGradient {
                    centerX: body.width * 0.3; centerY: body.height * 0.25; centerRadius: body.width * 0.95
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0.0; color: Theme.alpha(node.tint, 0.30) }
                    GradientStop { position: 0.45; color: Theme.alpha(node.tint, 0.08) }
                    GradientStop { position: 1.0; color: Theme.dockNodeBase }
                }
                PathAngleArc { centerX: body.width / 2; centerY: body.height / 2; radiusX: body.width / 2 - 0.5; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
        }
        Rectangle {   // top highlight, white 18 %
            visible: !node.iconOnly
            anchors.fill: parent
            anchors.margins: 1
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.dockNodeShine }
                GradientStop { position: 0.45; color: Theme.transparent }
            }
        }
        Rectangle {   // planet ring of the focused app
            visible: node.item.focused
            anchors.fill: parent
            anchors.margins: node.iconOnly ? -3 : 0
            radius: width / 2
            color: Theme.transparent
            border.width: 2
            border.color: Theme.alpha(Theme.lavender, 0.7)
        }

        Image {
            id: icon
            anchors.centerIn: parent
            rotation: dock.back
            readonly property real s: node.iconOnly ? node.size : Math.round(node.size * Theme.dockIconRatio)
            width: s
            height: s
            source: node.item.icon
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            mipmap: true
            smooth: true
            layer.enabled: node.item.minimizedOnly
            layer.effect: MultiEffect { saturation: -0.7 }
        }
    }

    // unread notifications of the app
    Rectangle {
        visible: node.item.badge > 0
        rotation: dock.back
        width: Math.max(17, badgeText.implicitWidth + 9)
        height: 17
        radius: height / 2
        x: node.nx + node.size * 0.36 - width / 2
        y: node.ny - node.size * 0.36 - height / 2
        color: Theme.badge
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.25)
        UiText { id: badgeText; anchors.centerIn: parent; text: `${Math.min(99, node.item.badge)}`; size: Theme.sizeCaption; weight: Theme.weightBold; color: Theme.text }
    }

    // label: glass pill above the node, name + state
    Rectangle {
        id: label
        readonly property string state: {
            const parts = [];
            const n = node.item.count;
            parts.push(n === 0 ? "sin abrir" : (n === 1 ? "1 ventana" : `${n} ventanas`));
            if (node.item.agent === "working") parts.push("agente trabajando");
            else if (node.item.agent === "blocked") parts.push("esperando tu respuesta");
            if (node.item.badge > 0) parts.push(`${node.item.badge} sin leer`);
            if (node.item.minimizedOnly) parts.push("minimizada");
            return parts.join(" · ");
        }
        rotation: dock.back
        opacity: node.hovered && !dock.menuOpen && !dock.thumbsOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.durStd } }
        width: Math.max(nameText.implicitWidth, stateText.implicitWidth) + 24
        height: labelCol.implicitHeight + 12
        radius: 12
        color: Theme.alpha(Theme.islandInk, 0.88)
        border.width: 1
        border.color: Theme.glassBorder
        readonly property real gap: (node.size + Theme.dockMoonOrbit) / 2 + 10
        x: node.nx - width / 2 + (dock.horiz ? 0 : (dock.pos === "left" ? 0 : 0))
        y: node.ny - gap - (dock.horiz ? height : (height + width) / 2)
        Column {
            id: labelCol
            anchors.centerIn: parent
            spacing: 1
            UiText { id: nameText; anchors.horizontalCenter: parent.horizontalCenter; text: node.item.name; size: Theme.sizeBody; weight: Theme.weightSemiBold }
            UiText { id: stateText; anchors.horizontalCenter: parent.horizontalCenter; text: label.state; size: Theme.sizeCaption; color: Theme.textDim }
        }
    }

    // click = activate / cycle windows · middle = new window · right = menu · hold = thumbnails · drag (pinned) = reorder
    MouseArea {
        id: mouse
        width: node.size + 8
        height: width
        x: node.nx - width / 2
        y: node.ny - height / 2
        enabled: node.fade > 0.4 && dock.shownT > 0.5
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        pressAndHoldInterval: 450
        property real pressAlong: 0
        property bool dragging: false
        property bool held: false
        onPressed: m => { pressAlong = m.x; dragging = false; held = false; }
        onPositionChanged: m => {
            if (!(pressedButtons & Qt.LeftButton) || !node.item.pinned || held) return;
            const d = m.x - pressAlong;
            if (Math.abs(d) > 8) dragging = true;
            if (dragging) node.dragOffset = d;
        }
        onPressAndHold: m => { if (!dragging && node.item.count > 0) { held = true; dock.openThumbs(node.item, body); } }
        onReleased: m => {
            if (dragging) {
                // pinned apps grow to the LEFT of the core: moving left = a higher index
                Dock.reorder(node.k, node.k - Math.round(node.dragOffset / dock.pitch));
                node.dragOffset = 0;
                dragging = false;
            }
        }
        onClicked: m => { if (!dragging && !held) dock.itemClicked(node.item, m, body); }
    }

}
