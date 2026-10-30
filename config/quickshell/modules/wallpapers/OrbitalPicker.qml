// =============================================================================
// dragon-island — OrbitalPicker.qml (SUPER + W, or a right click on the empty desktop) · docs/design/16-orbital.png
// The wallpapers as thumbnails on a ring around the click point (the screen centre from a shortcut).
//   - the ring (an ellipse) is pushed inwards so it never leaves the screen (nor covers the bar or the help pill)
//   - thumbnails come out of the centre with the `orbita` curve, Theme.durOrbitStagger apart
//   - centre: a 112 px dashed disc with the hovered wallpaper's name and ACTUAL / CLIC PARA APLICAR (ELIGE UNO at rest)
//   - at most Theme.orbitalMax thumbnails; with more, the wheel turns the ring (the slot that leaves and the one that
//     comes in cross-fade at the same place)
//   - choosing one: the thumbnail flies to the screen centre, then grows until it covers the screen; while it grows
//     Wallpaper.apply() starts awww's grow reveal from the screen centre; then it fades out and the picker closes
//   - help pill at the bottom only at rest; the grid button opens the classic picker (WallpaperPanel)
//   - keyboard: ← → pick a thumbnail (the ring turns to keep it in view), Enter applies it
//   - Esc, a click outside the ring or applying a wallpaper close it
// Only already made thumbnails (Wallpaper.thumbUrl: a still frame for GIF and video) are shown, never the files.
// =============================================================================
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    property var screen: null
    readonly property bool flying: flight.running

    readonly property var list: Wallpaper.items
    readonly property int total: list.length
    readonly property int count: Math.min(total, Theme.orbitalMax)
    readonly property bool canSpin: total > Theme.orbitalMax

    property var mouseItem: null      // under the pointer
    property int keyIndex: -1         // picked with ← → (index in `list`)
    readonly property var hoveredItem: mouseItem ?? (keyIndex >= 0 ? list[keyIndex] ?? null : null)
    property var chosen: null

    // ---- the ring's centre: the click, pushed inwards ----
    readonly property real _reachX: Theme.orbitalRadiusX + Theme.orbitalThumbW * Theme.orbitalHoverScale / 2 + Theme.orbitalEdge
    readonly property real _reachY: Theme.orbitalRadiusY + Theme.orbitalThumbH * Theme.orbitalHoverScale / 2 + Theme.orbitalStrip + Theme.orbitalEdge
    // a click outside this ellipse (the ring plus half a thumbnail) closes the picker
    function _outside(x: real, y: real): bool {
        const ax = Theme.orbitalRadiusX + Theme.orbitalThumbW / 2, ay = Theme.orbitalRadiusY + Theme.orbitalThumbH / 2;
        return Math.pow((x - root.cx) / ax, 2) + Math.pow((y - root.cy) / ay, 2) > 1;
    }
    function _clamp(v: real, lo: real, hi: real): real { return hi < lo ? (lo + hi) / 2 : Math.max(lo, Math.min(hi, v)); }
    readonly property real cx: _clamp(Wallpaper.orbitalX < 0 ? width / 2 : Wallpaper.orbitalX, _reachX, width - _reachX)
    readonly property real cy: _clamp(Wallpaper.orbitalY < 0 ? height / 2 : Wallpaper.orbitalY,
                                      _reachY + Theme.barZone, height - _reachY - help.height - Theme.spacingLg * 2)

    // ---- turning the ring ----
    property int target: 0
    property bool _jump: false
    property real pos: target
    Behavior on pos {
        enabled: !root._jump
        NumberAnimation { duration: Theme.durOrbitSpin; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar }
    }
    readonly property int _base: Math.floor(pos)
    readonly property real _frac: pos - _base
    property real _wheel: 0

    function prettyName(item): string {
        if (!item) return "";
        return item.name.replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ");
    }

    // ← → : step the keyboard pick; the ring turns when it would leave the visible slots
    function step(d: int): void {
        if (root.total === 0 || root.flying) return;
        root.mouseItem = null;
        const k = root.keyIndex < 0 ? ((root.target % root.total) + root.total) % root.total : root.keyIndex + d;
        root.keyIndex = ((k % root.total) + root.total) % root.total;
        if (!root.canSpin) return;
        const off = ((root.keyIndex - root.target) % root.total + root.total) % root.total;   // slot of the pick
        if (off >= root.count) root.target += d > 0 ? off - root.count + 1 : off - root.total;
    }
    function applyKey(): void {
        for (let i = 0; i < slots.count; i++) {
            const s = slots.itemAt(i);
            if (s && s.fade > 0.5 && s.itemIndex === root.keyIndex) { root.choose(s); return; }
        }
    }

    function choose(slot): void {
        const item = slot.item;
        if (!item || root.flying) return;
        if (item.path === Wallpaper.current) { ShellState.close(); return; }
        root.chosen = item;
        root.mouseItem = null;
        root.keyIndex = -1;
        const w = slot.width * slot.scale, h = slot.height * slot.scale;
        flyer.source = Wallpaper.thumbUrl(item);
        flyer.x = slot.x + slot.width / 2 - w / 2;
        flyer.y = slot.y + slot.height / 2 - h / 2;
        flyer.width = w;
        flyer.height = h;
        flyer.radius = Theme.orbitalThumbRadius;
        flyer.opacity = 1;
        flight.restart();
    }

    onShownChanged: {
        if (shown) {
            Wallpaper.refresh();
            root.mouseItem = null;
            root.keyIndex = -1;
            root.chosen = null;
            root._wheel = 0;
            // start with the current wallpaper at the top of the ring
            const at = Wallpaper.items.findIndex(i => i.path === Wallpaper.current);
            root._jump = true;
            root.target = Math.max(0, at);
            root._jump = false;
        } else {
            flight.stop();
            root.chosen = null;
        }
    }

    // clicks outside the ring close it; the wheel turns it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.shown && !root.flying
        onClicked: mouse => { if (root._outside(mouse.x, mouse.y)) ShellState.close(); }
        onWheel: wheel => {
            if (!root.canSpin) return;
            root._wheel += wheel.angleDelta.y;
            while (Math.abs(root._wheel) >= 120) {
                root.target += root._wheel < 0 ? 1 : -1;
                root._wheel += root._wheel < 0 ? 120 : -120;
            }
        }
    }

    // ---- the ring ----
    Item {
        id: ring
        anchors.fill: parent
        opacity: root.chosen ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSalida } }

        Repeater {
            id: slots
            model: root.count > 0 ? root.count + 1 : 0

            delegate: Item {
                id: slot
                required property int index
                readonly property int itemIndex: root.total > 0 ? ((root._base + index) % root.total + root.total) % root.total : 0
                readonly property var item: root.list[itemIndex] ?? null
                readonly property real angle: (index - root._frac) * 2 * Math.PI / root.count - Math.PI / 2
                readonly property real fade: index === 0 ? 1 - root._frac : (index === root.count ? root._frac : 1)
                readonly property bool hovered: root.shown && !root.flying && fade > 0.5
                                                && (hover.containsMouse || (root.mouseItem === null && itemIndex === root.keyIndex))
                readonly property bool isCurrent: item !== null && item.path === Wallpaper.current
                property real t: 0          // 0 = in the centre, 1 = on the ring
                property real lift: hovered ? 1 : 0
                Behavior on lift { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }

                width: Theme.orbitalThumbW
                height: Theme.orbitalThumbH
                x: root.cx + Math.cos(angle) * Theme.orbitalRadiusX * t - width / 2
                y: root.cy + Math.sin(angle) * Theme.orbitalRadiusY * t - height / 2
                scale: (0.35 + 0.65 * t) * (1 + (Theme.orbitalHoverScale - 1) * lift)
                opacity: t * fade * (root.chosen !== null && root.chosen === item ? 0 : 1)
                visible: opacity > 0.01
                z: hovered ? 2 : 1

                SequentialAnimation {
                    id: appear
                    PauseAnimation { duration: slot.index * Theme.durOrbitStagger }
                    NumberAnimation { target: slot; property: "t"; to: 1; duration: Theme.durOrbit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita }
                }
                NumberAnimation { id: vanish; target: slot; property: "t"; to: 0; duration: Theme.durOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSalida }
                function play(): void {
                    if (root.shown) { vanish.stop(); slot.t = 0; appear.restart(); }
                    else { appear.stop(); vanish.restart(); }
                }
                Connections { target: root; function onShownChanged() { slot.play(); } }
                Component.onCompleted: if (root.shown) play()

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.orbitalThumbRadius
                    color: Theme.surface2
                    border.width: slot.isCurrent ? 2 : 1
                    border.color: slot.isCurrent ? Theme.lavender : Theme.glassBorder

                    Image {
                        anchors.fill: parent
                        source: root.shown || slot.t > 0 ? Wallpaper.thumbUrl(slot.item) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 256
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: slot.fade > 0.5 && slot.t > 0.5
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) root.mouseItem = slot.item;
                        else if (root.mouseItem === slot.item) root.mouseItem = null;
                    }
                    onClicked: root.choose(slot)
                }
            }
        }

        // ---- the centre ----
        Item {
            id: disc
            width: Theme.orbitalCore
            height: width
            x: root.cx - width / 2
            y: root.cy - height / 2
            scale: root.shown ? 1 : 0.6
            opacity: root.shown ? 1 : 0
            Behavior on scale { NumberAnimation { duration: Theme.durEmerge; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmergente } }
            Behavior on opacity { NumberAnimation { duration: Theme.durStd } }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.orbitalDisc
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.orbitalDiscEdge
                    strokeWidth: 1.2
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [Theme.orbitalDash, Theme.orbitalDash]
                    fillColor: Theme.transparent
                    PathAngleArc {
                        centerX: Theme.orbitalCore / 2
                        centerY: Theme.orbitalCore / 2
                        radiusX: Theme.orbitalCore / 2 - 1
                        radiusY: Theme.orbitalCore / 2 - 1
                        sweepAngle: 360
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingLg * 2
                spacing: Theme.spacingXs
                UiText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    text: root.hoveredItem ? root.prettyName(root.hoveredItem) : `${root.total} fondos`
                    size: Theme.sizeBody
                    weight: Theme.weightSemiBold
                    color: root.hoveredItem ? Theme.text : Theme.textDim
                }
                UiText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    mono: true
                    size: Theme.sizeCaption - 2
                    font.letterSpacing: Theme.sizeCaption * Theme.captionTracking
                    text: !root.hoveredItem ? "ELIGE UNO" : (root.hoveredItem.path === Wallpaper.current ? "ACTUAL" : "CLIC PARA APLICAR")
                    color: root.hoveredItem && root.hoveredItem.path === Wallpaper.current ? Theme.lavender : Theme.textDim
                }
            }
        }
    }

    // ---- help pill + the classic grid ----
    Row {
        id: help
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingLg * 2
        spacing: Theme.spacingSm
        opacity: root.shown && !root.chosen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durStd } }

        Rectangle {
            height: Theme.touchTarget - 8
            width: hintRow.implicitWidth + Theme.spacingLg * 2
            radius: height / 2
            color: Theme.orbitalPill
            border.width: 1
            border.color: Theme.glassBorder
            opacity: root.hoveredItem === null ? 1 : 0     // only at rest
            Behavior on opacity { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: Theme.spacingSm
                Glyph { anchors.verticalCenter: parent.verticalCenter; icon: Icons.mouse; size: Theme.iconMd; color: Theme.textSoft }
                UiText { anchors.verticalCenter: parent.verticalCenter; text: "Clic para aplicar · Esc para cerrar"; color: Theme.textSoft }
            }
        }

        Rectangle {
            height: Theme.touchTarget - 8
            width: gridRow.implicitWidth + Theme.spacingLg * 2
            radius: height / 2
            color: gridMouse.containsMouse ? Theme.alpha(Theme.surfaceHi, 0.9) : Theme.orbitalPill
            border.width: 1
            border.color: Theme.glassBorder
            Behavior on color { ColorAnimation { duration: Theme.durHover } }
            Row {
                id: gridRow
                anchors.centerIn: parent
                spacing: Theme.spacingSm
                Glyph { anchors.verticalCenter: parent.verticalCenter; icon: Icons.apps; size: Theme.iconMd; color: Theme.textSoft }
                UiText { anchors.verticalCenter: parent.verticalCenter; text: "Cuadrícula"; color: Theme.textSoft }
            }
            MouseArea {
                id: gridMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.shown && !root.flying
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.open("wallpapers", root.screen?.name ?? "")
            }
        }
    }

    // ---- the chosen thumbnail: flies to the centre, then covers the screen ----
    ClippingRectangle {
        id: flyer
        property alias source: flyImage.source
        visible: root.flying
        z: 10
        color: Theme.surface2
        Image {
            id: flyImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
        }
    }

    SequentialAnimation {
        id: flight
        ParallelAnimation {
            NumberAnimation { target: flyer; property: "x"; to: root.width / 2 - flyer.width / 2; duration: Theme.durOrbitFly * 0.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita }
            NumberAnimation { target: flyer; property: "y"; to: root.height / 2 - flyer.height / 2; duration: Theme.durOrbitFly * 0.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita }
        }
        ScriptAction { script: Wallpaper.apply(root.chosen.path, Wallpaper.growPos(root.screen)) }
        ParallelAnimation {
            NumberAnimation { target: flyer; property: "x"; to: 0; duration: Theme.durOrbitFly * 0.6; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar }
            NumberAnimation { target: flyer; property: "y"; to: 0; duration: Theme.durOrbitFly * 0.6; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar }
            NumberAnimation { target: flyer; property: "width"; to: root.width; duration: Theme.durOrbitFly * 0.6; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar }
            NumberAnimation { target: flyer; property: "height"; to: root.height; duration: Theme.durOrbitFly * 0.6; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar }
            NumberAnimation { target: flyer; property: "radius"; to: 0; duration: Theme.durOrbitFly * 0.6; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar }
        }
        NumberAnimation { target: flyer; property: "opacity"; to: 0; duration: Theme.durOrbitReveal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSalida }
        ScriptAction { script: ShellState.close() }
    }
}
