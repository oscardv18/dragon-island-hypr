// =============================================================================
// dragon-island — PlanetGlass.qml
// The orbital launcher's planet in a layer window of its own, exactly as big as the disc (namespace "dragon-planet"; it
// never changes size, the disc grows inside it). Its own namespace because hyprglass lights a rim from the layer's
// RECTANGLE: on a circle that only shows as white patches where the disc touches the square, so glass.lua gives this
// namespace plain liquid glass (blur + tint, no bevel / specular / fresnel / refraction).
// OrbitalLauncher maps it after the back ring and before the launcher window, so the back icons pass behind the
// disc and the front ones over it.
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
    WlrLayershell.namespace: "dragon-planet"
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
