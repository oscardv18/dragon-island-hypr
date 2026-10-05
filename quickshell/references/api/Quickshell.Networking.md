# Quickshell.Networking

`import Quickshell.Networking`

Network API

## ConnectionFailReason
*enum* · extends `QtObject`

The reason a connection failed.

**Functions**
- `toString(reason: ConnectionFailReason)`: string

**Values:** `ConnectionFailReason.Unknown`, `ConnectionFailReason.WifiClientFailed`, `ConnectionFailReason.WifiAuthTimeout`, `ConnectionFailReason.WifiClientDisconnected`, `ConnectionFailReason.NoSecrets`, `ConnectionFailReason.WifiNetworkLost`

## ConnectionState
*enum* · extends `QtObject`

The connection state of a device or network.

**Functions**
- `toString(state: ConnectionState)`: string

**Values:** `ConnectionState.Connecting`, `ConnectionState.Unknown`, `ConnectionState.Connected`, `ConnectionState.Disconnecting`, `ConnectionState.Disconnected`

## DeviceType
*enum* · extends `QtObject`

Type of a `NetworkDevice`.

**Functions**
- `toString(type: DeviceType)`: string

**Values:** `DeviceType.Wifi`, `DeviceType.Wired`, `DeviceType.None`

## NMSettings
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A NetworkManager connection settings profile.

**Properties**
- `id`: string [readonly] — The human-readable unique identifier for the connection.
- `uuid`: string [readonly] — A universally unique identifier for the connection.

**Functions**
- `clearSecrets()`: void — Clear all of the secrets belonging to the settings.
- `forget()`: void — Delete the settings.
- `read()`:  — Get the settings map describing this network configuration.

  > [!NOTE]
  > This will never include any secrets required for connection to the network, as those are often protected.
- `write(settings: )`: void — Update the connection with new settings and save the connection to disk.
  Only changed fields need to be included.
  Writing a setting to `null` will remove the setting or reset it to its default.

  > [!NOTE]
  > Secrets may be part of the update request,
  > and will be either stored in persistent storage or sent to a Secret Agent for storage,
  > depending on the flags associated with each secret.

**Signals**
- `loaded()` — handler `onLoaded`
- `settingsChanged(settings: )` — handler `onSettingsChanged`

## Network
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A network. Networks derived from a `WifiDevice` are `WifiNetwork` instances.

**Properties**
- `state`: ConnectionState [readonly] — The connectivity state of the network.
- `connected`: bool [readonly] — True if the network is connected.
- `known`: bool [readonly] — True if the wifi network has known connection settings saved.
- `device`: NetworkDevice [readonly] — The device this network belongs to.
- `nmSettings`: list<NMSettings> [readonly] — A list of NetworkManager connection settings profiles for this network.

  > [!WARNING]
  > Only valid for the NetworkManager backend.
- `stateChanging`: bool [readonly] — If the network is currently connecting or disconnecting. Shorthand for checking `state`.
- `name`: string [readonly] — The name of the network.

**Functions**
- `connect()`: void — Attempt to connect to the network.

  > [!NOTE]
  > If the network is a `WifiNetwork` and requires secrets, a `connectionFailed`
  > signal will be emitted with `NoSecrets`.
  > `WifiNetwork.connectWithPsk` can be used to provide secrets.
- `connectWithSettings(settings: NMSettings)`: void — Attempt to connect to the network with a specific `nmSettings` entry.

  > [!WARNING]
  > Only valid for the NetworkManager backend.
- `disconnect()`: void — Disconnect from the network.
- `forget()`: void — Forget all connection settings for this network.

**Signals**
- `connectionFailed(reason: ConnectionFailReason)` — handler `onConnectionFailed` — Signals that a connection to the network has failed because of the given `ConnectionFailReason`.

## NetworkBackendType
*enum* · extends `QtObject`

The backend supplying the Network service.

**Functions**
- `toString(type: NetworkBackendType)`: string

**Values:** `NetworkBackendType.None`, `NetworkBackendType.NetworkManager`

## NetworkConnectivity
*enum* · extends `QtObject`

The degree to which the host can reach the internet.

**Functions**
- `toString(conn: NetworkConnectivity)`: string

**Values:** `NetworkConnectivity.Full`, `NetworkConnectivity.Unknown`, `NetworkConnectivity.Limited`, `NetworkConnectivity.None`, `NetworkConnectivity.Portal`

## NetworkDevice
*class* · extends `QtObject` · uncreatable (obtained from other objects)

The `type` property may be used to determine if this device is a `WifiDevice` or `WiredDevice`.

**Properties**
- `networks`: ObjectModel<Network> [readonly] — A list of available or connected networks for this device.

  When the device type is 'Wifi', this model will only contain `WifiNetwork`.
