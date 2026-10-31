// HUD frame of every bar popover (docs/design/28-emergentes.png, 29-paneles-*.png).
//   material   the glass of Theme (ahumado / clásico / líquido): glassFill, glassBorder, light edge, soft shadow
//   header     an uppercase monospaced caption, a line that fades out to the right, «● EN VIVO» when `live`, and
//              `headerRight` (a switch, usually)
//   brackets   four cyan corner brackets (12 px, 1.5 px stroke, radius 6) that appear when the opening ends
//   rows       every direct child of the body enters in cascade (opacity + 8 px, 40 ms apart)
// Opening (≤ 600 ms, the four curves of Theme):
//   1 the capsule that opened it glows cyan (Capsule.active)          2 beam: a 1.5 px cyan line with a glow runs
//   down from the capsule to the frame (180 ms, estandar)             3 unfold: the frame opens clipped from where
//   the beam lands, first in width, then down (300 ms, emergente)     4 rows in cascade; then the brackets and,
//   last, `filled` goes 0 → 1 so segmented bars, dials and charts fill after the rows.
// Closing (≤ 400 ms): rows out (100 ms) → the clip folds back into the beam (160 ms, salida) → the beam retracts
// (120 ms). Settings.calmMotion (reduceMotion): only a 120 ms fade. Theme.motionScale 0: instant.
// `beamX` is the x of the capsule's centre, local to the frame (PopoverHost computes it from ShellState).
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import ".."
import "../services"

