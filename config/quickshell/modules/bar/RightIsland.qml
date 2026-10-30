// Right island (docs/design/19-islas.png), in this order:
//   [contextual capsules] · CPU ring · RAM ring · network line · │ · keyboard · tiling · Wi-Fi · BT · volume · battery · orbital clock
// Meters (hidden with Settings.barMetrics = false): 15 px rings (CPU cyan, RAM lavender, track white 13 %) and a
// 30×12 cyan line of the last 12 download samples; hovering one shows its detail as a tooltip UNDER the island
// (the island never widens, HANDOFF §7t); a click opens the Rendimiento popover.
// Volume: icon + a 30×4 bar; wheel ±5 %, click = mute, right click = the Sonido popover.
// Orbital clock: a 14 px lavender ring with a cyan dot going round once a minute, the time in mono 12 semibold on
// white 6 %, the markers (No molestar, unread, updates) as tiny dots; click = calendar + notifications, right
// click = No molestar, the date as a tooltip.
// Neutral capsules: icons textSoft, hover white 8 %, open → accent tint (components/Capsule.qml).
// Style D (minimal): only the orbital clock. Style C (bare): no box, inside the joined strip.
import QtQuick
import Quickshell
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    required property var bar
    property real windowX: 0     // screen x of this island's window
    property real maxWidth: 0    // room the bar leaves it (contextual capsules that do not fit are grouped into "+N")
    property bool live: true     // its window is mapped

    // popovers of the right island: right edge on the capsule's right edge
    function openPopover(name: string, item): void { bar.openFrom(name, item, "right", windowX); }

    // what each contextual capsule does when clicked
    function chipAction(key: string, item): void {
        switch (key) {
            case "privacy": root.openPopover("privacy", item); break;
            case "rec":     Toggles.toggleRecording(); break;
            case "agents":  root.openPopover("agents", item); break;
            case "vpn":     Vpn.openApp(); break;
            case "headset": root.openPopover("bt", item); break;
            case "caffeine": Caffeine.toggle(); break;
        }
    }

    property bool bare: false            // C: drawn inside the joined strip, no box of its own
    readonly property bool minimal: Theme.barLook === "D"   // D: only the clock
    readonly property bool metrics: Settings.barMetrics && !minimal

    implicitHeight: Theme.barHeight
    height: Theme.barHeight
    width: row.implicitWidth + (minimal ? Theme.spacingXs : Theme.barIslandPadH) * 2
    radius: Theme.barIslandRadius
    color: bare ? Theme.transparent : Theme.glassBg
    border.width: bare ? 0 : 1
    border.color: Theme.glassBorder
    Behavior on height { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
    Behavior on opacity { NumberAnimation { duration: Theme.durStd } }

    // inner top highlight, white 6 %
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, parent.radius - 1)
        visible: !root.bare
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassHighlight }
            GradientStop { position: 0.5; color: Theme.transparent }
        }
    }

    Row {
        id: row
        x: root.minimal ? Theme.spacingXs : Theme.barIslandPadH
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXs

        ContextChips {
            id: chips
            visible: !root.minimal
            anchors.verticalCenter: parent.verticalCenter
            // room left once the always-present capsules are placed (measured separately: no feedback loop)
            available: root.maxWidth > 0 ? root.maxWidth - Theme.barIslandPadH * 2 - staticRow.implicitWidth - row.spacing : 10000
            onChipClicked: (key, chip) => root.chipAction(key, chip)
        }

        Row {
            id: staticRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXs

            // ---- meters: CPU ring · RAM ring · network line ----
            MeterCapsule {
                island: root
                visible: root.metrics
                tip: `CPU ${SysStats.cpuPct} %${SysStats.tempC >= 0 ? ` · ${SysStats.tempC} °` : ""}`
                RingMeter { anchors.verticalCenter: parent.verticalCenter; value: SysStats.cpuPct / 100; color: Theme.cyan }
            }
            MeterCapsule {
                island: root
                visible: root.metrics
                tip: `RAM ${SysStats.memUsedGb.toFixed(1)} / ${Math.round(SysStats.memTotalGb)} G`
                RingMeter { anchors.verticalCenter: parent.verticalCenter; value: SysStats.memPct / 100; color: Theme.lavender }
            }
            MeterCapsule {
                island: root
                visible: root.metrics
                tip: `↓ ${SysStats.formatRate(SysStats.rxRate)} · ↑ ${SysStats.formatRate(SysStats.txRate)}`
                Sparkline { anchors.verticalCenter: parent.verticalCenter; samples: SysStats.rxHistory; color: Theme.cyan }
            }

            Rectangle {
                visible: root.metrics
                width: 1
                height: Theme.barHeight - 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.divider
            }

            // Keyboard layout ("US" / "LA"): click = next layout
            Capsule {
                id: kbCap
                visible: Keyboard.code.length > 0 && !root.minimal
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                padH: Theme.spacingSm - 2
                onClicked: Keyboard.next()
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Keyboard.code
                    mono: true
                    size: Theme.sizeCaption + 1
                    weight: Theme.weightSemiBold
                    color: Theme.textSoft
                }
            }

            // Tiling mode of the focused workspace: dwindle ↔ scrolling (click or SUPER + T)
            Capsule {
                id: tilingCap
                visible: !root.minimal
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                padH: Theme.spacingSm - 2
                onClicked: Tiling.toggle()
                CoreIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Tiling.scrolling ? "columns" : "grid"
                    size: Theme.iconSm
                    color: Tiling.scrolling ? Theme.cyan : Theme.textSoft
                }
                BarTooltip {
                    target: tilingCap
                    shown: tilingCap.hovered
                    delay: 450
                    text: `${Tiling.scrolling ? "Scrolling" : "Dwindle"} · clic o ${Tiling.shortcut} para alternar`
                }
            }

            Capsule {
                id: wifiCap
                visible: !root.minimal
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                padH: Theme.spacingSm - 2
                active: root.bar.isOpen("wifi")
                onClicked: root.openPopover("wifi", wifiCap)
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.iconSm
                    icon: Network.wiredConnected && !Network.wifiConnected ? Icons.ethernet
                          : Icons.wifiFor(Network.signalStrength, Network.wifiEnabled && Network.hasWifi)
                    color: Network.connected ? Theme.textSoft : Theme.muted
                }
            }

            Capsule {
                id: btCap
                visible: Bluetooth.adapterAvailable && !root.minimal
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                padH: Theme.spacingSm - 2
                active: root.bar.isOpen("bt")
                onClicked: root.openPopover("bt", btCap)
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.iconSm
                    icon: !Bluetooth.enabled ? Icons.btOff : (Bluetooth.connectedDevices.length > 0 ? Icons.btConnected : Icons.bluetooth)
                    color: Bluetooth.connectedDevices.length > 0 ? Theme.cyan : (Bluetooth.enabled ? Theme.textSoft : Theme.muted)
                }
            }

            // Volume: icon + 30×4 bar. Wheel ±5 %, click = mute, right click = Sonido popover
            Capsule {
                id: volCap
                visible: !root.minimal
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                padH: Theme.spacingSm - 2
                active: root.bar.isOpen("audio")
                onClicked: m => {
                    if (m.button === Qt.RightButton) root.openPopover("audio", volCap);
                    else Audio.toggleMute();
                }
                onWheel: d => Audio.setVolume(Audio.volume + (d > 0 ? 0.05 : -0.05))
                Item {
                    width: Theme.iconSm
                    height: Theme.barCapsuleHeight
                    anchors.verticalCenter: parent.verticalCenter
                    Glyph {
                        anchors.centerIn: parent
                        size: Theme.iconSm
                        icon: Icons.volumeFor(Audio.volume, Audio.muted)
                        color: Audio.muted ? Theme.muted : Theme.textSoft
                    }
                    // microphone in use: an orange dot here (the apps are listed in the Sonido popover)
                    Rectangle {
                        id: micDot
                        visible: Privacy.mic
                        width: Theme.pillDot + 1
                        height: width
                        radius: width / 2
                        color: Theme.warn
                        x: parent.width - width / 2
                        y: parent.height / 2 - Theme.iconSm / 2 - 1
                        SequentialAnimation on opacity {
                            running: micDot.visible && Theme.animationsEnabled
                            loops: Animation.Infinite
                            onStopped: micDot.opacity = 1
                            NumberAnimation { to: 0.45; duration: Theme.ms(900); easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: Theme.ms(900); easing.type: Easing.InOutSine }
                        }
                    }
                }
                Item {
                    width: 30
                    height: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { anchors.fill: parent; radius: 2; color: Qt.rgba(1, 1, 1, 0.13) }
                    Rectangle {
                        width: parent.width * (Audio.muted ? 0 : Math.min(1, Audio.volume))
                        height: parent.height
                        radius: 2
                        color: Theme.textSoft
                        Behavior on width { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
                    }
                }
                BarTooltip { target: volCap; shown: volCap.hovered; text: Audio.muted ? "Silenciado" : `Volumen ${Audio.volumePct} %` }
            }

            Capsule {
                id: batCap
                visible: Power.hasBattery && !root.minimal
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                padH: Theme.spacingSm - 2
                active: root.bar.isOpen("battery")
                onClicked: root.openPopover("battery", batCap)
                // wheel on the battery = screen brightness (the bar has no brightness capsule)
                onWheel: d => Brightness.setLevelFor(root.bar.screenName, Brightness.levelFor(root.bar.screenName) + (d > 0 ? 0.05 : -0.05))
                readonly property color tone: Power.isCharging ? Theme.ok
                                             : (Power.batteryPct <= 10 ? Theme.error : (Power.isLow ? Theme.warn : Theme.textSoft))
                readonly property bool critical: !Power.isCharging && Power.batteryPct < 15
                Glyph {
                    id: batGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.iconSm
                    icon: Icons.batteryFor(Power.batteryPct, Power.isCharging)
                    color: batCap.tone
                    // charging: a slow breathing glow · below 15 %: a faster warning pulse
                    SequentialAnimation on opacity {
                        running: (Power.isCharging || batCap.critical) && Theme.animationsEnabled
                        loops: Animation.Infinite
                        onStopped: batGlyph.opacity = 1
                        NumberAnimation { to: batCap.critical ? 0.3 : 0.55; duration: Theme.ms(batCap.critical ? 450 : 1100); easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: Theme.ms(batCap.critical ? 450 : 1100); easing.type: Easing.InOutSine }
                    }
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Power.batteryPct}`
                    mono: true
                    size: Theme.sizeCaption + 1
                    color: batCap.tone
                }
            }

            // ---- orbital clock ----
            Capsule {
                id: clockCap
                anchors.verticalCenter: parent.verticalCenter
                brand: true
                radius: height / 2
                padH: Theme.spacingSm
                active: root.bar.isOpen("calendar")
                onClicked: m => {
                    if (m.button === Qt.RightButton) Notifs.toggleDnd();
                    else root.openPopover("calendar", clockCap);
                }

                // markers: No molestar (muted) · unread (warn) · updates (cyan), tiny dots that grow in / out
                component Marker: Rectangle {
                    property bool shown: false
                    anchors.verticalCenter: parent.verticalCenter
                    width: shown ? 4 : 0
                    height: 4
                    radius: 2
                    opacity: shown ? 1 : 0
                    visible: width > 0.5
                    Behavior on width { NumberAnimation { duration: Theme.durStd } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durStd } }
                }
                Marker { shown: Notifs.dnd; color: Theme.muted }
                Marker { shown: Notifs.hasUnread && !Notifs.dnd; color: Theme.warn }
                Marker { shown: Updates.count > 0; color: Theme.cyan }

                // 14 px ring, lavender 40 %, with a 4 px cyan dot going round once a minute
                Item {
                    id: orbit
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.transparent
                        border.width: 1
                        border.color: Theme.alpha(Theme.lavender, 0.4)
                    }
                    Item {
                        anchors.fill: parent
                        rotation: Clock.seconds * 6
                        Behavior on rotation {
                            enabled: Theme.animationsEnabled
                            RotationAnimation { duration: 1000; direction: RotationAnimation.Clockwise }
                        }
                        Rectangle {
                            x: parent.width / 2 - width / 2
                            y: -width / 2 + 0.5
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.cyan
                        }
                    }
                }
                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clock.time
                    mono: true
                    size: 12
                    weight: Theme.weightSemiBold
                    color: Theme.text
                }
                BarTooltip { target: clockCap; shown: clockCap.hovered && !clockCap.active; text: Clock.dateFormatted }
            }
        }
    }
}
