// =============================================================================
// dragon-island — PlanetGlass.qml
// The orbital launcher's planet in a layer window of its own (namespace "dragon-launcher", so it gets the same liquid
// glass): hyprglass draws the rim relief (bevel, specular, refraction) from the layer's rectangle, so a shape inside a
// full-screen layer is flat, but a window exactly as big as the disc gets the real edge. The window never changes size
// (the disc grows inside it). OrbitalLauncher maps it after the back ring and before the launcher window, so the back
// icons pass behind the disc and the front ones over it.
// The search field stays in the launcher window (this one takes no input).
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
    readonly property string screenName: modelData?.name ?? ""

    // no anchors: the layer is centred on the screen, where the launcher puts the planet
    implicitWidth: Theme.orbitPlanet
    implicitHeight: Theme.orbitPlanet
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool shown: ShellState.openPanel === "launcher" && (ShellState.panelScreen === "" || ShellState.panelScreen === screenName)
    property real scaleNow: shown ? 1 : 0
    Behavior on scaleNow { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchAppearSpring; damping: Theme.notchAppearDamping; epsilon: 0.002 } }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.popoverBg
        scale: win.scaleNow
        visible: win.scaleNow > 0.01
    }
}
