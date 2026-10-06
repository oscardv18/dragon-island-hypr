// =============================================================================
// dragon-island — Power.qml
// Service: UPower battery & power-profiles-daemon
// =============================================================================
/**
 * Properties:
 *   - hasBattery: bool [readonly] (false on desktops → hide battery UI)
 *   - batteryPct: int [readonly] (0 - 100)        batteryFraction: real [readonly] (0.0 - 1.0)
 *   - isCharging: bool [readonly]                 isPluggedIn: bool [readonly]
 *   - onBattery: bool [readonly]
 *   - isLow: bool [readonly] (≤ 15 % and discharging)
 *   - stateString: string [readonly]
 *   - timeRemainingSeconds: real [readonly]       timeRemainingFormatted: string [readonly]
 *   - changeRateWatts: real [readonly] (absolute value)
 *   - healthPct: real [readonly] (-1 if unknown)
 *   - hasPerformanceProfile: bool [readonly]
 *   - currentProfile: int [readonly] (PowerProfile enum value)
 *   - currentProfileKey: string [readonly] ("power-saver" | "balanced" | "performance")
 *   - currentProfileString: string [readonly] (Spanish label)
 *   - profiles: list<var> [readonly] ({ key, label, available })
 *
 * Functions:
 *   - setProfile(profile: PowerProfile): void
 *   - setProfileByName(name: string): void (keys above or Spanish labels)
 *   - cycleProfile(): void
 *
 * Signals:
 *   - batteryChanged(pct: int, isCharging: bool)
 *   - profileChanged(profile: string)
 */
pragma Singleton
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    readonly property UPowerDevice displayDevice: UPower.displayDevice
    // physical battery (health is only meaningful there, not on the aggregate display device)
    readonly property var batteryDevice: UPower.devices.values.find(d => d.isLaptopBattery) ?? null

    readonly property bool hasBattery: (displayDevice?.isLaptopBattery ?? false) || batteryDevice !== null

    // NOTE: percentage is 0.0 - 1.0 in Quickshell 0.3.1
    readonly property real batteryFraction: displayDevice?.percentage ?? 0.0
    readonly property int batteryPct: Math.round(batteryFraction * 100)

    readonly property bool isCharging: displayDevice?.state === UPowerDeviceState.Charging
    readonly property bool onBattery: UPower.onBattery
    readonly property bool isPluggedIn: hasBattery && !onBattery
    readonly property bool isLow: hasBattery && onBattery && batteryPct <= 15

    readonly property string stateString: {
        switch (displayDevice?.state) {
            case UPowerDeviceState.Charging:         return "Cargando";
            case UPowerDeviceState.Discharging:      return "Con batería";
            case UPowerDeviceState.FullyCharged:     return "Carga completa";
            case UPowerDeviceState.PendingCharge:    return "Conectado, sin cargar";
            case UPowerDeviceState.PendingDischarge: return "En espera";
            case UPowerDeviceState.Empty:            return "Batería agotada";
            default:                                 return "Conectado";
        }
    }

    readonly property real timeRemainingSeconds: isCharging ? (displayDevice?.timeToFull ?? 0) : (displayDevice?.timeToEmpty ?? 0)
    readonly property string timeRemainingFormatted: {
        const secs = root.timeRemainingSeconds;
        if (!(secs > 0)) return "";
        const mins = Math.round(secs / 60);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        const t = h > 0 ? `${h} h ${m} min` : `${m} min`;
        return root.isCharging ? `${t} hasta completar` : `${t} restantes`;
    }

    readonly property real changeRateWatts: Math.abs(displayDevice?.changeRate ?? 0.0)
    readonly property real healthPct: (batteryDevice?.healthSupported ?? false) ? batteryDevice.healthPercentage : -1

    // ---- Power profiles ----
    // Needs power-profiles-daemon (installed and enabled by the installer's "services" component)
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    readonly property int currentProfile: PowerProfiles.profile
    readonly property string currentProfileKey: {
        switch (PowerProfiles.profile) {
            case PowerProfile.PowerSaver:  return "power-saver";
            case PowerProfile.Performance: return "performance";
            default:                       return "balanced";
        }
    }
    readonly property string currentProfileString: labelFor(currentProfileKey)
    readonly property var profiles: [
        { key: "power-saver", label: labelFor("power-saver"), available: true },
        { key: "balanced",    label: labelFor("balanced"),    available: true },
        { key: "performance", label: labelFor("performance"), available: hasPerformanceProfile }
    ]

    function labelFor(key: string): string {
        switch (key) {
            case "power-saver": return "Ahorro";
            case "performance": return "Rendimiento";
            default:            return "Equilibrado";
        }
    }

    function setProfile(profile: PowerProfile): void {
        if (profile === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile) return;
        PowerProfiles.profile = profile;
    }

    function setProfileByName(name: string): void {
        switch (name.toLowerCase()) {
            case "power-saver": case "powersaver": case "ahorro":
                setProfile(PowerProfile.PowerSaver); break;
            case "balanced": case "equilibrado":
                setProfile(PowerProfile.Balanced); break;
            case "performance": case "rendimiento":
                setProfile(PowerProfile.Performance); break;
        }
    }

    function cycleProfile(): void {
        if (PowerProfiles.profile === PowerProfile.PowerSaver) setProfile(PowerProfile.Balanced);
        else if (PowerProfiles.profile === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile) setProfile(PowerProfile.Performance);
        else setProfile(PowerProfile.PowerSaver);
    }

    signal batteryChanged(pct: int, isCharging: bool)
    signal profileChanged(profile: string)

    onBatteryPctChanged: root.batteryChanged(root.batteryPct, root.isCharging)
    onIsChargingChanged: root.batteryChanged(root.batteryPct, root.isCharging)
    onCurrentProfileKeyChanged: root.profileChanged(root.currentProfileKey)
}
