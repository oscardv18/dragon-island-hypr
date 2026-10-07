// =============================================================================
// dragon-island — OrbitalLauncher.qml
// The orbital launcher on one monitor: three layer windows that must be mapped in this order, because windows of
// one layer stack in mapping order (the last one mapped is on top):
//   1. OrbitBack      the icons at the back of the ring
//   2. PlanetGlass    the glass disc (liquid glass from the alpha shape)
//   3. LauncherWindow the icons in front, the search field, power menu / clipboard / shortcuts
// So the back icons really pass BEHIND the planet. While the launcher is closed all three are unmapped
// (a mapped glass layer costs GPU every frame); opening maps them in order, a moment apart.
// =============================================================================
import Quickshell
import QtQuick
import "../.."
import "../../services"

Scope {
    id: root

    property var modelData
    readonly property string screenName: modelData?.name ?? ""

    readonly property bool shown: ShellState.openPanel === "launcher" && (ShellState.panelScreen === "" || ShellState.panelScreen === screenName)

    // 0 = nothing mapped · 1 = back ring · 2 = + planet · 3 = + launcher window
    property int stage: 0

    onShownChanged: {
        if (shown) {
            linger.stop();
            if (stage === 0) { stage = 1; toPlanet.restart(); }
            else stage = 3;
        } else {
            toPlanet.stop();
            toWindow.stop();
            linger.restart();
        }
    }

    Timer { id: toPlanet; interval: 45; onTriggered: { root.stage = 2; toWindow.restart(); } }
    Timer { id: toWindow; interval: 45; onTriggered: root.stage = 3 }
    // after closing, let the planet and the ring finish their animation before unmapping
    Timer { id: linger; interval: 900; onTriggered: root.stage = 0 }

    OrbitBack {
        modelData: root.modelData
        launcher: window.launcher
        visible: root.stage >= 1
    }

    PlanetGlass {
        modelData: root.modelData
        visible: root.stage >= 2
    }

    LauncherWindow {
        id: window
        modelData: root.modelData
        orbitReady: root.stage >= 3
    }
}
