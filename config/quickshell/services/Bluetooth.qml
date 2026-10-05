// =============================================================================
// dragon-island — Bluetooth.qml
// Service: Bluetooth Adapter & Device Management
// =============================================================================
/**
 * Properties:
 *   - adapterAvailable: bool [readonly]
 *   - enabled: bool
 *   - discovering: bool [readonly]
 *   - connectedDevices: list<BluetoothDevice> [readonly]
 *   - pairedDevices: list<BluetoothDevice> [readonly]
 *   - connectedDeviceName: string [readonly]
 *   - connectedBattery: real [readonly] (0.0 - 1.0)
 *   - connectedBatteryPct: int [readonly] (0 - 100)
 *   - hasBattery: bool [readonly]
 *
 * Functions:
 *   - togglePower(): void
 *   - setPower(on: bool): void
 *   - startDiscovery(): void
 *   - connectDevice(device: BluetoothDevice): void
 *   - disconnectDevice(device: BluetoothDevice): void
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

    property bool enabled: adapter?.enabled ?? false
    onEnabledChanged: {
        if (adapter && adapter.enabled !== root.enabled) {
            adapter.enabled = root.enabled;
        }
    }

    readonly property bool discovering: adapter?.discovering ?? false

    // Device lists
    readonly property var connectedDevices: {
        return Bluetooth.devices.values.filter(d => d.connected);
    }

    readonly property var pairedDevices: {
        return Bluetooth.devices.values.filter(d => d.paired);
    }

    // First connected device summary for bar capsule
    readonly property BluetoothDevice primaryConnectedDevice: connectedDevices[0] ?? null
    readonly property string connectedDeviceName: primaryConnectedDevice?.name || ""
    readonly property real connectedBattery: primaryConnectedDevice?.battery ?? 0.0
    readonly property int connectedBatteryPct: Math.round(connectedBattery * 100)
    readonly property bool hasBattery: primaryConnectedDevice?.batteryAvailable ?? false

    function togglePower(): void {
        root.enabled = !root.enabled;
    }

    function setPower(on: bool): void {
        root.enabled = on;
    }

    function startDiscovery(): void {
        if (adapter) {
            adapter.discovering = true;
        }
    }

    function connectDevice(device: BluetoothDevice): void {
        device?.connect();
    }

    function disconnectDevice(device: BluetoothDevice): void {
        device?.disconnect();
    }

    signal powerChanged(enabled: bool)
    signal deviceConnected(name: string)

    onEnabledChanged: root.powerChanged(root.enabled)
    onConnectedDeviceNameChanged: {
        if (root.connectedDeviceName.length > 0) {
            root.deviceConnected(root.connectedDeviceName);
        }
    }
}
