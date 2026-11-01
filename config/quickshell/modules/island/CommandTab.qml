// «Mando», the body of the isla de mando (docs/design/31-isla-mando.png), built from the three proposals of board 30:
//   left    priority stack (B): one big card, the next two as thin rows (a click raises one); wheel or ← → turn it;
//           no cards: «Todo en orden» (services/Priority.qml)
//   centre  the 92 px NeuralCore (A) following the agents: working → thinking, one waiting → alert (amber), done → ok;
//           «N AGENTES · M ESPERA» under it; a click opens the IA tab
//   right   music (A): art, title, artist · app, progress and controls; the wave is real with cava (services/Cava.qml),
//           else soft decorative bars only while playing (still with reduced motion); no player: «Nada sonando»
//   bottom  the 6 h time strip (C, TimeStrip.qml) and five round toggles (A): Wi‑Fi, Bluetooth, No molestar, Cafeína,
//           Enfoque — click toggles, right click opens their panel
// Width 600 – 740 (always centred, BarMetrics.commandWidth): the stack takes what is left; the core and the music keep
// their minimum (Theme.cmdCoreMin / cmdMusicMin); the 6 h strip fills the bottom row next to the toggles.
// The zones enter in cascade (40 ms apart) when the island expands; nothing here animates while it is collapsed
// (this whole tab only exists while expanded).
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property string screenName: ""
    signal askAi()
    signal goTab(string tab)

    // ---- priority stack state ----
    property string raised: ""          // key of a card raised by a click (stays on top while it exists)
    property int turn: 0                // wheel / arrows
    readonly property var cards: {
        const c = Priority.cards.slice();
        const i = c.findIndex(x => x.key === root.raised);
        if (i > 0) c.unshift(c.splice(i, 1)[0]);
        const n = c.length;
        if (n > 1 && root.turn !== 0) { const k = ((root.turn % n) + n) % n; return c.slice(k).concat(c.slice(0, k)); }
        return c;
    }

    focus: true
    Keys.onLeftPressed: root.turn--
    Keys.onRightPressed: root.turn++

    // cascade of the zones
    property real enter: 0
    NumberAnimation on enter { from: 0; to: 1; duration: Theme.cmdStagger * 4 + Theme.durRowIn; running: true }
    function zone(i: int): real {
        const total = Theme.cmdStagger * 4 + Theme.durRowIn;
        return total <= 0 ? 1 : Math.max(0, Math.min(1, (root.enter * total - i * Theme.cmdStagger) / Math.max(1, Theme.durRowIn)));
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingSm + 2

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingMd

            // ======== priority stack ========
            ColumnLayout {
                id: stack
                Layout.fillWidth: true                     // takes what is left (600 – 740 wide island): gives way first
                Layout.fillHeight: true
                spacing: Theme.spacingXs
                opacity: root.zone(0)
                transform: Translate { y: Theme.hudRowShift * (1 - root.zone(0)) }
                WheelHandler { onWheel: e => root.turn += e.angleDelta.y > 0 ? -1 : 1 }

                Rectangle {
                    id: bigCard
                    readonly property var card: root.cards[0] ?? null
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.hudCardRadius
                    color: Theme.cmdFill
                    border.width: 1
                    border.color: card ? Theme.alpha(card.tone, 0.35) : Theme.cmdEdge

                    // empty: a quiet state
                    Column {
                        visible: bigCard.card === null
                        anchors.centerIn: parent
                        spacing: Theme.spacingXs
                        Glyph { anchors.horizontalCenter: parent.horizontalCenter; icon: Icons.check; size: Theme.iconLg; color: Theme.ok }
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: "Todo en orden"; weight: Theme.weightMedium; color: Theme.textSoft }
                        HudCaption {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(implicitWidth, bigCard.width - Theme.spacingMd * 2)   // narrow island: wraps inside the card
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            text: "sin agentes, reuniones ni avisos"
                        }
                    }

                    ColumnLayout {
                        visible: bigCard.card !== null
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            HudCaption { Layout.fillWidth: true; text: bigCard.card?.label ?? ""; color: bigCard.card?.tone ?? Theme.textDim }
                            HudCaption { text: bigCard.card?.when ?? "" }
                        }
                        UiText { Layout.fillWidth: true; text: bigCard.card?.title ?? ""; size: Theme.sizeBodyLg; weight: Theme.weightSemiBold }
                        UiText { Layout.fillWidth: true; text: bigCard.card?.sub ?? ""; size: Theme.sizeCaption + 1.5; color: Theme.textDim }
                        Item { Layout.fillHeight: true }
                        Row {
                            spacing: Theme.spacingXs + 2
                            Repeater {
                                model: {
                                    const c = bigCard.card;
                                    if (!c) return [];
                                    switch (c.kind) {
                                        case "agent": return [{ k: "answer", l: "Ir al panel", on: true }, { k: "ignoreAgent", l: "Ignorar 10 min" }];
                                        case "meeting": return (Priority.meetingLink(c.payload) ? [{ k: "join", l: "Unirse", on: true }] : []).concat([{ k: "snooze", l: "Posponer 5 min" }]);
                                        case "focus": return [{ k: "pause", l: Focus.paused ? "Reanudar" : "Pausar", on: true }, { k: "stop", l: "Terminar" }];
                                        case "command": return [{ k: "terminal", l: "Abrir terminal", on: true }];
                                        case "updates": return [{ k: "update", l: "Actualizar", on: true }];
                                    }
                                    return [];
                                }
                                delegate: HudChip {
                                    required property var modelData
                                    label: modelData.l
                                    active: modelData.on === true
                                    implicitHeight: Theme.hudChip - 4
                                    onClicked: {
                                        const c = bigCard.card;
                                        switch (modelData.k) {
                                            case "answer": Herdr.focusAgent(c.payload); ShellState.close(); break;
                                            case "ignoreAgent": Herdr.snooze(c.payload, 10); break;
                                            case "join": Priority.join(c.payload); ShellState.close(); break;
                                            case "snooze": Priority.snooze(c.key, 5); break;
                                            case "pause": Focus.togglePause(); break;
                                            case "stop": Focus.stop(); break;
                                            case "terminal": Priority.openTerminal(c.payload); ShellState.close(); break;
                                            case "update": Updates.run(); ShellState.close(); break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // the next two, as thin rows (a click raises one)
                Repeater {
                    model: root.cards.slice(1, 3)
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        radius: 6
                        color: thinMouse.containsMouse ? Theme.hudRowHover : Theme.cmdFill
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingSm
                            anchors.rightMargin: Theme.spacingSm
                            spacing: Theme.spacingSm
                            Rectangle { width: 6; height: 6; radius: 3; color: modelData.tone }
                            UiText { Layout.fillWidth: true; text: modelData.title; size: Theme.sizeCaption + 1.5 }
                            HudCaption { text: modelData.when }
                        }
                        MouseArea { id: thinMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.turn = 0; root.raised = modelData.key; } }
                    }
                }
            }

            // ======== neural core ========
            ColumnLayout {
                Layout.preferredWidth: Theme.cmdCoreMin
                Layout.minimumWidth: Theme.cmdCoreMin      // never squeezed: the stack gives way first
                Layout.fillHeight: true
                spacing: 0
                opacity: root.zone(1)
                transform: Translate { y: Theme.hudRowShift * (1 - root.zone(1)) }
                readonly property int working: Herdr.counts?.working ?? 0
                readonly property int waiting: Herdr.counts?.blocked ?? 0
                readonly property int total: Herdr.agents.length
                Core {
                    id: core
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Theme.cmdCore
                    Layout.preferredHeight: Theme.cmdCore
                    identity: Theme.coreIdentity
                    bare: true
                    fps: 30
                    mood: parent.waiting > 0 ? "alert" : (parent.working > 0 ? "thinking" : ((Herdr.counts?.done ?? 0) > 0 ? "ok" : "calm"))
                    reducedMotion: Settings.calmMotion || !Theme.animationsEnabled
                    running: root.visible && Theme.animationsEnabled
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.goTab("ia") }
                }
                HudCaption { Layout.alignment: Qt.AlignHCenter; text: parent.total === 1 ? "1 agente" : `${parent.total} agentes`; color: Theme.cyan }
                HudCaption { Layout.alignment: Qt.AlignHCenter; text: parent.waiting > 0 ? `${parent.waiting} espera` : (parent.working > 0 ? `${parent.working} trabajando` : "en calma") }
                Item { Layout.fillHeight: true }
            }

            // ======== music ========
            MusicCard {
                Layout.preferredWidth: Theme.cmdMusicWidth
                Layout.minimumWidth: Theme.cmdMusicMin     // never squeezed below this: the stack gives way first
                Layout.fillHeight: true
                opacity: root.zone(2)
                transform: Translate { y: Theme.hudRowShift * (1 - root.zone(2)) }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.cmdStrip
            spacing: Theme.spacingMd

            TimeStrip {
                Layout.fillWidth: true
                Layout.fillHeight: true
                screenName: root.screenName
                opacity: root.zone(3)
                transform: Translate { y: Theme.hudRowShift * (1 - root.zone(3)) }
            }

            Row {
                spacing: Theme.spacingSm
                opacity: root.zone(4)
                transform: Translate { y: Theme.hudRowShift * (1 - root.zone(4)) }
                Repeater {
                    model: [
                        { key: "wifi", icon: Icons.wifiFor(1, true), on: Toggles.wifi, panel: "wifi", tip: "Wi‑Fi" },
                        { key: "bt", icon: Icons.bluetooth, on: Toggles.bluetooth, panel: "bt", tip: "Bluetooth" },
                        { key: "dnd", icon: Icons.bellOff, on: Toggles.dnd, panel: "notifications", tip: "No molestar" },
                        { key: "caffeine", icon: Icons.coffee, on: Caffeine.enabled, panel: "", tip: "Cafeína" },
                        { key: "focus", icon: Icons.timer, on: Focus.active, panel: "calendar", tip: "Enfoque" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: Theme.cmdToggle
                        height: Theme.cmdToggle
                        radius: width / 2
                        color: modelData.on ? Theme.cyan : (tMouse.containsMouse ? Theme.hudRowHover : Theme.alpha(Theme.text, 0.07))
                        Behavior on color { ColorAnimation { duration: Theme.durStd } }
                        Glyph { anchors.centerIn: parent; icon: modelData.icon; size: Theme.iconSm; color: modelData.on ? Theme.islandInk : Theme.textSoft }
                        MouseArea {
                            id: tMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: m => {
                                if (m.button === Qt.RightButton) { if (modelData.panel) ShellState.open(modelData.panel, root.screenName); return; }
                                switch (modelData.key) {
                                    case "wifi": Toggles.toggleWifi(); break;
                                    case "bt": Toggles.toggleBluetooth(); break;
                                    case "dnd": Toggles.toggleDnd(); break;
                                    case "caffeine": Caffeine.toggle(); break;
                                    case "focus": Focus.toggle(); break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
