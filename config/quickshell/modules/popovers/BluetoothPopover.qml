// Bluetooth: switch · connected device card with battery · paired list · "Buscar dispositivos"
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Bluetooth"

    onClosed: Bluetooth.stopDiscovery()

    headerRight: ToggleSwitch {
        checked: Bluetooth.enabled
        enabled: Bluetooth.adapterAvailable && !Bluetooth.blocked
        onToggled: Bluetooth.togglePower()
    }

    function deviceIcon(d): string {
        return (d?.icon ?? "").indexOf("audio") >= 0 ? Icons.headphones : Icons.bluetooth;
    }

    UiText {
        visible: !Bluetooth.adapterAvailable
        Layout.fillWidth: true
        text: "No se encontró ningún adaptador Bluetooth"
        color: Theme.textDim
    }
    UiText {
        visible: Bluetooth.adapterAvailable && !Bluetooth.enabled
        Layout.fillWidth: true
        text: Bluetooth.blocked ? "Bluetooth bloqueado (rfkill)" : "Bluetooth apagado"
        color: Theme.textDim
    }

    // connected device
    Card {
        visible: Bluetooth.enabled && Bluetooth.primaryConnectedDevice !== null
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm + 2
            Glyph { icon: root.deviceIcon(Bluetooth.primaryConnectedDevice); size: Theme.iconLg + Theme.spacingXs; color: Theme.cyan }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                UiText { Layout.fillWidth: true; text: Bluetooth.connectedDeviceName; weight: Theme.weightSemiBold }
                UiText {
                    text: Bluetooth.hasBattery ? `Batería ${Bluetooth.connectedBatteryPct}%` : "Conectado"
                    size: Theme.sizeCaption + 1
                    color: Theme.textDim
                }
            }
            IconButton {
                icon: Icons.close
                size: Theme.capsuleHeight + Theme.spacingXs
                iconSize: Theme.iconSm
                onClicked: Bluetooth.disconnectDevice(Bluetooth.primaryConnectedDevice)
            }
        }
        ProgressBar {
            visible: Bluetooth.hasBattery
            Layout.fillWidth: true
            value: Bluetooth.connectedBattery
            color: Bluetooth.connectedBatteryPct <= 20 ? Theme.warn : Theme.ok
        }
    }

    // paired devices
    ColumnLayout {
        visible: Bluetooth.enabled
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2

        UiText { caption: true; text: "Dispositivos vinculados" }
        UiText {
            visible: Bluetooth.pairedDevices.length === 0
            text: "Ninguno todavía"
            color: Theme.textDim
        }
        Repeater {
            model: Bluetooth.pairedDevices
            delegate: ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: root.deviceIcon(modelData)
                title: modelData.name || modelData.address
                active: modelData.connected
                subtitle: Bluetooth.isBusy(modelData) ? "Conectando…"
                        : (modelData.connected ? (Bluetooth.batteryPct(modelData) >= 0 ? `Conectado · ${Bluetooth.batteryPct(modelData)}%` : "Conectado") : "Desconectado")
                onClicked: Bluetooth.toggleConnection(modelData)
            }
        }
    }

    // discovery
    ColumnLayout {
        visible: Bluetooth.enabled && Bluetooth.discovering
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2

        UiText { caption: true; text: "Cerca" }
        UiText {
            visible: Bluetooth.availableDevices.length === 0
            text: "Buscando…"
            color: Theme.textDim
        }
        Repeater {
            model: Bluetooth.availableDevices
            delegate: ListRow {
                required property var modelData
                Layout.fillWidth: true
                icon: root.deviceIcon(modelData)
                title: modelData.name
                subtitle: modelData.pairing ? "Vinculando…" : "Pulsa para vincular"
                onClicked: Bluetooth.pairDevice(modelData)
            }
        }
    }

    ListRow {
        visible: Bluetooth.enabled
        Layout.fillWidth: true
        icon: Icons.refresh
        title: Bluetooth.discovering ? "Detener búsqueda" : "Buscar dispositivos"
        onClicked: Bluetooth.toggleDiscovery()
    }
}
