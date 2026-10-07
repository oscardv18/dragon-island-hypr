// Quick toggles row: Wi‑Fi, Bluetooth, No molestar, Luz nocturna. Right click on Wi‑Fi / Bluetooth /
// No molestar opens the related popover.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

RowLayout {
    id: root

    property string screenName: ""

    spacing: Theme.spacingSm

    component Tile: Item {
        id: tile
        property string icon: ""
        property string label: ""
        property bool checked: false
        readonly property bool hovered: mouse.containsMouse
        signal clicked()
        signal secondaryClicked()

        Layout.fillWidth: true
        Layout.preferredHeight: Theme.notchTile
        opacity: enabled ? 1 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: Theme.tileRadius - 4
            visible: !tile.checked
            color: tile.hovered ? Theme.surfaceHi : Theme.surface2
            Behavior on color { ColorAnimation { duration: Theme.durHover } }
        }
        BrandFill {
            anchors.fill: parent
            radius: Theme.tileRadius - 4
            visible: tile.checked
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.tileRadius - 4
            visible: tile.checked
            color: Theme.hoverOverlay
            opacity: tile.hovered ? 1 : 0
        }
        Column {
            anchors.centerIn: parent
            spacing: 1
            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: tile.icon
                size: Theme.iconMd
                color: tile.checked ? Theme.onBrand : Theme.textSoft
            }
            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, tile.width - Theme.spacingXs * 2)
                text: tile.label
                size: Theme.sizeCaption - 1
                color: tile.checked ? Theme.onBrand : Theme.textDim
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: tile.enabled
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? tile.secondaryClicked() : tile.clicked()
        }
    }

    Tile {
        icon: Icons.wifiFor(Network.signalStrength, Toggles.wifi)
        label: "Wi‑Fi"
        checked: Toggles.wifi && Toggles.wifiAvailable
        enabled: Toggles.wifiAvailable && Network.wifiHardwareEnabled
        onClicked: Toggles.toggleWifi()
        onSecondaryClicked: ShellState.open("wifi", root.screenName)
    }
    Tile {
        icon: Toggles.bluetooth ? Icons.bluetooth : Icons.btOff
        label: "Bluetooth"
        checked: Toggles.bluetooth
        enabled: Toggles.bluetoothAvailable
        onClicked: Toggles.toggleBluetooth()
        onSecondaryClicked: ShellState.open("bt", root.screenName)
    }
    Tile {
        icon: Toggles.dnd ? Icons.bellOff : Icons.bell
        label: "No molestar"
        checked: Toggles.dnd
        onClicked: Toggles.toggleDnd()
        onSecondaryClicked: ShellState.open("notifications", root.screenName)
    }
    Tile {
        icon: Icons.nightLight
        label: "Luz nocturna"
        checked: Toggles.nightLight
        onClicked: Toggles.toggleNightLight()
    }
}
