// 2×3 toggle grid: Wi-Fi, Bluetooth, No molestar, Luz nocturna, Captura, Grabar
// Right click on Wi-Fi / Bluetooth opens their popover.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

GridLayout {
    id: root
    property string screenName: ""

    columns: 2
    columnSpacing: Theme.spacingSm + Theme.spacingXs / 2
    rowSpacing: Theme.spacingSm + Theme.spacingXs / 2

    function fmt(secs: int): string {
        return `${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, "0")}`;
    }

    ToggleTile {
        Layout.fillWidth: true
        icon: Icons.wifiFor(Network.signalStrength, Toggles.wifi)
        label: "Wi‑Fi"
        sublabel: !Toggles.wifiAvailable ? "Sin adaptador" : (!Toggles.wifi ? "Apagado" : (Network.wifiConnected ? Network.ssid : "Sin conexión"))
        checked: Toggles.wifi && Toggles.wifiAvailable
        enabled: Toggles.wifiAvailable && Network.wifiHardwareEnabled
        onClicked: Toggles.toggleWifi()
        onSecondaryClicked: ShellState.open("wifi", root.screenName)
    }
    ToggleTile {
        Layout.fillWidth: true
        icon: Toggles.bluetooth ? Icons.bluetooth : Icons.btOff
        label: "Bluetooth"
        sublabel: !Toggles.bluetoothAvailable ? "Sin adaptador"
                : (!Toggles.bluetooth ? "Apagado" : (Bluetooth.connectedDeviceName || "Encendido"))
        checked: Toggles.bluetooth
        enabled: Toggles.bluetoothAvailable
        onClicked: Toggles.toggleBluetooth()
        onSecondaryClicked: ShellState.open("bt", root.screenName)
    }
    ToggleTile {
        Layout.fillWidth: true
        icon: Toggles.dnd ? Icons.bellOff : Icons.bell
        label: "No molestar"
        sublabel: Toggles.dnd ? "Activado" : "Desactivado"
        checked: Toggles.dnd
        onClicked: Toggles.toggleDnd()
        onSecondaryClicked: ShellState.open("notifications", root.screenName)
    }
    ToggleTile {
        Layout.fillWidth: true
        icon: Icons.nightLight
        label: "Luz nocturna"
        sublabel: Toggles.nightLight ? "4500 K" : "Apagada"
        checked: Toggles.nightLight
        onClicked: Toggles.toggleNightLight()
    }
    ToggleTile {
        Layout.fillWidth: true
        icon: Icons.camera
        label: "Captura"
        sublabel: "Región"
        onClicked: { ShellState.close(); Toggles.triggerScreenshot(); }
    }
    ToggleTile {
        Layout.fillWidth: true
        icon: Icons.record
        label: "Grabar"
        sublabel: Toggles.isRecording ? root.fmt(Toggles.recordingSeconds) : "Pantalla"
        checked: Toggles.isRecording
        onClicked: {
            if (!Toggles.isRecording) ShellState.close();
            Toggles.toggleRecording();
        }
    }
}
