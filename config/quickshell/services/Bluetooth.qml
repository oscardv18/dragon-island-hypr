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
 * Signals:
 *   - powerChanged(enabled: bool)
 *   - deviceConnected(name: string)
 */
pragma Singleton
import Quickshell
import Quickshell.Bluetooth
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

    onEnabledChanged: root.powerChanged(root.enabled)
    onConnectedDeviceNameChanged: {
        if (root.connectedDeviceName.length > 0) root.deviceConnected(root.connectedDeviceName);
    }
}
