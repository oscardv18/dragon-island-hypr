// Right island: CPU · RAM · keyboard layout · [Wi-Fi | Bluetooth | volume | battery] · bell · tray · clock
// Each capsule opens its own popover through ShellState (one at a time).
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    required property var bar
    property real windowX: 0     // screen x of this island's window

    // popovers of the right island: right edge on the capsule's right edge
    function openPopover(name: string, item): void { bar.openFrom(name, item, "right", windowX); }

    implicitHeight: Theme.barHeight
    height: Theme.barHeight
    width: row.implicitWidth + Theme.barIslandPadH * 2
    radius: Theme.barIslandRadius
    color: Theme.glassBg
    border.width: 1
    border.color: Theme.glassBorder

    Row {
        id: row
        x: Theme.barIslandPadH
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barIslandGap

        // CPU
        Capsule {
            id: cpuCap
            anchors.verticalCenter: parent.verticalCenter
            active: root.bar.isOpen("perf")
            onClicked: root.openPopover("perf", cpuCap)
            Glyph { shadow: true; icon: Icons.cpu; size: Theme.iconSm; color: Theme.cyan; anchors.verticalCenter: parent.verticalCenter }
            UiText {
                shadow: true
                anchors.verticalCenter: parent.verticalCenter
                text: `${SysStats.cpuPct}%`
                mono: true
                size: Theme.sizeBar
            }
        }

        // RAM
        Capsule {
            id: ramCap
            anchors.verticalCenter: parent.verticalCenter
            active: root.bar.isOpen("perf")
            onClicked: root.openPopover("perf", ramCap)
            Glyph { shadow: true; icon: Icons.memory; size: Theme.iconSm; color: Theme.violetSoft; anchors.verticalCenter: parent.verticalCenter }
            UiText {
                shadow: true
                anchors.verticalCenter: parent.verticalCenter
                text: `${SysStats.memUsedGb.toFixed(1)}G`
                mono: true
                size: Theme.sizeBar
            }
        }

        // Keyboard layout ("US" / "LA"): click = next layout
        Capsule {
            id: kbCap
            visible: Keyboard.code.length > 0
            anchors.verticalCenter: parent.verticalCenter
            padH: Theme.capsulePadH - 2
            onClicked: Keyboard.next()
            UiText {
                shadow: true
                anchors.verticalCenter: parent.verticalCenter
                text: Keyboard.code
                mono: true
                size: Theme.sizeBar
                weight: Theme.weightSemiBold
            }
        }

        // Grouped capsule: each part is its own button
        Rectangle {
            id: group
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.capsuleHeight
            width: groupRow.implicitWidth
            radius: Theme.capsuleRadius
            color: Theme.surface2

            Row {
                id: groupRow
                anchors.verticalCenter: parent.verticalCenter

                Capsule {
                    id: wifiCap
                    flat: true
                    padH: Theme.capsulePadH - 2
                    active: root.bar.isOpen("wifi")
                    onClicked: root.openPopover("wifi", wifiCap)
                    Glyph {
                        shadow: true
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.iconMd
                        icon: Network.wiredConnected && !Network.wifiConnected ? Icons.ethernet
                              : Icons.wifiFor(Network.signalStrength, Network.wifiEnabled && Network.hasWifi)
                        color: Network.connected ? Theme.text : Theme.textDim
                    }
                }

                Capsule {
                    id: btCap
                    visible: Bluetooth.adapterAvailable
                    flat: true
                    padH: Theme.capsulePadH - 2
                    active: root.bar.isOpen("bt")
                    onClicked: root.openPopover("bt", btCap)
                    Glyph {
                        shadow: true
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.iconMd
                        icon: !Bluetooth.enabled ? Icons.btOff : (Bluetooth.connectedDevices.length > 0 ? Icons.btConnected : Icons.bluetooth)
                        color: Bluetooth.connectedDevices.length > 0 ? Theme.cyan : (Bluetooth.enabled ? Theme.text : Theme.textDim)
                    }
                }

                Capsule {
                    id: volCap
                    flat: true
                    padH: Theme.capsulePadH - 2
                    active: root.bar.isOpen("audio")
                    onClicked: m => {
                        if (m.button === Qt.MiddleButton || m.button === Qt.RightButton) Audio.toggleMute();
                        else root.openPopover("audio", volCap);
                    }
                    onWheel: d => Audio.setVolume(Audio.volume + (d > 0 ? 0.05 : -0.05))
                    Glyph {
                        shadow: true
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.iconMd
                        icon: Icons.volumeFor(Audio.volume, Audio.muted)
                        color: Audio.muted ? Theme.textDim : Theme.text
                    }
                    UiText {
                        shadow: true
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Audio.volumePct}`
                        mono: true
                        size: Theme.sizeBar
                        color: Audio.muted ? Theme.textDim : Theme.text
                    }
                }

                Capsule {
                    id: batCap
                    visible: Power.hasBattery
                    flat: true
                    padH: Theme.capsulePadH - 2
                    active: root.bar.isOpen("battery")
                    onClicked: root.openPopover("battery", batCap)
                    readonly property color tone: Power.isCharging ? Theme.ok
                                                 : (Power.batteryPct <= 10 ? Theme.error : (Power.isLow ? Theme.warn : Theme.ok))
                    Glyph {
                        shadow: true
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.iconMd
                        icon: Icons.batteryFor(Power.batteryPct, Power.isCharging)
                        color: batCap.tone
                    }
                    UiText {
                        shadow: true
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Power.batteryPct}%`
                        mono: true
                        size: Theme.sizeBar
                        color: batCap.tone
                    }
                }
            }
        }

        // Notifications bell: dot = unread (accent + glow)
        Capsule {
            id: bellCap
            anchors.verticalCenter: parent.verticalCenter
            padH: Theme.capsulePadH - 2
            active: root.bar.isOpen("notifications")
            onClicked: m => {
                if (m.button === Qt.RightButton) Notifs.toggleDnd();
                else root.openPopover("notifications", bellCap);
            }
            Item {
                width: Theme.iconMd
                height: Theme.capsuleHeight
                Glyph {
                    shadow: true
                    anchors.centerIn: parent
                    size: Theme.iconMd
                    icon: Notifs.dnd ? Icons.bellOff : Icons.bell
                    color: Notifs.dnd ? Theme.textDim : Theme.text
                }
                RectangularShadow {
                    anchors.fill: unreadDot
                    radius: width / 2
                    blur: Theme.glowBlurSmall
                    color: Theme.glowStrong
                    visible: unreadDot.visible
                }
                Rectangle {
                    id: unreadDot
                    visible: Notifs.hasUnread && !Notifs.dnd
                    width: Theme.pillDot + 2
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    x: parent.width - width / 2 - 1
                    y: parent.height / 2 - Theme.iconMd / 2
                }
            }
        }

        // System tray (StatusNotifierItems), between bell and clock. Left = activate (or menu if
        // the item only has one), right = menu (QsMenuAnchor), middle = secondary, wheel = scroll.
        // Hidden when no app exposes an item. Logic lives in services/Tray.qml.
        Rectangle {
            id: tray
            visible: Tray.hasItems
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.capsuleHeight
            width: trayRow.implicitWidth + Theme.spacingXs * 2
            radius: Theme.capsuleRadius
            color: Theme.surface2

            Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: ScriptModel {
                        values: Tray.items
                        comparisonMode: ObjectComparison.Identity
                    }
                    delegate: Item {
                        id: trayItem
                        required property var modelData
                        // Apps swap icons (e.g. VPN connected): retry the primary source each time
                        readonly property string rawIcon: modelData.icon
                        property bool iconFailed: false
                        onRawIconChanged: iconFailed = false
                        width: Theme.capsuleHeight - Theme.spacingXs
                        height: Theme.capsuleHeight - Theme.spacingXs

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.capsuleRadius - 2
                            color: trayMouse.containsMouse || menuAnchor.visible ? Theme.surfaceHi : Theme.transparent
                            Behavior on color { ColorAnimation { duration: Theme.durHover } }
                        }
                        IconImage {
                            anchors.centerIn: parent
                            source: Tray.iconSource(trayItem.modelData, trayItem.iconFailed)
                            implicitSize: Theme.iconMd
                            asynchronous: true
                            onStatusChanged: if (status === Image.Error) trayItem.iconFailed = true
                        }
                        Rectangle {
                            visible: Tray.needsAttention(trayItem.modelData)
                            width: Theme.pillDot
                            height: width
                            radius: width / 2
                            color: Theme.warn
                            anchors.right: parent.right
                            anchors.top: parent.top
                        }

                        // Menu opens below the icon, one popover gap away
                        Item {
                            id: menuSpot
                            y: trayItem.height + Theme.popoverGap
                            width: trayItem.width
                        }
                        QsMenuAnchor {
                            id: menuAnchor
                            menu: trayItem.modelData.menu
                            anchor.item: menuSpot
                        }

                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: m => {
                                if (m.button === Qt.RightButton) Tray.openMenu(menuAnchor);
                                else if (m.button === Qt.MiddleButton) Tray.secondaryActivate(trayItem.modelData);
                                else Tray.click(trayItem.modelData, menuAnchor);
                            }
                            onWheel: w => Tray.scroll(trayItem.modelData, w.angleDelta.x, w.angleDelta.y)
                        }
                    }
                }
            }
        }

        // Clock: brand gradient, "lun 5 oct  16:23"
        Capsule {
            id: clockCap
            anchors.verticalCenter: parent.verticalCenter
            brand: true
            active: root.bar.isOpen("calendar")
            onClicked: root.openPopover("calendar", clockCap)
            UiText {
                shadow: true
                anchors.verticalCenter: parent.verticalCenter
                text: Clock.barText
                mono: true
                size: Theme.sizeBar
                weight: Theme.weightSemiBold
                color: Theme.onBrand
            }
        }
    }
}
