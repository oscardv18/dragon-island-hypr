// =============================================================================
// dragon-island — Network.qml
// Service: NetworkManager (Quickshell.Networking) + nmcli for link details
// =============================================================================
/**
 * Properties:
 *   - available: bool [readonly] (a NetworkManager backend is running)
 *   - wifiEnabled: bool [readonly] (rfkill software switch)
 *   - wifiHardwareEnabled: bool [readonly] (false = hardware kill switch)
 *   - hasWifi / hasEthernet: bool [readonly]
 *   - wiredConnected / wifiConnected / connected: bool [readonly]
 *   - ssid: string [readonly] (Wi-Fi name, "Ethernet" or "Desconectado")
 *   - signalStrength: real [readonly] (0.0 - 1.0)   signalPct: int [readonly]
 *   - connectedWifiNetwork: WifiNetwork [readonly]
 *   - wifiNetworks: list<WifiNetwork> [readonly] (named, deduplicated, strongest first, connected on top)
 *   - scanning: bool [readonly]
 *   - band: string [readonly] ("2.4 GHz" | "5 GHz" | "6 GHz" | "")
 *   - linkSpeed: string [readonly] ("866 Mbit/s" | "")
 *   - ipAddress: string [readonly] ("192.168.1.20/24" | "")
 *   - gateway: string [readonly]   dns: string [readonly] (first DNS server)   (current connection, "" if unknown)
 *   - security: string [readonly] (current Wi‑Fi: "WPA2" · "WPA3" · "Abierta" · …)
 *   - bands: var [readonly] (SSID → "2.4 GHz" | "5 GHz" | "6 GHz", refreshed while scanning; WifiNetwork has no frequency)
 *   - qrAvailable: bool [readonly] (qrencode installed: «Compartir con QR» is offered)
 *   - qrPath: string [readonly] (PNG of the current network's QR code after shareQr(), "" before)
 *   - qrError: string [readonly]
 *   - hotspotActive: bool [readonly] (an NM connection of mode ap is up)   hotspotName: string [readonly]
 *   - connectivity: NetworkConnectivity [readonly]   connectivityString: string [readonly]
 *   - pendingNetwork: WifiNetwork [readonly] (network being connected from the UI)
 *   - needsPassword: bool [readonly] (last attempt failed with NoSecrets → ask for a PSK)
 *   - lastError: string [readonly]
 *
 * Functions:
 *   - toggleWifi(): void           setWifiEnabled(enabled: bool): void
 *   - setScanning(on: bool): void  (enable the scanner while the Wi-Fi popover is open)
 *   - connectToWifi(network: WifiNetwork, psk: string): void
 *   - disconnect(): void
 *   - shareQr(): void (asks NetworkManager for the saved key and renders WIFI:… with qrencode into qrPath)
 *   - clearQr(): void
 *   - connectHidden(ssid: string, psk: string): void (`nmcli device wifi connect … hidden yes`)
 *   - setHotspot(on: bool): void (`nmcli device wifi hotspot` with a generated key; off = `nmcli connection down`)
 *   - bandOf(network: WifiNetwork): string
 *   - forget(network: WifiNetwork): void
 *   - isSecure(network: WifiNetwork): bool
 *   - securityLabel(network: WifiNetwork): string
 *   - refreshDetails(): void
 *   - checkConnectivity(): void
 *   - openSettings(): void         (external network editor)
 *
 * Signals:
 *   - connectionChanged(connected: bool, ssid: string)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    readonly property bool available: Networking.backend !== NetworkBackendType.None

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null

    readonly property bool hasWifi: wifiDevice !== null
    readonly property bool hasEthernet: wiredDevice !== null

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    readonly property var connectedWifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

    readonly property bool wiredConnected: wiredDevice?.connected ?? false
    readonly property bool wifiConnected: connectedWifiNetwork !== null
    readonly property bool connected: wiredConnected || wifiConnected
    readonly property string ssid: connectedWifiNetwork?.name || (wiredConnected ? "Ethernet" : "Desconectado")
    readonly property real signalStrength: connectedWifiNetwork?.signalStrength ?? 0.0
    readonly property int signalPct: Math.round(signalStrength * 100)

    readonly property var wifiNetworks: {
        if (!wifiDevice) return [];
        const best = {};
        for (const n of wifiDevice.networks.values) {
            if (!n.name) continue;
            const prev = best[n.name];
            if (!prev || n.connected || (!prev.connected && n.signalStrength > prev.signalStrength)) best[n.name] = n;
        }
        return Object.values(best).sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
    }

    readonly property bool scanning: wifiDevice?.scannerEnabled ?? false

    readonly property int connectivity: Networking.connectivity
    readonly property string connectivityString: {
        switch (Networking.connectivity) {
            case NetworkConnectivity.Full:    return "Acceso a Internet";
            case NetworkConnectivity.Limited: return "Conectividad limitada";
            case NetworkConnectivity.Portal:  return "Portal cautivo";
            case NetworkConnectivity.None:    return "Sin conexión";
            default:                          return "Comprobando…";
        }
    }

    // ---- Link details (band / speed / IP are not exposed by Quickshell.Networking) ----
    property string band: ""
    property string linkSpeed: ""
    property string ipAddress: ""
    property string gateway: ""
    property string dns: ""
    readonly property string security: connectedWifiNetwork ? securityLabel(connectedWifiNetwork) : ""

    readonly property string activeIface: wifiConnected ? (wifiDevice?.name ?? "") : (wiredConnected ? (wiredDevice?.name ?? "") : "")

    Process {
        id: detailsProc
        stdout: StdioCollector {
            onStreamFinished: {
                let band = "", speed = "", ip = "", gw = "", dns = "";
                for (const raw of this.text.split("\n")) {
                    const line = raw.trim();
                    if (line.startsWith("IP4.GATEWAY") && !gw) {
                        gw = line.substring(line.indexOf(":") + 1);
                    } else if (line.startsWith("IP4.DNS") && !dns) {
                        dns = line.substring(line.indexOf(":") + 1);
                    } else if (line.startsWith("IP4.ADDRESS") && !ip) {
                        ip = line.substring(line.indexOf(":") + 1);
                    } else if (line.startsWith("*:")) {
                        // IN-USE:FREQ:RATE  e.g. "*:5180 MHz:866 Mbit/s"
                        const parts = line.split(":");
                        const mhz = parseInt(parts[1]);
                        if (!isNaN(mhz)) band = mhz >= 5925 ? "6 GHz" : (mhz >= 4900 ? "5 GHz" : "2.4 GHz");
                        speed = (parts[2] || "").trim();
                    } else if (line.startsWith("SPEED:")) {
                        const mbps = parseInt(line.substring(6));
                        if (!isNaN(mbps) && !speed) speed = `${mbps} Mbit/s`;
                    }
                }
                root.band = band;
                root.linkSpeed = speed;
                root.ipAddress = ip;
                root.gateway = gw;
                root.dns = dns;
            }
        }
    }

    function refreshDetails(): void {
        const iface = root.activeIface;
        if (!iface) { root.band = ""; root.linkSpeed = ""; root.ipAddress = ""; root.gateway = ""; root.dns = ""; return; }
        const cmd = `nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show '${iface}'; ` +
            (root.wifiConnected
                ? `nmcli -t -f IN-USE,FREQ,RATE device wifi list ifname '${iface}' --rescan no`
                : `echo "SPEED:$(cat /sys/class/net/'${iface}'/speed 2>/dev/null)"`);
        detailsProc.exec(["sh", "-c", cmd]);
    }

    onActiveIfaceChanged: refreshDetails()
    onSsidChanged: refreshDetails()
    Timer {
        interval: 15000
        running: root.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshDetails()
    }

    // ---- Connecting ----
    property var pendingNetwork: null
    property bool needsPassword: false
    property string lastError: ""

    Connections {
        target: root.pendingNetwork
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            root.needsPassword = reason === ConnectionFailReason.NoSecrets;
            root.lastError = root.needsPassword ? "Se necesita contraseña" : ConnectionFailReason.toString(reason);
        }
        function onConnectedChanged() {
            if (root.pendingNetwork?.connected) {
                root.needsPassword = false;
                root.lastError = "";
                root.pendingNetwork = null;
            }
        }
    }

    function setWifiEnabled(enabled: bool): void { Networking.wifiEnabled = enabled; }
    function toggleWifi(): void { Networking.wifiEnabled = !Networking.wifiEnabled; }

    function setScanning(on: bool): void {
        if (wifiDevice) wifiDevice.scannerEnabled = on && Networking.wifiEnabled;
    }

    function connectToWifi(network, psk: string): void {
        if (!network) return;
        root.pendingNetwork = network;
        root.needsPassword = false;
        root.lastError = "";
        if (psk && psk.length > 0) network.connectWithPsk(psk);
        else network.connect();
    }

    function disconnect(): void {
        if (connectedWifiNetwork) connectedWifiNetwork.disconnect();
        else if (wiredConnected) wiredDevice.disconnect();
    }

    function forget(network): void { network?.forget(); }

    function isSecure(network): bool {
        const s = network?.security;
        return s !== undefined && s !== WifiSecurityType.Open && s !== WifiSecurityType.Unknown;
    }

    function securityLabel(network): string {
        switch (network?.security) {
            case WifiSecurityType.Open:    return "Abierta";
            case WifiSecurityType.Owe:     return "OWE";
            case WifiSecurityType.Sae:     return "WPA3";
            case WifiSecurityType.Wpa2Psk: return "WPA2";
            case WifiSecurityType.WpaPsk:  return "WPA";
            case WifiSecurityType.Wpa2Eap:
            case WifiSecurityType.WpaEap:
            case WifiSecurityType.Wpa3SuiteB192: return "Empresarial";
            case WifiSecurityType.StaticWep:
            case WifiSecurityType.DynamicWep:    return "WEP";
            default:                       return "";
        }
    }

    function checkConnectivity(): void { if (Networking.canCheckConnectivity) Networking.checkConnectivity(); }

    function openSettings(): void {
        Quickshell.execDetached(["sh", "-c",
            "command -v nm-connection-editor >/dev/null && exec nm-connection-editor; " +
            "command -v kcmshell6 >/dev/null && exec kcmshell6 kcm_networkmanagement; " +
            "exec systemsettings kcm_networkmanagement"]);
    }

    // ---- bands of the nearby networks (Quickshell's WifiNetwork has no frequency): while the Wi‑Fi popover scans ----
    property var bands: ({})
    function bandOf(network): string { return root.bands[network?.name ?? ""] ?? ""; }
    Process {
        id: bandsProc
        command: ["nmcli", "-t", "-f", "SSID,FREQ", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const b = {};
                for (const raw of this.text.split("\n")) {
                    const i = raw.lastIndexOf(":");
                    if (i <= 0) continue;
                    const ssid = raw.substring(0, i).replace(/\\:/g, ":"), mhz = parseInt(raw.substring(i + 1));
                    if (!ssid || isNaN(mhz) || b[ssid]) continue;
                    b[ssid] = mhz >= 5925 ? "6 GHz" : (mhz >= 4900 ? "5 GHz" : "2.4 GHz");
                }
                root.bands = b;
            }
        }
    }
    Timer {
        interval: 8000
        running: root.scanning
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!bandsProc.running) bandsProc.running = true
    }

    // ---- share the current network as a QR code (qrencode) ----
    property bool qrAvailable: false
    property string qrPath: ""
    property string qrError: ""
    Process {
        command: ["sh", "-c", "command -v qrencode"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.qrAvailable = this.text.trim().length > 0 }
    }
    Process {
        id: qrProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                if (out.startsWith("/")) { root.qrPath = ""; root.qrPath = out; root.qrError = ""; }
                else root.qrError = out || "No se pudo leer la clave de la red";
            }
        }
    }
    function shareQr(): void {
        if (!root.qrAvailable || !root.connectedWifiNetwork) return;
        const ssid = root.connectedWifiNetwork.name;
        const kind = root.isSecure(root.connectedWifiNetwork) ? (root.security === "WEP" ? "WEP" : "WPA") : "nopass";
        // the key of the active connection (NetworkManager asks the secret agent / keyring); WIFI: escapes \ ; , : "
        qrProc.exec(["sh", "-c", `
con=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v d="$2" '$2==d {print $1; exit}')
key=$(nmcli -s -g 802-11-wireless-security.psk connection show "$con" 2>/dev/null)
[ "$3" != "nopass" ] && [ -z "$key" ] && { echo "Sin clave guardada"; exit 0; }
esc() { printf '%s' "$1" | sed 's/[\\;,:"]/\\\\&/g'; }
out="\${XDG_RUNTIME_DIR:-/tmp}/dragon-wifi-qr.png"
qrencode -o "$out" -s 6 -m 1 --foreground=EDEBF5 --background=0E0C18 "WIFI:T:$3;S:$(esc "$1");P:$(esc "$key");;" && echo "$out"
`, "sh", ssid, root.wifiDevice?.name ?? "", kind]);
    }
    function clearQr(): void { root.qrPath = ""; root.qrError = ""; }
    onConnectedWifiNetworkChanged: clearQr()

    // ---- hidden network ----
    Process { id: hiddenProc; stdout: StdioCollector { onStreamFinished: root.lastError = this.text.indexOf("successfully") >= 0 ? "" : this.text.trim().split("\n").pop() } }
    function connectHidden(ssid: string, psk: string): void {
        if (!ssid) return;
        const args = ["nmcli", "device", "wifi", "connect", ssid, "hidden", "yes"];
        if (psk) args.push("password", psk);
        hiddenProc.exec(["sh", "-c", '"$@" 2>&1', "sh"].concat(args));
    }

    // ---- hotspot (shares the wired / other connection; on the only Wi‑Fi adapter it drops the current network) ----
    property bool hotspotActive: false
    property string hotspotName: ""
    Process {
        id: apProbe
        command: ["sh", "-c", "for c in $(nmcli -t -f UUID,TYPE connection show --active | awk -F: '$2==\"802-11-wireless\" {print $1}'); do [ \"$(nmcli -g 802-11-wireless.mode connection show \"$c\")\" = ap ] && nmcli -g connection.id connection show \"$c\"; done"]
        stdout: StdioCollector { onStreamFinished: { const n = this.text.trim().split("\n")[0] ?? ""; root.hotspotName = n; root.hotspotActive = n.length > 0; } }
    }
    Process { id: apProc; onExited: apProbe.running = true }
    function setHotspot(on: bool): void {
        const dev = root.wifiDevice?.name ?? "";
        if (on) apProc.exec(["sh", "-c", 'nmcli device wifi hotspot ifname "$1" ssid "$(hostname)-dragon" password "$(head -c 12 /dev/urandom | base64 | tr -dc A-Za-z0-9 | head -c 12)"', "sh", dev]);
        else if (root.hotspotName) apProc.exec(["nmcli", "connection", "down", root.hotspotName]);
    }
    Timer {
        interval: 10000
        running: root.scanning
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!apProbe.running) apProbe.running = true
    }

    signal connectionChanged(connected: bool, ssid: string)
    onConnectedChanged: root.connectionChanged(root.connected, root.ssid)
}
