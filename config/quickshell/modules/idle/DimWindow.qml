// =============================================================================
// dragon-island — DimWindow.qml (namespace "dragon-dim", layer Top: over the windows, under the island so its warning
// stays readable)
// The idle dim: a black layer rising to Theme.idleDimOpacity in Theme.durDim (Estándar curve) while Idle.warning,
// on every monitor (no DDC / backlight change). No input (the next mouse move is hypridle's resume), no blur; unmapped
// when it is not needed.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

PanelWindow {
    id: win
    property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    visible: Idle.warning || shade.opacity > 0.001
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dragon-dim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: shade
        anchors.fill: parent
        color: Theme.island
        opacity: Idle.warning ? Theme.idleDimOpacity : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Idle.warning ? Theme.durDim : Theme.durOut
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Idle.warning ? Theme.curveEstandar : Theme.curveSalida
            }
        }
    }
}
