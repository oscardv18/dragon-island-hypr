// =============================================================================
// dragon-island — Launcher.qml: the orbital launcher (SUPER + Space)
// A glass "planet" with the search field in the middle and a tilted elliptical ring of app icons that turns
// slowly (one revolution per Theme.orbitPeriod). Icons at the back are smaller, dimmer and pass BEHIND the
// planet (they are drawn by OrbitBack.qml, a window mapped below the planet's glass); the ones in front are larger and sharp; the name of the front icon shows under it.
//   empty search : favourites + most used (max 16); more results go to a second, outer, dimmer ring
//   typing       : fuzzy search; non-matching icons fade, the rest redistribute; the ring stops with the best
//                  match in front. A single match grows and glows in the accent colour.
//   =expression  : the result shows in the planet, Enter copies it      >command : Enter runs it in Ghostty
//   ← → / wheel  : turn the ring and change the selection · Enter launches · right click = favourite · Esc closes
// The ring animation only runs while the launcher is open.
// =============================================================================
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    readonly property string query: search.text

    // ---- what is on the rings ----
    readonly property var results: shown ? Apps.ringEntries(query, Theme.orbitInner) : []
    readonly property var ringEntries: results.slice(0, Theme.orbitInner * 2)
    readonly property int n1: Math.min(Theme.orbitInner, ringEntries.length)
    readonly property int n2: Math.max(0, ringEntries.length - Theme.orbitInner)
    readonly property string calcResult: query.startsWith("=") ? Apps.calc(query.slice(1)) : ""
    readonly property bool isCommand: query.startsWith(">")
    readonly property bool special: query.startsWith("=") || isCommand

    // ---- rotation: automatic turn + a spring-driven offset for keyboard / wheel selection ----
    property real spinAuto: 0
    property real off1: 0
    property real off2: 0
    property bool picked: false
    property int sel: 0
    readonly property bool auto: shown && query.length === 0 && !picked
    readonly property real spin1: spinAuto + off1
    readonly property real spin2: off2 - 0.6 * spinAuto

    Behavior on off1 { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping; modulus: Math.PI * 2 } }
    Behavior on off2 { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping; modulus: Math.PI * 2 } }

    FrameAnimation {
        running: root.auto
        onTriggered: root.spinAuto += frameTime * 2 * Math.PI / Theme.orbitPeriod
    }

    // index (in ringEntries) of the icon in front: the one the ring is turning past, or the selection
    readonly property int frontIdx: {
        if (ringEntries.length === 0) return -1;
        if (!auto) return Math.min(sel, ringEntries.length - 1);
        const n = Math.max(1, n1);
        const j = Math.round(((Math.PI / 2 - spin1) / (2 * Math.PI)) * n);
        return ((j % n) + n) % n;
    }
    readonly property var frontEntry: frontIdx >= 0 ? ringEntries[frontIdx] : null

    function _bring(idx: int): void {
        if (idx < Theme.orbitInner) off1 = Math.PI / 2 - 2 * Math.PI * idx / Math.max(1, n1) - spinAuto;
        else off2 = Math.PI / 2 - 2 * Math.PI * (idx - Theme.orbitInner) / Math.max(1, n2) + 0.6 * spinAuto;
    }

    function select(idx: int): void {
        if (ringEntries.length === 0) return;
        const from = auto ? Math.max(0, frontIdx) : sel;
        sel = Math.max(0, Math.min(ringEntries.length - 1, idx < 0 ? from + idx : idx));
        picked = true;
        _bring(sel);
    }
    function step(delta: int): void {
        if (ringEntries.length === 0) return;
        const from = auto ? Math.max(0, frontIdx) : sel;
        sel = (from + delta + ringEntries.length) % ringEntries.length;
        picked = true;
        _bring(sel);
    }

    function launch(entry): void {
        if (!entry) return;
        ShellState.close();
        Apps.launch(entry);
    }

    function accept(): void {
        if (calcResult.length > 0) { Apps.copy(calcResult); ShellState.close(); }
        else if (isCommand) { const c = query.slice(1).trim(); if (c.length > 0) { ShellState.close(); Apps.runInTerminal(c); } }
        else launch(frontEntry);
    }

    function focusSearch(): void { search.forceActiveFocus(); }

    onQueryChanged: {
        sel = 0;
        picked = false;
        if (query.length > 0) { picked = true; _bring(0); }   // the best match comes to the front and the ring stops
    }

    onShownChanged: {

        if (shown) {
            search.text = "";
            picked = false;
            sel = 0;
            ringTimer.restart();
        } else {
            ringOn = false;
        }
    }

    // opening: the planet grows first, the ring appears a moment later
    property bool ringOn: false
    Timer { id: ringTimer; interval: 200; onTriggered: { root.ringOn = true } }
    property real planetScale: shown ? 1 : 0
    Behavior on planetScale { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchAppearSpring; damping: Theme.notchAppearDamping; epsilon: 0.002 } }
    property real ringProgress: ringOn ? 1 : 0
    Behavior on ringProgress { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: 0.5; epsilon: 0.002 } }

    WheelHandler {
        enabled: root.shown
        onWheel: e => root.step(e.angleDelta.y > 0 ? -1 : 1)
    }

    // the ring and the planet share one centre
    Item {
        id: orbit
        x: root.width / 2
        y: root.height / 2
        visible: root.planetScale > 0.01

        // ---- one delegate per installed app: the front half of the ring (the back half is OrbitBack.qml, in a window below the planet) ----
        Repeater {
            model: Apps.list
            delegate: OrbitIcon {
                launcher: root
                half: "front"
            }
        }

        // ---- the planet: a glass disc (hyprglass takes its shape from the alpha) with the search field ----
        Rectangle {
            id: planet
            width: Theme.orbitPlanet
            height: Theme.orbitPlanet
            x: -width / 2
            y: -height / 2
            radius: width / 2
            z: 0
            scale: root.planetScale
            color: Theme.transparent        // the glass disc is PlanetGlass (its own window, for the rim)

            // swallow clicks (clicking outside the launcher closes it, the planet must not)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingLg * 2
                spacing: Theme.spacingSm

                UiText {
                    visible: root.calcResult.length > 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: `= ${root.calcResult}`
                    mono: true
                    size: Theme.sizeGreeting
                    weight: Theme.weightSemiBold
                    color: Theme.accent
                    shadow: true
                }

                Item {
                    width: parent.width
                    height: Theme.touchTarget

                    TextInput {
                        id: search
                        anchors.fill: parent
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        selectionColor: Theme.alpha(Theme.accent, 0.5)
                        selectedTextColor: Theme.onBrand
                        font.family: Theme.fontUi
                        font.pixelSize: Math.round(Theme.sizeTitle)
                        clip: true
                        cursorVisible: activeFocus
                        onAccepted: root.accept()
                        Keys.onEscapePressed: ShellState.close()
                        Keys.onLeftPressed: e => root.step(-1)
                        Keys.onRightPressed: e => root.step(1)
                        Keys.onUpPressed: e => root.step(-1)
                        Keys.onDownPressed: e => root.step(1)
                        Keys.onTabPressed: root.step(1)
                        Keys.onBacktabPressed: root.step(-1)
                    }
                    UiText {
                        anchors.fill: parent
                        visible: search.text.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: "Buscar…"
                        size: Theme.sizeTitle
                        color: Theme.textDim
                    }
                }

                UiText {
                    visible: root.isCommand || (root.query.startsWith("=") && root.calcResult.length === 0) || root.ringEntries.length === 0 && root.query.length > 0 && !root.special
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isCommand ? "Enter: ejecutar en Ghostty" : (root.query.startsWith("=") ? "Escribe una operación" : "Sin resultados")
                    size: Theme.sizeCaption + 1
                    color: Theme.textDim
                }
            }
        }
    }
}
