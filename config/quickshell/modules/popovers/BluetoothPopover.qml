// Bluetooth (docs/design/29-paneles-bluetooth.png): switch and «Visible como <equipo>» · connected devices with their
// kind, battery by segments, audio profile, «Usar como salida», disconnect and forget · nearby devices while it scans
// (radar indicator), pair / connect. The island says when a device connects or its battery drops under 15 %
// (IslandState ← Bluetooth.deviceConnected / batteryLow).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Bluetooth"

    onOpened: if (Bluetooth.enabled) Bluetooth.startDiscovery()
    onClosed: Bluetooth.stopDiscovery()

    headerRight: ToggleSwitch {
        checked: Bluetooth.enabled
        enabled: Bluetooth.adapterAvailable && !Bluetooth.blocked
        onToggled: Bluetooth.togglePower()
    }

    function icon(d): string {
        switch (Bluetooth.kindOf(d)) {
            case "audio": return Icons.headphones;
            case "mouse": return Icons.mouse;
            case "keyboard": return Icons.keyboard;
            case "phone": return Icons.phone;
            default: return Icons.bluetooth;
        }
    }

    UiText { visible: !Bluetooth.adapterAvailable; Layout.fillWidth: true; text: "No se encontró ningún adaptador Bluetooth"; color: Theme.textDim }
    UiText { visible: Bluetooth.blocked; Layout.fillWidth: true; text: "Bluetooth bloqueado (rfkill)"; color: Theme.warn }

    RowLayout {
        visible: Bluetooth.enabled
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.hudRow - 6
        UiText { text: "Visible como"; color: Theme.textSoft }
        UiText { Layout.fillWidth: true; text: Bluetooth.adapterName; weight: Theme.weightSemiBold }
        ToggleSwitch { checked: Bluetooth.discoverable; onToggled: Bluetooth.setDiscoverable(!Bluetooth.discoverable) }
    }

    // ---- connected ----
    HudCaption { visible: Bluetooth.enabled && Bluetooth.connectedDevices.length > 0; text: `Conectados · ${Bluetooth.connectedDevices.length}` }
    Repeater {
        model: Bluetooth.enabled ? Bluetooth.connectedDevices : []
        delegate: HudCard {
            id: dev
            required property var modelData
            readonly property int battery: Bluetooth.batteryPct(modelData)
            readonly property bool isAudio: Bluetooth.kindOf(modelData) === "audio"
            readonly property var node: Bluetooth.audioNode(modelData)
            readonly property bool activeOut: node !== null && node === Audio.sink
            spacing: Theme.spacingSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMd
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: Theme.hudRowFill
                    border.width: 1
                    border.color: Theme.hudCardEdge
                    Glyph { anchors.centerIn: parent; icon: root.icon(dev.modelData); size: Theme.iconMd; color: Theme.textSoft }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    UiText { Layout.fillWidth: true; text: dev.modelData.name || dev.modelData.address; weight: Theme.weightSemiBold; size: Theme.sizeBodyLg }
                    HudCaption {
                        Layout.fillWidth: true
                        color: dev.isAudio ? Theme.ok : Theme.textDim
                        text: [Bluetooth.kindLabel(dev.modelData), dev.activeOut ? "salida activa" : "",
                               dev.isAudio ? (Bluetooth.profileOf(dev.modelData) === "alta calidad" ? "A2DP" : Bluetooth.profileOf(dev.modelData)) : "",
                               !dev.isAudio && dev.battery >= 0 ? `${dev.battery} %` : ""].filter(x => x.length > 0).join(" · ")
                    }
                }
                HudChip { label: "Desconectar"; onClicked: Bluetooth.disconnectDevice(dev.modelData) }
            }
            ColumnLayout {
                visible: dev.isAudio && dev.battery >= 0
                Layout.fillWidth: true
                spacing: Theme.spacingXs
                RowLayout {
                    Layout.fillWidth: true
                    HudCaption { Layout.fillWidth: true; text: "Batería" }
                    UiText { text: `${dev.battery} %`; mono: true; size: Theme.sizeCaption + 1 }
                }
                SegmentBar { Layout.fillWidth: true; value: dev.battery / 100; color: dev.battery < 15 ? Theme.warn : Theme.ok; fill: root.filled; segments: 20 }
            }
            Flow {
                visible: dev.isAudio
                Layout.fillWidth: true
                spacing: Theme.spacingXs + 2
                HudChip { visible: dev.node !== null; label: dev.activeOut ? "Salida activa" : "Usar como salida"; active: dev.activeOut; onClicked: Bluetooth.useAsOutput(dev.modelData) }
                HudChip { visible: Bluetooth.profileOf(dev.modelData).length > 0; label: `Perfil: ${Bluetooth.profileOf(dev.modelData)}`; onClicked: Bluetooth.toggleProfile(dev.modelData) }
                HudChip { label: "Olvidar"; tone: Theme.warn; onClicked: Bluetooth.forgetDevice(dev.modelData) }
            }
        }
    }

    // ---- paired, not connected ----
    Repeater {
        model: Bluetooth.enabled ? Bluetooth.pairedDevices.filter(d => !d.connected) : []
        delegate: HudRow {
            required property var modelData
            title: modelData.name || modelData.address
            detail: `${Bluetooth.kindLabel(modelData)} · emparejado`
            leading: Glyph { icon: root.icon(modelData); size: Theme.iconMd; color: Theme.textDim }
            HudChip { label: Bluetooth.isBusy(modelData) ? "…" : "Conectar"; enabled: !Bluetooth.isBusy(modelData); onClicked: Bluetooth.connectDevice(modelData) }
            HudChip { label: "Olvidar"; tone: Theme.warn; onClicked: Bluetooth.forgetDevice(modelData) }
            onClicked: Bluetooth.connectDevice(modelData)
        }
    }

    // ---- nearby (while scanning) ----
    RowLayout {
        visible: Bluetooth.enabled
        Layout.fillWidth: true
        HudCaption { Layout.fillWidth: true; text: "Cercanos" }
        Radar { visible: Bluetooth.discovering; running: Bluetooth.discovering && root.shown }
        HudChip {
            label: Bluetooth.discovering ? "Buscando" : "Buscar"
            active: Bluetooth.discovering
            tone: Bluetooth.discovering ? Theme.cyan : Theme.text
            onClicked: Bluetooth.toggleDiscovery()
        }
    }
    UiText {
        visible: Bluetooth.enabled && Bluetooth.availableDevices.length === 0
        text: Bluetooth.discovering ? "Buscando dispositivos…" : "Pulsa «Buscar» para ver dispositivos cercanos"
        color: Theme.textDim
        size: Theme.sizeCaption + 1
    }
    Repeater {
        model: Bluetooth.enabled ? Bluetooth.availableDevices.slice().sort((a, b) => (/^([0-9A-F]{2}[-:]){5}/i.test(a.name) ? 1 : 0) - (/^([0-9A-F]{2}[-:]){5}/i.test(b.name) ? 1 : 0)).slice(0, 6) : []
        delegate: HudRow {
            required property var modelData
            readonly property bool unnamed: !modelData.name || /^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(modelData.name) || /^[0-9A-F]{12,}$/i.test(modelData.name)
            title: unnamed ? "Dispositivo desconocido" : modelData.name
            detail: unnamed ? `sin nombre · ${modelData.address}` : Bluetooth.kindLabel(modelData)
            HudChip { label: Bluetooth.isBusy(modelData) ? "Emparejando…" : "Emparejar"; enabled: !Bluetooth.isBusy(modelData); onClicked: Bluetooth.pairDevice(modelData) }
            onClicked: Bluetooth.pairDevice(modelData)
        }
    }
}