- `connected`: bool [readonly] — True if the device is connected.
- `autoconnect`: bool — True if the device is allowed to autoconnect to a network.
- `name`: string [readonly] — The name of the device's control interface.
- `address`: string [readonly] — The hardware address of the device in the XX:XX:XX:XX:XX:XX format.
- `type`: DeviceType [readonly] — The device type.

  When the device type is `Wifi`, the device object is a `WifiDevice`.
  When the device type is `Wired`, the device object is a `WiredDevice`.
  connection and scanning.
- `state`: ConnectionState [readonly] — Connection state of the device.

**Functions**
- `disconnect()`: void — Disconnects the device and prevents it from automatically activating further connections.

## Networking
*singleton* · extends `QtObject`

An interface to a network backend (currently only NetworkManager),
which can be used to view, configure, and connect to various networks.

**Properties**
- `canCheckConnectivity`: bool [readonly] — True if the `backend` supports connectivity checks.
- `backend`: NetworkBackendType [readonly] — The backend being used to power the Network service.
- `connectivity`: NetworkConnectivity [readonly] — The result of the last connectivity check.

  Connectivity checks may require additional configuration depending on your distro.

  > [!NOTE]
  > This property can be used to determine if network access is restricted
  > or gated behind a captive portal.
  >
  > If checking for captive portals, `checkConnectivity` should be called after
  > the portal is dismissed to update this property.
- `devices`: ObjectModel<NetworkDevice> [readonly] — A list of all network devices. Networks are exposed through their respective devices.
- `wifiEnabled`: bool — Switch for the rfkill software block of all wireless devices.
- `connectivityCheckEnabled`: bool — True if connectivity checking is enabled.
- `wifiHardwareEnabled`: bool [readonly] — State of the rfkill hardware block of all wireless devices.

**Functions**
- `checkConnectivity()`: void — Re-check the network connectivity state immediately.
  > [!NOTE]
  > This should be invoked after a user dismisses a web browser that was opened to authenticate via a captive portal.

## WifiDevice
*class* · extends `NetworkDevice` · uncreatable (obtained from other objects)

WiFi variant of a `NetworkDevice`.

**Properties**
- `scannerEnabled`: bool — True when currently scanning for networks.
  When enabled, the scanner populates the device with an active list of available wifi networks.
- `mode`: WifiDeviceMode [readonly] — The 802.11 mode the device is in.

## WifiDeviceMode
*enum* · extends `QtObject`

The 802.11 mode of a `WifiDevice`.

**Functions**
- `toString(mode: WifiDeviceMode)`: string

**Values:** `WifiDeviceMode.Mesh`, `WifiDeviceMode.Station`, `WifiDeviceMode.AccessPoint`, `WifiDeviceMode.AdHoc`, `WifiDeviceMode.Unknown`

## WifiNetwork
*class* · extends `Network` · uncreatable (obtained from other objects)

WiFi subtype of `Network`.

**Properties**
- `security`: WifiSecurityType [readonly] — The security type of the wifi network.
- `signalStrength`: real [readonly] — The current signal strength of the network, from 0.0 to 1.0.

**Functions**
- `connectWithPsk(psk: string)`: void — Attempt to connect to the network with the given PSK. If the PSK is wrong,
  a `Network.connectionFailed` signal will be emitted with `NoSecrets`.

  The networking backend may store the PSK for future use with `Network.connect`.
  As such, calling that function first is recommended to avoid having to show a
  prompt if not required.

  > [!NOTE]
  > PSKs should only be provided when the `security` is one of
  > `WpaPsk`, `Wpa2Psk`, or `Sae`.

## WifiSecurityType
*enum* · extends `QtObject`

The security type of a `WifiNetwork`.

**Functions**
- `toString(type: WifiSecurityType)`: string

**Values:** `WifiSecurityType.Owe`, `WifiSecurityType.WpaPsk`, `WifiSecurityType.Unknown`, `WifiSecurityType.Wpa2Eap`, `WifiSecurityType.Wpa3SuiteB192`, `WifiSecurityType.Sae`, `WifiSecurityType.Leap`, `WifiSecurityType.WpaEap`, `WifiSecurityType.DynamicWep`, `WifiSecurityType.StaticWep`, `WifiSecurityType.Open`, `WifiSecurityType.Wpa2Psk`

## WiredDevice
*class* · extends `NetworkDevice` · uncreatable (obtained from other objects)

Wired variant of a `NetworkDevice`.

**Properties**
- `hasLink`: bool [readonly] — True if the wired device has a physical link (cable plugged in).
- `linkSpeed`: int [readonly] — The maximum speed of the physical device link, in megabits per second.
- `network`: Network [readonly] — The wired network for this device or `null`.

  > [!NOTE]
  > This network is only available when `hasLink` is `true`.
