// =============================================================================
// dragon-island — Bluetooth.qml
// Service: BlueZ adapter & devices (Quickshell.Bluetooth)
// =============================================================================
/**
 * Properties:
 *   - adapter: BluetoothAdapter [readonly] (null when there is no adapter)
 *   - adapterAvailable: bool [readonly]
 *   - enabled: bool [readonly] (adapter powered)
 *   - blocked: bool [readonly] (rfkill)
 *   - discovering: bool [readonly]
 *   - devices: list<BluetoothDevice> [readonly] (connected first, then paired, then others; by name)
 *   - connectedDevices: list<BluetoothDevice> [readonly]
 *   - pairedDevices: list<BluetoothDevice> [readonly]
 *   - availableDevices: list<BluetoothDevice> [readonly] (found while discovering, not paired)
 *   - primaryConnectedDevice: BluetoothDevice [readonly]
 *   - connectedDeviceName: string [readonly]
 *   - hasBattery: bool [readonly]   connectedBattery: real [readonly]   connectedBatteryPct: int [readonly]
 *
 * Functions:
 *   - togglePower(): void            setPower(on: bool): void
 *   - startDiscovery(): void         stopDiscovery(): void        toggleDiscovery(): void
 *   - connectDevice(d): void         disconnectDevice(d): void    toggleConnection(d): void
 *   - pairDevice(d): void            forgetDevice(d): void
 *   - batteryPct(d): int (-1 when the device does not report it)
 *   - isBusy(d): bool (pairing, connecting or disconnecting)
 *
 *   - discoverable: bool [readonly]   adapterName: string [readonly] («Visible como DragonOS»)
 *   - setDiscoverable(on: bool): void
 *   - kindOf(d): string ("audio" · "mouse" · "keyboard" · "phone" · "computer" · "other")   kindLabel(d): string (Spanish)
 *   - audioNode(d): PwNode (its PipeWire output, or null)   profileOf(d): string («alta calidad» · «manos libres» · "")
 *   - useAsOutput(d): void (Audio.setDefaultSink on its node)   toggleProfile(d): void (A2DP ↔ HFP with pactl, if present)
 *
 * Signals:
 *   - powerChanged(enabled: bool)
 *   - deviceConnected(name: string)
 *   - batteryLow(name: string, pct: int) (a connected device drops under 15 %; once until it charges above 20 %)
 */
pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool adapterAvailable: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
    readonly property bool discovering: adapter?.discovering ?? false

    readonly property var devices: {
        const rank = d => d.connected ? 0 : (d.paired ? 1 : 2);
        return Bluetooth.devices.values.slice().sort((a, b) => (rank(a) - rank(b)) || (a.name || "").localeCompare(b.name || ""));
    }
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property var pairedDevices: devices.filter(d => d.paired)
    readonly property var availableDevices: devices.filter(d => !d.paired && !d.connected && (d.name || "").length > 0)

    readonly property BluetoothDevice primaryConnectedDevice: connectedDevices[0] ?? null
    readonly property string connectedDeviceName: primaryConnectedDevice?.name || ""
    readonly property bool hasBattery: primaryConnectedDevice?.batteryAvailable ?? false
    readonly property real connectedBattery: hasBattery ? primaryConnectedDevice.battery : 0.0
    readonly property int connectedBatteryPct: Math.round(connectedBattery * 100)

    function setPower(on: bool): void { if (adapter) adapter.enabled = on; }
    function togglePower(): void { if (adapter) adapter.enabled = !adapter.enabled; }

    function startDiscovery(): void { if (adapter && adapter.enabled) adapter.discovering = true; }
    function stopDiscovery(): void { if (adapter) adapter.discovering = false; }
    function toggleDiscovery(): void { if (discovering) stopDiscovery(); else startDiscovery(); }

    function connectDevice(device): void { device?.connect(); }
    function disconnectDevice(device): void { device?.disconnect(); }
    function toggleConnection(device): void {
        if (!device) return;
        if (device.connected) device.disconnect(); else device.connect();
    }
    function pairDevice(device): void { device?.pair(); }
    function forgetDevice(device): void { device?.forget(); }

    readonly property bool discoverable: adapter?.discoverable ?? false
    readonly property string adapterName: adapter?.name ?? ""
    function setDiscoverable(on: bool): void { if (adapter) adapter.discoverable = on; }

    function kindOf(d): string {
        const i = (d?.icon ?? "").toLowerCase();
        if (i.indexOf("audio") >= 0 || i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "audio";
        if (i.indexOf("mouse") >= 0) return "mouse";
        if (i.indexOf("keyboard") >= 0) return "keyboard";
        if (i.indexOf("phone") >= 0) return "phone";
        if (i.indexOf("computer") >= 0) return "computer";
        return "other";
    }
    function kindLabel(d): string {
        return { audio: "Audio", mouse: "Ratón", keyboard: "Teclado", phone: "Teléfono", computer: "Equipo", other: "Dispositivo" }[kindOf(d)];
    }
    // the PipeWire output of a Bluetooth device: bluez_output.<MAC with _>.*
    function audioNode(d) {
        const mac = (d?.address ?? "").replace(/:/g, "_");
        if (!mac) return null;
        return Audio.sinks.find(n => (n.name ?? "").indexOf(mac) >= 0) ?? null;
    }
    function profileOf(d): string {
        const n = root.audioNode(d);
        const prof = `${n?.properties?.["api.bluez5.profile"] ?? n?.name ?? ""}`;
        if (/a2dp/i.test(prof)) return "alta calidad";
        if (/headset|hfp|hsp/i.test(prof)) return "manos libres";
        return "";
    }
    function useAsOutput(d): void { const n = root.audioNode(d); if (n) Audio.setDefaultSink(n); }
    Process { id: profileProc }
    function toggleProfile(d): void {
        const mac = (d?.address ?? "").replace(/:/g, "_");
        if (!mac) return;
        const next = root.profileOf(d) === "alta calidad" ? "headset-head-unit" : "a2dp-sink";
        profileProc.exec(["sh", "-c", 'command -v pactl >/dev/null && pactl set-card-profile "bluez_card.$1" "$2"', "sh", mac, next]);
    }

    // low battery: once per device until it is back above 20 %
    property var _lowWarned: ({})
    function _checkBatteries(): void {
        const w = Object.assign({}, root._lowWarned);
        for (const d of root.connectedDevices) {
            const p = root.batteryPct(d);
            if (p < 0) continue;
            if (p < 15 && !w[d.address]) { w[d.address] = true; root.batteryLow(d.name || "Dispositivo", p); }
            else if (p > 20 && w[d.address]) delete w[d.address];
        }
        root._lowWarned = w;
    }
    Timer { interval: 60000; running: root.connectedDevices.length > 0; repeat: true; triggeredOnStart: true; onTriggered: root._checkBatteries() }

    function batteryPct(device): int {
        return device?.batteryAvailable ? Math.round(device.battery * 100) : -1;
    }

    function isBusy(device): bool {
        return (device?.pairing ?? false)
            || device?.state === BluetoothDeviceState.Connecting
            || device?.state === BluetoothDeviceState.Disconnecting;
    }

    signal powerChanged(enabled: bool)
    signal deviceConnected(name: string)
    signal batteryLow(name: string, pct: int)

    onEnabledChanged: root.powerChanged(root.enabled)
    onConnectedDeviceNameChanged: {
        if (root.connectedDeviceName.length > 0) root.deviceConnected(root.connectedDeviceName);
    }
}
