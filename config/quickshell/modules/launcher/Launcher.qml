// =============================================================================
// dragon-island — Launcher.qml: the orbital launcher (SUPER + Space)
// A glass "planet" with the search field in the middle and a tilted elliptical ring of app icons that turns
// slowly (one revolution per Theme.orbitPeriod). Icons at the back are smaller, dimmer and pass BEHIND the
// planet; the ones in front are larger and sharp; the name of the front icon shows under it.
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

        // ---- one delegate per installed app: those that are not results fade out instead of vanishing ----
        Repeater {
            model: Apps.list
            delegate: Item {
                id: icon
                required property var modelData
                readonly property int idx: root.ringEntries.indexOf(modelData)
                readonly property bool present: idx >= 0 && root.shown
                readonly property int ring: idx < Theme.orbitInner ? 1 : 2
                readonly property real j: ring === 1 ? idx : idx - Theme.orbitInner
                readonly property real n: ring === 1 ? root.n1 : root.n2

                // slot and ring size are animated, so the icons glide to their new places when the results change
                property real aj: j
                property real an: Math.max(1, n)
                Behavior on aj { enabled: icon.present && Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping } }
                Behavior on an { enabled: icon.present && Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping } }

                readonly property real theta: (ring === 1 ? root.spin1 : root.spin2) + 2 * Math.PI * aj / an
                readonly property real depth: Math.sin(theta)                   // 1 = in front, -1 = behind the planet
                readonly property real k: (depth + 1) / 2
                readonly property real outer: ring === 2 ? 1 : 0
                readonly property real rx: Theme.orbitRx * (1 + 0.38 * outer)
                readonly property real ry: Theme.orbitRy * (1 + 0.5 * outer)
                readonly property real tilt: Theme.orbitTilt * Math.PI / 180
                readonly property real px: rx * Math.cos(theta)
                readonly property real py: ry * depth
                readonly property bool isFront: present && idx === root.frontIdx
                readonly property bool single: root.ringEntries.length === 1
                readonly property real boost: isFront && !root.auto ? (single ? 1.55 : 1.3) : 1

                x: (px * Math.cos(tilt) - py * Math.sin(tilt)) * root.ringProgress - width / 2
                y: (px * Math.sin(tilt) + py * Math.cos(tilt)) * root.ringProgress - height / 2
                width: Theme.orbitIcon
                height: Theme.orbitIcon
                z: depth >= 0 ? 2 + depth : -1 + depth                          // behind the planet when depth < 0
                scale: (0.6 + 0.55 * k) * (1 - 0.2 * outer) * boost * Math.min(1, root.ringProgress)
                opacity: present ? (0.4 + 0.6 * k) * (1 - 0.4 * outer) * Math.min(1, root.ringProgress) : 0
                visible: present || opacity > 0.01

                // accent glow behind the icon that is about to launch
                RectangularShadow {
                    anchors.fill: parent
                    radius: width / 2
                    blur: Theme.glowBlurSmall * 2
                    color: Theme.glowStrong
                    opacity: icon.isFront && !root.auto ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
                }

                // a circular glass pill behind the icon (the layer is glassed by alpha: hyprglass gives it the liquid-glass look)
                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.orbitIcon + 32
                    height: width
                    radius: width / 2
                    color: icon.isFront && !root.auto ? Theme.alpha(Theme.accent, 0.35) : Theme.pillBg
                    Behavior on color { ColorAnimation { duration: Theme.durFade } }
                }
                Image {
                    id: ico
                    anchors.fill: parent
                    source: icon.present || icon.opacity > 0.01 ? Apps.iconFor(icon.modelData) : ""
                    sourceSize: Qt.size(Theme.orbitIcon * 2, Theme.orbitIcon * 2)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                // a pinned app has a small accent dot
                Rectangle {
                    visible: Apps.isFavorite(icon.modelData)
                    width: Theme.pillDot + 1
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    anchors.right: parent.right
                    anchors.top: parent.top
                }

                // the name sits in a glass pill of its own, under the icon's pill (never over its edge)
                Rectangle {
                    visible: icon.isFront
                    anchors.top: parent.bottom
                    anchors.topMargin: Theme.spacingMd + 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 28
                    width: Math.min(Theme.orbitIcon * 4.5, nameText.implicitWidth + 28)
                    radius: height / 2
                    color: Theme.popoverBg
                    UiText {
                        id: nameText
                        anchors.centerIn: parent
                        width: parent.width - 20
                        horizontalAlignment: Text.AlignHCenter
                        text: icon.modelData.name
                        size: Theme.sizeBody
                        weight: Theme.weightSemiBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: icon.present && icon.depth > -0.2
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => {
                        if (m.button === Qt.RightButton) Apps.toggleFavorite(icon.modelData);
                        else root.launch(icon.modelData);
                    }
                }
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
