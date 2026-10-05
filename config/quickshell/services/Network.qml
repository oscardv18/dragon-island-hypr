// =============================================================================
// dragon-island — Network.qml
// Service: NetworkManager & Wi-Fi Management
// =============================================================================
/**
 * Properties:
 *   - wifiEnabled: bool
 *   - connected: bool [readonly]
 *   - hasWifi: bool [readonly]
 *   - hasEthernet: bool [readonly]
 *   - ssid: string [readonly]
 *   - signalStrength: real [readonly] (0.0 - 1.0)
 *   - signalPct: int [readonly] (0 - 100)
 *   - connectivity: NetworkConnectivity [readonly]
 *   - connectivityString: string [readonly]
 *   - wifiNetworks: list<WifiNetwork> [readonly]
 *
 * Functions:
 *   - toggleWifi(): void
 *   - setWifiEnabled(enabled: bool): void
 *   - checkConnectivity(): void
 *   - connectToWifi(network: WifiNetwork, psk: string): void
 *   - disconnect(): void
 *
 * Signals:
 *   - connectionChanged(connected: bool, ssid: string)
 */
pragma Singleton
import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    // Wi-Fi device lookup
    readonly property WifiDevice wifiDevice: {
        return Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null;
    }

    // Wired device lookup
    readonly property WiredDevice wiredDevice: {
        return Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null;
    }

    readonly property bool hasWifi: wifiDevice !== null
    readonly property bool hasEthernet: wiredDevice !== null

    // Wi-Fi rfkill power switch
    property bool wifiEnabled: Networking.wifiEnabled
    onWifiEnabledChanged: {
        if (Networking.wifiEnabled !== root.wifiEnabled) {
            Networking.wifiEnabled = root.wifiEnabled;
        }
    }

    // Connected network details
    readonly property WifiNetwork connectedWifiNetwork: {
        if (!wifiDevice) return null;
        return wifiDevice.networks.values.find(n => n.connected) ?? null;
    }

    readonly property bool connected: (wiredDevice?.connected ?? false) || (connectedWifiNetwork !== null)
    readonly property string ssid: connectedWifiNetwork?.name || (wiredDevice?.connected ? "Cable Ethernet" : "Desconectado")
    readonly property real signalStrength: connectedWifiNetwork?.signalStrength ?? 0.0
    readonly property int signalPct: Math.round(signalStrength * 100)

    readonly property NetworkConnectivity connectivity: Networking.connectivity
    readonly property string connectivityString: {
        switch (Networking.connectivity) {
            case NetworkConnectivity.Full: return "Acceso a Internet";
            case NetworkConnectivity.Limited: return "Conectividad limitada";
            case NetworkConnectivity.Portal: return "Portal cautivo detectado";
            case NetworkConnectivity.None: return "Sin conexión";
            default: return "Comprobando...";
        }
    }

    // Available scan list
    readonly property var wifiNetworks: {
        if (!wifiDevice) return [];
        return wifiDevice.networks.values;
    }

    function toggleWifi(): void {
        root.wifiEnabled = !root.wifiEnabled;
    }

    function setWifiEnabled(enabled: bool): void {
        root.wifiEnabled = enabled;
    }

    function checkConnectivity(): void {
        Networking.checkConnectivity();
    }

    function connectToWifi(network: WifiNetwork, psk: string): void {
        if (!network) return;
        if (psk && psk.length > 0) {
            network.connectWithPsk(psk);
        } else {
            network.connect();
        }
    }

    function disconnect(): void {
        wifiDevice?.disconnect();
        wiredDevice?.disconnect();
    }

    signal connectionChanged(connected: bool, ssid: string)
    onConnectedChanged: root.connectionChanged(root.connected, root.ssid)
}
