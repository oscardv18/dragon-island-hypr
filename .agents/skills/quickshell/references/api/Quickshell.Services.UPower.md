# Quickshell.Services.UPower

`import Quickshell.Services.UPower`

UPower Service

## PerformanceDegradationReason
*enum* · extends `QtObject`

See `PowerProfiles.degradationReason` for more information.

**Functions**
- `toString(reason: PerformanceDegradationReason)`: string

**Values:** `PerformanceDegradationReason.LapDetected`, `PerformanceDegradationReason.None`, `PerformanceDegradationReason.HighTemperature`

## PowerProfile
*enum* · extends `QtObject`

See `PowerProfiles`.

**Functions**
- `toString(profile: PowerProfile)`: string

**Values:** `PowerProfile.PowerSaver`, `PowerProfile.Balanced`, `PowerProfile.Performance`

## PowerProfiles
*singleton* · extends `QtObject`

An interface to the UPower [power profiles daemon], which can be
used to view and manage power profiles.

> [!NOTE]
> The power profiles daemon must be installed to use this service.
> Installing UPower does not necessarily install the power profiles daemon.

[power profiles daemon]: https://gitlab.freedesktop.org/upower/power-profiles-daemon

**Properties**
- `degradationReason`: PerformanceDegradationReason [readonly] — If power-profiles-daemon detects degraded system performance, the reason
  for the degradation will be present here.
- `hasPerformanceProfile`: bool [readonly] — If the system has a performance profile.

  If this property is false, your system does not have a performance
  profile known to power-profiles-daemon.
- `holds`: list<> [readonly] — Power profile holds created by other applications.

  This property returns a `powerProfileHold` object, which has the following properties.
  - `profile` - The `PowerProfile` held by the application.
  - `applicationId` - A string identifying the application
  - `reason` - The reason the application has given for holding the profile.

  Applications may "hold" a power profile in place for their lifetime, such
  as a game holding Performance mode or a system daemon holding Power Saver mode
  when reaching a battery threshold. If the user selects a different profile explicitly
  (e.g. by setting `profile`) all holds will be removed.

  Multiple applications may hold a power profile, however if multiple applications request
  profiles than `PowerSaver` will win over `Performance`. Only `Performance` and `PowerSaver`
  profiles may be held.
- `profile`: PowerProfile — The current power profile.

  This property may be set to change the system's power profile, however
  it cannot be set to `Performance` unless `hasPerformanceProfile` is true.

## UPower
*singleton* · extends `QtObject`

An interface to the [UPower daemon], which can be used to
view battery and power statistics for your computer and
connected devices.

> [!NOTE]
> The UPower daemon must be installed to use this service.

[UPower daemon]: https://upower.freedesktop.org

**Properties**
- `displayDevice`: UPowerDevice [readonly] — UPower's DisplayDevice for your system. Cannot be null,
  but might not be initialized (check `UPowerDevice.ready` if you need to know).

  This is an aggregate device and not a physical one, meaning you will not find it in `devices`.
  It is typically the device that is used for displaying information in desktop environments.
- `onBattery`: bool [readonly] — If the system is currently running on battery power, or discharging.
- `devices`: ObjectModel<UPowerDevice> [readonly] — All connected UPower devices.

## UPowerDevice
*class* · extends `QtObject` · uncreatable (obtained from other objects)

A device exposed through the UPower system service.

**Properties**
- `healthPercentage`: real [readonly] — Health of the device as a percentage of its original health.
- `energy`: real [readonly] — Current energy level of the device in watt-hours.
- `type`: DeviceType [readonly] — The type of device.
- `isLaptopBattery`: bool [readonly] — If the device is a laptop battery or not. Use this to check if your device is a valid battery.

  This will be equivalent to `type` == Battery && `powerSupply` == true.
- `timeToFull`: real [readonly] — Estimated time until the device is fully charged, in seconds.

  Will be set to `0` if discharging.
- `timeToEmpty`: real [readonly] — Estimated time until the device is fully discharged, in seconds.

  Will be set to `0` if charging.
- `powerSupply`: bool [readonly] — If the device is a power supply for your computer and can provide charge.
- `healthSupported`: bool [readonly]
- `state`: UPowerDeviceState [readonly] — Current state of the device.
- `percentage`: real [readonly] — Current charge level as a percentage.

  This would be equivalent to `energy` / `energyCapacity`.
- `iconName`: string [readonly] — Name of the icon representing the current state of the device, or an empty string if not provided.
- `model`: string [readonly] — Model name of the device. Unlikely to be useful for internal devices.
- `energyCapacity`: real [readonly] — Maximum energy capacity of the device in watt-hours
- `nativePath`: string [readonly] — Native path of the device specific to your OS.
- `changeRate`: real [readonly] — Rate of energy change in watts (positive when charging, negative when discharging).
- `ready`: bool [readonly] — If device statistics have been queried for this device yet.
  This will be true for all devices returned from `UPower.devices`, but not the default
  device, which may be returned before it is ready to avoid returning null.
- `isPresent`: bool [readonly] — If the power source is present in the bay or slot, useful for hot-removable batteries.

  If the device `type` is not `Battery`, then the property will be invalid.

## UPowerDeviceState
*enum* · extends `QtObject`

See `UPowerDevice.state`.

**Functions**
- `toString(status: UPowerDeviceState)`: string

**Values:** `UPowerDeviceState.Charging`, `UPowerDeviceState.PendingCharge`, `UPowerDeviceState.PendingDischarge`, `UPowerDeviceState.Discharging`, `UPowerDeviceState.Empty`, `UPowerDeviceState.Unknown`, `UPowerDeviceState.FullyCharged`

## UPowerDeviceType
*enum* · extends `QtObject`

See `UPowerDevice.type`.

**Functions**
- `toString(type: DeviceType)`: string

**Values:** `UPowerDeviceType.BluetoothGeneric`, `UPowerDeviceType.Computer`, `UPowerDeviceType.Pda`, `UPowerDeviceType.Phone`, `UPowerDeviceType.Network`, `UPowerDeviceType.LinePower`, `UPowerDeviceType.Speakers`, `UPowerDeviceType.Headphones`, `UPowerDeviceType.Toy`, `UPowerDeviceType.Printer`, `UPowerDeviceType.Ups`, `UPowerDeviceType.Unknown`, `UPowerDeviceType.Tablet`, `UPowerDeviceType.MediaPlayer`, `UPowerDeviceType.Wearable`, `UPowerDeviceType.Scanner`, `UPowerDeviceType.Keyboard`, `UPowerDeviceType.Mouse`, `UPowerDeviceType.Pen`, `UPowerDeviceType.Modem`, `UPowerDeviceType.Headset`, `UPowerDeviceType.Video`, `UPowerDeviceType.RemoteControl`, `UPowerDeviceType.Camera`, `UPowerDeviceType.Battery`, `UPowerDeviceType.GamingInput`, `UPowerDeviceType.OtherAudio`, `UPowerDeviceType.Monitor`, `UPowerDeviceType.Touchpad`
