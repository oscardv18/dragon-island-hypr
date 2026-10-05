// Wi-Fi: switch · current network card (band, speed, IP) · networks with signal + security · settings
import QtQuick
import Quickshell
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Wi‑Fi"

    property var selected: null     // secured network waiting for a password

    onOpened: { Network.setScanning(true); Network.refreshDetails(); }
    onClosed: { Network.setScanning(false); root.selected = null; pass.text = ""; }

    Connections {
        target: Network
        function onNeedsPasswordChanged() {
            if (Network.needsPassword && Network.pendingNetwork) root.selected = Network.pendingNetwork;
        }
    }

    headerRight: ToggleSwitch {
        checked: Network.wifiEnabled
        enabled: Network.hasWifi && Network.wifiHardwareEnabled
        onToggled: Network.toggleWifi()
    }

    // ---- states without a list ----
    UiText {
        visible: !Network.available
        Layout.fillWidth: true
        text: "NetworkManager no está en ejecución"
        color: Theme.textDim
    }
    UiText {
        visible: Network.available && !Network.hasWifi
        Layout.fillWidth: true
        text: "No hay adaptador Wi‑Fi"
        color: Theme.textDim
    }
    UiText {
        visible: Network.hasWifi && !Network.wifiHardwareEnabled
        Layout.fillWidth: true
        text: "Wi‑Fi bloqueado por el interruptor de hardware"
        color: Theme.warn
    }

    // ---- current connection ----
    Card {
        visible: Network.connected
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm + 2
            Glyph {
                icon: Network.wifiConnected ? Icons.wifiFor(Network.signalStrength, true) : Icons.ethernet
                size: Theme.iconLg + Theme.spacingXs
                color: Theme.accent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                UiText { Layout.fillWidth: true; text: Network.ssid; weight: Theme.weightSemiBold }
                UiText {
                    Layout.fillWidth: true
                    text: [Network.band, Network.linkSpeed, Network.connectivityString].filter(s => s.length > 0).join(" · ")
                    size: Theme.sizeCaption + 1
                    color: Theme.textDim
                }
                UiText {
                    visible: Network.ipAddress.length > 0
                    text: `IP ${Network.ipAddress}`
                    mono: true
                    size: Theme.sizeCaption
                    color: Theme.cyan
                }
            }
            IconButton {
                icon: Icons.close
                size: Theme.capsuleHeight + Theme.spacingXs
                iconSize: Theme.iconSm
                onClicked: Network.disconnect()
            }
        }
    }

    // ---- networks ----
    ColumnLayout {
        visible: Network.hasWifi && Network.wifiEnabled
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        RowLayout {
            Layout.fillWidth: true
            UiText { caption: true; text: "Redes disponibles"; Layout.fillWidth: true }
            Glyph {
                icon: Icons.refresh
                size: Theme.iconSm
                color: Theme.textDim
                RotationAnimation on rotation {
                    running: Network.scanning && Theme.animationsEnabled
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: Theme.ms(1200)
                }
            }
        }

        UiText {
            visible: listView.count === 0
            text: Network.scanning ? "Buscando redes…" : "No se encontraron redes"
            color: Theme.textDim
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Theme.popoverMaxListHeight * 0.75)
            clip: true
            spacing: Theme.spacingXs + 2
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: Network.wifiNetworks.filter(n => !n.connected)
                comparisonMode: ObjectComparison.Identity
            }
            delegate: ListRow {
                required property var modelData
                width: ListView.view.width
                icon: Icons.wifiFor(modelData.signalStrength, true)
                title: modelData.name
                subtitle: [Network.securityLabel(modelData), modelData.known ? "Guardada" : "",
                           modelData.stateChanging ? "Conectando…" : ""].filter(s => s.length > 0).join(" · ")
                Glyph {
                    visible: Network.isSecure(modelData)
                    icon: Icons.lock
                    size: Theme.iconSm
                    color: Theme.textDim
                }
                onClicked: {
                    if (Network.isSecure(modelData) && !modelData.known) {
                        root.selected = modelData;
                        pass.text = "";
                        pass.focusInput();
                    } else {
                        Network.connectToWifi(modelData, "");
                    }
                }
            }
        }

        // password prompt for the selected secured network
        ColumnLayout {
            visible: root.selected !== null
            Layout.fillWidth: true
            spacing: Theme.spacingXs + 2
            UiText {
                Layout.fillWidth: true
                text: `Contraseña para «${root.selected?.name ?? ""}»`
                size: Theme.sizeCaption + 1
                color: Network.lastError.length > 0 ? Theme.warn : Theme.textSoft
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                InputField {
                    id: pass
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholder: "Contraseña"
                    icon: Icons.lock
                    onAccepted: connectBtn.clicked()
                    onEscapePressed: ShellState.close()
                }
                IconButton {
                    id: connectBtn
                    icon: Icons.check
                    brand: true
                    enabled: pass.text.length >= 8
                    onClicked: {
                        Network.connectToWifi(root.selected, pass.text);
                        root.selected = null;
                        pass.text = "";
                    }
                }
            }
        }
    }

    ListRow {
        Layout.fillWidth: true
        icon: Icons.cog
        title: "Configuración de red…"
        onClicked: { ShellState.close(); Network.openSettings(); }
    }
}
