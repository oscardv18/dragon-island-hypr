// Wi‑Fi · Red (docs/design/29-paneles-wifi.png): switch · current network (band, security, link speed, signal by
// segments, IP, gateway, DNS, live download / upload with a small chart) and its actions (QR when qrencode is installed,
// forget, disconnect) · VPN (state, last server, connect) · nearby networks (signal, band, security; the password is
// asked inline) · hidden network · hotspot. Everything goes through services/Network.qml and services/Vpn.qml.
import QtQuick
import Quickshell
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Wi‑Fi · Red"

    property var selected: null     // secured network waiting for a password
    property bool hiddenForm: false

    onOpened: { Network.setScanning(true); Network.refreshDetails(); }
    onClosed: { Network.setScanning(false); root.selected = null; root.hiddenForm = false; pass.text = ""; Network.clearQr(); }

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
    UiText { visible: !Network.available; Layout.fillWidth: true; text: "NetworkManager no está en ejecución"; color: Theme.textDim }
    UiText { visible: Network.available && !Network.hasWifi; Layout.fillWidth: true; text: "No hay adaptador Wi‑Fi"; color: Theme.textDim }
    UiText { visible: Network.hasWifi && !Network.wifiHardwareEnabled; Layout.fillWidth: true; text: "Wi‑Fi bloqueado por el interruptor de hardware"; color: Theme.warn }

    // ---- current network ----
    HudCard {
        visible: Network.connected
        spacing: Theme.spacingMd

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd
            Rectangle {
                width: 36; height: 36; radius: 18
                color: Theme.alpha(Theme.cyan, 0.10)
                border.width: 1
                border.color: Theme.alpha(Theme.cyan, 0.4)
                Glyph { anchors.centerIn: parent; icon: Network.wifiConnected ? Icons.wifiFor(Network.signalStrength, true) : Icons.ethernet; size: Theme.iconMd; color: Theme.cyan }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                UiText { Layout.fillWidth: true; text: Network.ssid; size: Theme.sizeBodyLg; weight: Theme.weightSemiBold }
                HudCaption {
                    Layout.fillWidth: true
                    color: Theme.ok
                    text: ["Conectada", Network.band, Network.security, Network.linkSpeed].filter(s => s.length > 0).join(" · ")
                }
            }
            SignalBars { visible: Network.wifiConnected; value: Network.signalStrength; barHeight: 14 }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Theme.spacingMd
            rowSpacing: 1
            HudCaption { text: "IP" }
            HudCaption { text: "Puerta" }
            HudCaption { text: "DNS" }
            UiText { text: (Network.ipAddress.split("/")[0]) || "—"; mono: true; size: Theme.sizeCaption + 1 }
            UiText { text: Network.gateway || "—"; mono: true; size: Theme.sizeCaption + 1 }
            UiText { text: Network.dns || "—"; mono: true; size: Theme.sizeCaption + 1 }
        }

        // live traffic: ↓ rate · chart · ↑ rate
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            UiText { text: `↓ ${SysStats.formatRate(SysStats.rxRate)}`; mono: true; size: Theme.sizeCaption + 1; color: Theme.cyan }
            AreaChart { Layout.fillWidth: true; Layout.preferredHeight: 16; samples: SysStats.rxHistory; max: 0; fill: root.filled; lineWidth: 1.2 }
            UiText { text: `↑ ${SysStats.formatRate(SysStats.txRate)}`; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingXs + 2
            HudChip { visible: Network.wifiConnected && Network.qrAvailable; label: Network.qrPath ? "Ocultar QR" : "Compartir con QR"; icon: Icons.qrcode; active: Network.qrPath.length > 0
                onClicked: Network.qrPath ? Network.clearQr() : Network.shareQr() }
            HudChip { label: "Ajustes de red"; onClicked: { ShellState.close(); Network.openSettings(); } }
            HudChip { visible: Network.wifiConnected; label: "Olvidar"; tone: Theme.warn; onClicked: Network.forget(Network.connectedWifiNetwork) }
            HudChip { label: "Desconectar"; onClicked: Network.disconnect() }
        }

        // the QR code of the network (qrencode, WIFI:T:…;S:…;P:…;;)
        Image {
            visible: Network.qrPath.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 150
            Layout.preferredHeight: 150
            source: Network.qrPath ? `file://${Network.qrPath}` : ""
            cache: false
            smooth: false
            fillMode: Image.PreserveAspectFit
        }
        UiText { visible: Network.qrError.length > 0; text: Network.qrError; color: Theme.warn; size: Theme.sizeCaption + 1 }
    }

    // ---- VPN ----
    HudCard {
        visible: Vpn.active || Vpn.lastName.length > 0
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd
            Glyph { icon: Icons.shield; size: Theme.iconMd; color: Vpn.active ? Theme.ok : Theme.textSoft }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                UiText { Layout.fillWidth: true; text: Vpn.provider ? `VPN · ${Vpn.provider}` : "VPN"; weight: Theme.weightSemiBold }
                HudCaption {
                    Layout.fillWidth: true
                    color: Vpn.active ? Theme.ok : Theme.textDim
                    text: Vpn.active ? `Conectada · ${Vpn.server}` : `Desconectada${Vpn.server ? ` · última: ${Vpn.server}` : ""}`
                }
            }
            HudChip { label: Vpn.active ? "Desconectar" : "Conectar"; onClicked: Vpn.active ? Vpn.disconnect() : Vpn.connectLast() }
        }
    }

    // ---- nearby networks ----
    RowLayout {
        visible: Network.hasWifi && Network.wifiEnabled
        Layout.fillWidth: true
        HudCaption { Layout.fillWidth: true; text: `Redes · ${listView.count}` }
        Row {
            visible: Network.scanning
            spacing: Theme.spacingXs
            Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.cyan; anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity { running: Network.scanning && Theme.animationsEnabled && !Settings.calmMotion && root.shown; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: Theme.ms(600) } NumberAnimation { to: 1; duration: Theme.ms(600) } } }
            HudCaption { text: "buscando"; color: Theme.cyan }
        }
    }

    UiText {
        visible: Network.hasWifi && Network.wifiEnabled && listView.count === 0
        text: Network.scanning ? "Buscando redes…" : "No se encontraron redes"
        color: Theme.textDim
    }

    ListView {
        id: listView
        visible: Network.hasWifi && Network.wifiEnabled && count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, (Theme.hudRow + Theme.hudRowGap) * 5)
        clip: true
        spacing: Theme.hudRowGap
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: Network.wifiNetworks.filter(n => !n.connected)
            comparisonMode: ObjectComparison.Identity
        }
        delegate: HudRow {
            required property var modelData
            width: ListView.view.width
            title: modelData.name
            selected: root.selected === modelData
            leading: SignalBars { value: modelData.signalStrength; color: Theme.textSoft; barHeight: 11 }
            HudCaption { text: modelData.stateChanging ? "conectando…" : Network.bandOf(modelData); width: 54; horizontalAlignment: Text.AlignRight }
            HudCaption { text: Network.securityLabel(modelData) || "Abierta"; width: 54; horizontalAlignment: Text.AlignRight }
            onClicked: {
                if (Network.isSecure(modelData) && !modelData.known) {
                    root.hiddenForm = false;
                    root.selected = modelData;
                    pass.text = "";
                    pass.focusInput();
                } else {
                    Network.connectToWifi(modelData, "");
                }
            }
        }
    }

    // password inline (a nearby secured network, or the hidden network form)
    ColumnLayout {
        visible: root.selected !== null || root.hiddenForm
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2
        HudCaption {
            Layout.fillWidth: true
            text: root.hiddenForm ? "Red oculta" : `Contraseña para «${root.selected?.name ?? ""}»`
            color: Network.lastError.length > 0 ? Theme.warn : Theme.textDim
        }
        InputField {
            id: hiddenSsid
            visible: root.hiddenForm
            Layout.fillWidth: true
            placeholder: "Nombre de la red (SSID)"
            icon: Icons.wifiFor(1, true)
            onEscapePressed: root.hiddenForm = false
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            InputField {
                id: pass
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholder: root.hiddenForm ? "Contraseña (vacía si es abierta)" : "Contraseña"
                icon: Icons.lock
                onAccepted: connectBtn.clicked()
                onEscapePressed: { root.selected = null; root.hiddenForm = false; }
            }
            HudChip {
                id: connectBtn
                label: "Conectar"
                active: true
                enabled: root.hiddenForm ? hiddenSsid.text.length > 0 : pass.text.length >= 8
                onClicked: {
                    if (root.hiddenForm) Network.connectHidden(hiddenSsid.text, pass.text);
                    else Network.connectToWifi(root.selected, pass.text);
                    root.selected = null;
                    root.hiddenForm = false;
                    pass.text = "";
                    hiddenSsid.text = "";
                }
            }
        }
    }

    HudRow {
        visible: Network.hasWifi && Network.wifiEnabled && !root.hiddenForm
        title: "+ Conectar a red oculta…"
        titleColor: Theme.textSoft
        onClicked: { root.selected = null; root.hiddenForm = true; hiddenSsid.focusInput(); }
    }

    // ---- hotspot ----
    RowLayout {
        visible: Network.hasWifi
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.hudRow
        spacing: Theme.spacingSm
        UiText { text: "Punto de acceso"; weight: Theme.weightMedium }
        HudCaption { Layout.fillWidth: true; text: Network.hotspotActive ? `· ${Network.hotspotName}` : "· compartir conexión" }
        ToggleSwitch { checked: Network.hotspotActive; onToggled: Network.setHotspot(!Network.hotspotActive) }
    }
}