Item {
    id: root

    property bool shown: false
    property string title: ""
    property bool live: false            // «● EN VIVO» in the header
    property real popWidth: Theme.hudWidth
    property real beamX: width / 2
    property real originX: width         // legacy (PopoverHost still passes it)
    default property alias content: body.data
    property alias headerRight: headerRight.data
    readonly property real filled: _fill // 0 → 1 after the rows: meters bind their fill to it
    readonly property bool fullyOpen: _w >= 1 && _h >= 1 && !closeAnim.running
    readonly property real t: _calm ? _fade : _beam

    signal opened()
    signal closed()

    width: popWidth
    implicitHeight: frame.implicitHeight
    height: implicitHeight
    visible: _beam > 0.001 || _fade > 0.001

    // ---- timeline ----
    property real _beam: 0        // beam length 0 → 1
    property real _w: 0           // unfold in width
    property real _h: 0           // unfold downward
    property real _rows: 0        // cascade 0 → 1 (closing: uniform fade)
    property real _brackets: 0
    property real _fill: 0
    property real _fade: 0        // calm mode only
    property bool _closing: false
    readonly property bool _calm: Settings.calmMotion
    readonly property real _bx: Math.max(Theme.hudRadius, Math.min(width - Theme.hudRadius, beamX))

    onShownChanged: {
        openAnim.stop(); closeAnim.stop(); calmAnim.stop(); startLater.stop();
        if (shown) {
            root._closing = false;
            if (root._calm) { root._beam = 1; root._w = 1; root._h = 1; root._rows = 1; root._brackets = 1; root._fill = 1; calmAnim.to = 1; calmAnim.start(); }
            else { root._fade = 0; startLater.restart(); }
            root.opened();
        } else {
            root._closing = true;
            if (root._calm) { calmAnim.to = 0; calmAnim.start(); }
            else closeAnim.start();
            root.closed();
        }
    }
    on_CalmChanged: if (!_calm && shown) { _fade = 0; _beam = 1; }

    // the popover window is unmapped while nothing is open: an animation started in the same tick as the mapping did not
    // advance on the very first opening after Quickshell starts (its window was not exposed yet), so it starts a beat later
    Timer { id: startLater; interval: 30; onTriggered: if (root.shown) openAnim.start() }

    NumberAnimation { id: calmAnim; target: root; property: "_fade"; duration: Theme.durCalmFade; easing.type: Easing.OutCubic
        onStopped: if (!root.shown) { root._beam = 0; root._w = 0; root._h = 0; root._rows = 0; root._brackets = 0; root._fill = 0; } }

    SequentialAnimation {
        id: openAnim
        ScriptAction { script: { if (root._beam <= 0.001) { root._w = 0; root._h = 0; root._rows = 0; root._brackets = 0; root._fill = 0; } } }
        NumberAnimation { target: root; property: "_beam"; to: 1; duration: Theme.durBeam; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar }
        NumberAnimation { target: root; property: "_w"; to: 1; duration: Theme.durUnfoldW; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmergente }
        ParallelAnimation {
            NumberAnimation { target: root; property: "_h"; to: 1; duration: Theme.durUnfoldH; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmergente }
            SequentialAnimation {
                PauseAnimation { duration: Theme.durUnfoldH / 3 }
                NumberAnimation { target: root; property: "_rows"; to: 1; duration: Theme.durCascade; easing.type: Easing.Linear }
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.durUnfoldH }
                NumberAnimation { target: root; property: "_brackets"; to: 1; duration: Theme.durBrackets; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: Theme.durUnfoldH / 3 + Theme.durCascade * 0.6 }
                NumberAnimation { target: root; property: "_fill"; to: 1; duration: Theme.durFill; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar }
            }
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "_rows"; to: 0; duration: Theme.durRowsOut; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "_brackets"; to: 0; duration: Theme.durRowsOut; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "_h"; to: 0; duration: Theme.durFold; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSalida }
            NumberAnimation { target: root; property: "_w"; to: 0; duration: Theme.durFold; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSalida }
        }
        NumberAnimation { target: root; property: "_beam"; to: 0; duration: Theme.durBeamOut; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSalida }
        ScriptAction { script: root._fill = 0 }
    }

    // ---- rows in cascade: every visible direct child of the body ----
    property var _shifts: new Map()
    function _cascade(): void {
        const kids = [];
        for (let i = 0; i < body.children.length; i++) {
            const c = body.children[i];
            if (c.visible) kids.push(c);
            else c.opacity = 1;     // hidden rows wait at full opacity: when they show up later they are not stuck at 0
        }
        const n = kids.length;
        const total = Math.max(1, Theme.durCascade);
        const rowDur = Math.max(1, Theme.durRowIn);
        const stagger = n > 1 ? Math.min(Theme.durRowStagger, Math.max(0, total - rowDur) / (n - 1)) : 0;
        for (let i = 0; i < n; i++) {
            const c = kids[i];
            const local = root._closing ? root._rows : Math.max(0, Math.min(1, (root._rows * total - i * stagger) / rowDur));
            let tr = root._shifts.get(c);
            if (!tr) {
                tr = shiftComponent.createObject(c);
                c.transform = [tr];
                root._shifts.set(c, tr);
            }
            tr.y = root._closing ? 0 : Theme.hudRowShift * (1 - local);
            c.opacity = local;
        }
    }
    on_RowsChanged: _cascade()
    Component { id: shiftComponent; Translate {} }

    // ---- the beam: from the capsule (bar bottom) down to the frame ----
    Item {
        id: beam
        x: root._bx - Theme.hudBeam / 2
        y: -Theme.hudGap
        width: Theme.hudBeam
        height: Theme.hudGap
        visible: !root._calm && root._beam > 0.001
        // grows down while opening; while closing it retracts upward (anchored at the bar)
        Rectangle {
            id: beamLine
            width: parent.width
            height: parent.height * root._beam
            y: 0
            color: Theme.cyan
        }
        GlassShadow {
            anchors.fill: beamLine
            radius: 1
            blur: Theme.hudBeamGlow
            offset.y: 0
            color: Theme.haloCyan
            visible: true
        }
    }

    GlassShadow {
        anchors.fill: clipper
        radius: Theme.hudRadius
        opacity: root._h
    }

    // ---- the frame, revealed by a clip that unfolds from the beam point ----
    Item {
        id: clipper
        readonly property real lineH: 2
        x: root._calm ? 0 : root._bx * (1 - root._w)
        width: root._calm ? root.width : root._bx * root._w + (root.width - root._bx) * root._w
        height: root._calm ? frame.height : Math.max(root._w > 0 ? lineH : 0, frame.height * root._h)
        clip: true
        opacity: root._calm ? root._fade : 1
        visible: width > 0.5 && height > 0.5

        Rectangle {
            id: frame
            x: -clipper.x
            width: root.width
            implicitHeight: col.implicitHeight + Theme.hudPad * 2
            height: implicitHeight
            radius: Theme.hudRadius
            color: Theme.popoverBg
            border.width: 1
            border.color: Theme.glassBorder

            GlassLight { cornerRadius: frame.radius }

            // swallow clicks so they don't reach the click-outside catcher underneath
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onWheel: w => w.accepted = true
            }

            ColumnLayout {
                id: col
                x: Theme.hudPad
                y: Theme.hudPad
                width: parent.width - Theme.hudPad * 2
                spacing: Theme.spacingMd

                // header: CAPTION ———— ● EN VIVO [right]
                RowLayout {
                    visible: root.title.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.switchHeight
                    spacing: Theme.spacingMd
                    opacity: Math.min(1, root._rows * 3)

                    HudCaption { text: root.title }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.hudLine }
                            GradientStop { position: 1.0; color: Theme.transparent }
                        }
                    }
                    Row {
                        visible: root.live
                        spacing: Theme.spacingXs + 1
                        Layout.alignment: Qt.AlignVCenter
                        Rectangle { width: 6; height: 6; radius: 3; color: Theme.ok; anchors.verticalCenter: parent.verticalCenter }
                        HudCaption { text: "en vivo"; color: Theme.ok }
                    }
                    Row {
                        id: headerRight
                        spacing: Theme.spacingSm
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                ColumnLayout {
                    id: body
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd
                }
            }
        }
    }

    HudBrackets {
        anchors.fill: clipper
        visible: !root._calm && root._brackets > 0.001
        opacity: root._brackets
        grow: 1 - root._brackets
    }
}
