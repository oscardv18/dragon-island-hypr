// =============================================================================
// dragon-island — FrameWindow.qml (namespace "dragon-frame", Top layer)
// The frame of the focused window, now that windows have no title bar: the SAME FrameDecor as the popovers — a thin top
// line (lavender → cyan) and four cyan corner brackets — over the window's real box (services/WindowFrame.qml, fed by
// config/hypr/framewatch.lua), outside its 1 px native border and with its corner radius, so the brackets sit on the
// real edge. docs/design/28-emergentes.png, 32-contorno-ventana.png.
//   * follows focus, moves, resizes and workspace changes with a short estandar ease (Theme.motion.estandar); two
//     changes closer than that (a drag, a resize) snap instead, so it never lags behind the pointer
//   * hidden in fullscreen, on the drop-down terminal (joined to the island), while the session is locked and with
//     Ajustes › Apariencia › Contorno de ventanas = «nada»; «hilo» draws only the top line
//   * unfocused windows: nothing drawn here, only their dark native hairline (look.lua)
//   * Top layer: under every Quickshell panel (popovers, island, launcher are Overlay), over the windows
// No input (empty mask), no blur, no timer: it repaints only when the geometry, the focus or the mode change, and it
// is unmapped while there is nothing to draw on this monitor. IPC (`qs ipc call frame-<monitor> dump`): drawn vs real box.
// =============================================================================
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: win

    property var modelData
    property bool locked: false
    screen: modelData

    readonly property bool wanted: !locked && WindowFrame.shownOn(modelData?.name ?? "")
    // stays mapped while it fades out
    visible: wanted || box.opacity > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dragon-frame"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // outer box = the window plus its native border; the frame's radius is the border's outer radius
    readonly property real _b: WindowFrame.border
    readonly property real _tx: WindowFrame.winX - _b
    readonly property real _ty: WindowFrame.winY - _b
    readonly property real _tw: WindowFrame.winW + _b * 2
    readonly property real _th: WindowFrame.winH + _b * 2

    // snap (no ease) when the frame appears, or when changes come faster than the ease (drag / resize)
    property bool _snap: true
    function _follow(): void {
        win._snap = !win.wanted || box.opacity < 0.01 || WindowFrame.interval < Theme.motion.estandar;
        box.x = win._tx; box.y = win._ty; box.width = win._tw; box.height = win._th;
    }
    Connections {
        target: WindowFrame
        function onStampChanged() { win._follow(); }
    }
    onWantedChanged: if (wanted) _follow()
    Component.onCompleted: _follow()

    // checks (tests, HANDOFF): `qs ipc call frame-<monitor> dump` → the drawn box next to the window's outer box
    IpcHandler {
        target: `frame-${win.modelData?.name ?? ""}`
        function dump(): string {
            return `wanted=${win.wanted} mode=${WindowFrame.mode} drawn=${Math.round(box.x)},${Math.round(box.y)} ${Math.round(box.width)}x${Math.round(box.height)}`
                 + ` window=${win._tx},${win._ty} ${win._tw}x${win._th} radius=${WindowFrame.rounding + win._b}`;
        }
    }

    Item {
        id: box
        opacity: win.wanted ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.motion.estandar; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
        Behavior on x { enabled: !win._snap; NumberAnimation { duration: Theme.motion.estandar; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
        Behavior on y { enabled: !win._snap; NumberAnimation { duration: Theme.motion.estandar; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
        Behavior on width { enabled: !win._snap; NumberAnimation { duration: Theme.motion.estandar; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
        Behavior on height { enabled: !win._snap; NumberAnimation { duration: Theme.motion.estandar; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }

        FrameDecor {
            anchors.fill: parent
            radius: WindowFrame.rounding + win._b
            line: WindowFrame.mode !== "nada"
            brackets: WindowFrame.mode === "escuadras"
        }
    }
}
