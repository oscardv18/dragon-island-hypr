# Quickshell.Bluetooth

`import Quickshell.Bluetooth`

Bluetooth API

## Bluetooth
*singleton* · extends `QtObject`

Provides access to bluetooth devices and adapters.

**Properties**
- `adapters`: ObjectModel<BluetoothAdapter> [readonly] — A list of all bluetooth adapters. See `defaultAdapter` for the default.
- `defaultAdapter`: BluetoothAdapter [readonly] — The default bluetooth adapter. Usually there is only one.
- `devices`: ObjectModel<BluetoothDevice> [readonly] — A list of all connected bluetooth devices across all adapters.
  See `BluetoothAdapter.devices` for the devices connected to a single adapter.

## BluetoothAdapter
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A Bluetooth adapter

**Properties**
- `name`: string [readonly] — System provided name of the adapter. See `adapterId` for the internal identifier.
- `pairableTimeout`: int — Timeout in seconds for how long the adapter stays pairable after `pairable` is set to true.
  A value of 0 means the adapter stays pairable forever. Defaults to 0.
- `devices`: ObjectModel<BluetoothDevice> [readonly] — Bluetooth devices connected to this adapter.
- `adapterId`: string [readonly] — The internal ID of the adapter (e.g., "hci0").
- `dbusPath`: string [readonly] — DBus path of the adapter under the `org.bluez` system service.
- `discoverableTimeout`: int — Timeout in seconds for how long the adapter stays discoverable after `discoverable` is set to true.
  A value of 0 means the adapter stays discoverable forever.
- `pairable`: bool — True if the adapter is accepting incoming pairing requests.

  This only affects incoming pairing requests and should typically only be changed
  by system settings applications. Defaults to true.
- `discoverable`: bool — True if the adapter can be discovered by other bluetooth devices.
- `state`: BluetoothAdapterState [readonly] — Detailed power state of the adapter.
- `enabled`: bool — True if the adapter is currently enabled. More detailed state is available from `state`.
- `discovering`: bool — True if the adapter is scanning for new devices.

## BluetoothAdapterState
*enum* · extends `QtObject`

Power state of a Bluetooth adapter.

**Functions**
- `toString(state: BluetoothAdapterState)`: string

**Values:** `BluetoothAdapterState.Disabling`, `BluetoothAdapterState.Enabling`, `BluetoothAdapterState.Disabled`, `BluetoothAdapterState.Enabled`, `BluetoothAdapterState.Blocked`

## BluetoothDevice
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A tracked Bluetooth device.

**Properties**
- `adapter`: BluetoothAdapter [readonly] — The Bluetooth adapter this device belongs to.
- `dbusPath`: string [readonly] — DBus path of the device under the `org.bluez` system service.
- `paired`: bool [readonly] — True if the device is paired to the computer.

  > [!NOTE]
  > `pair` can be used to pair a device, however you must `forget` the device to unpair it.
- `deviceName`: string [readonly] — The name of the Bluetooth device, ignoring user provided aliases. See also `name`
  which returns a user provided alias if set.
- `connected`: bool — True if the device is currently connected to the computer.

  Setting this property is equivalent to calling `connect` and `disconnect`.

  > [!NOTE]
  > `state` provides more detailed information if required.
- `icon`: string [readonly] — System icon representing the device type. Use `Quickshell.iconPath` to display this in an image.
- `address`: string [readonly] — MAC address of the device.
- `blocked`: bool — True if the device is blocked from connecting.
  If a device is blocked, any connection attempts will be immediately rejected by the system.
- `wakeAllowed`: bool — True if the device is allowed to wake up the host system from suspend.
- `pairing`: bool [readonly] — True if the device is currently being paired.

  > [!NOTE]
  > `cancelPair` can be used to cancel the pairing process.
- `battery`: real [readonly] — Battery level of the connected device, from `0.0` to `1.0`. Only valid if `batteryAvailable` is true.
- `bonded`: bool [readonly] — True if pairing information is stored for future connections.
- `state`: BluetoothDeviceState [readonly] — Connection state of the device.
- `name`: string — The name of the Bluetooth device. This property may be written to create an alias, or set to
  an empty string to fall back to the device provided name.

  See `deviceName` for the name provided by the device.
- `trusted`: bool — True if the device is considered to be trusted by the system.
  Trusted devices are allowed to reconnect themselves to the system without intervention.
- `batteryAvailable`: bool [readonly] — True if the connected device reports its battery level. Battery level can be accessed via `battery`.

**Functions**
- `cancelPair()`: void — Cancel an active pairing attempt.
- `connect()`: void — Attempt to connect to the device.
- `disconnect()`: void — Disconnect from the device.
- `forget()`: void — Forget the device.
- `pair()`: void — Attempt to pair the device.

  > [!NOTE]
  > `paired` and `pairing` return the current pairing status of the device.

## BluetoothDeviceState
*enum* · extends `QtObject`

Connection state of a Bluetooth device.

**Functions**
- `toString(state: BluetoothDeviceState)`: string

**Values:** `BluetoothDeviceState.Disconnected`, `BluetoothDeviceState.Connected`, `BluetoothDeviceState.Disconnecting`, `BluetoothDeviceState.Connecting`
