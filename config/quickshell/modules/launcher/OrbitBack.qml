// =============================================================================
// dragon-island — OrbitBack.qml
// The back half of the orbital launcher's ring (icons with depth < -0.15), in a layer window of its own
// (namespace "dragon-launcher") mapped BELOW the planet's glass (PlanetGlass): that is what makes the icons
// pass behind the disc instead of over it — they are seen blurred through the glass. The icons in front are
// drawn by Launcher.qml, above the planet. Same state, same maths (OrbitIcon.qml). Takes no input.
// The window only covers the upper part of the ring, where the back icons are, and is centred horizontally.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"

PanelWindow {
    id: win

    property var modelData
    required property var launcher
    screen: modelData

    readonly property real above: 290      // ring centre → top of the window (outer ring + tilt + icon pill)
    readonly property real below: 110

    anchors { top: true }
    margins.top: Math.max(0, (modelData?.height ?? 768) / 2 - above)
    implicitWidth: Math.round(Theme.orbitRx * 1.38 * 2 + Theme.orbitIcon * 3)
    implicitHeight: above + below
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        x: win.width / 2
        y: win.above
        visible: win.launcher.planetScale > 0.01

        Repeater {
            model: Apps.list
            delegate: OrbitIcon {
                launcher: win.launcher
                half: "back"
            }
        }
    }
}
