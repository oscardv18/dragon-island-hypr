// =============================================================================
// dragon-island — Power.qml
// Service: UPower Battery & PowerProfiles Management
// =============================================================================
/**
 * Properties:
 *   - hasBattery: bool [readonly] (true only if system has a laptop battery)
 *   - batteryPct: int [readonly] (0 - 100 percentage)
 *   - batteryFraction: real [readonly] (0.0 - 1.0)
 *   - isCharging: bool [readonly]
 *   - isPluggedIn: bool [readonly]
 *   - stateString: string [readonly]
 *   - timeRemainingSeconds: real [readonly]
 *   - timeRemainingFormatted: string [readonly]
 *   - changeRateWatts: real [readonly]
 *   - healthPct: real [readonly]
 *   - currentProfile: PowerProfile [readonly]
 *   - currentProfileString: string [readonly]
 *
 * Functions:
 *   - setProfile(profile: PowerProfile): void
 *   - setProfileByName(name: string): void
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

    // Laptop battery verification (avoids showing battery widgets on desktop PCs)
    readonly property bool hasBattery: displayDevice?.isLaptopBattery ?? false

    // NOTE: UPower percentage is 0.0 to 1.0 in Quickshell 0.3.1
    readonly property real batteryFraction: displayDevice?.percentage ?? 0.0
    readonly property int batteryPct: Math.round(batteryFraction * 100)

    readonly property bool isCharging: displayDevice?.state === UPowerDeviceState.Charging
    readonly property bool isPluggedIn: isCharging || (displayDevice?.state === UPowerDeviceState.FullyCharged)

    readonly property string stateString: {
        switch (displayDevice?.state) {
            case UPowerDeviceState.Charging: return "Cargando";
            case UPowerDeviceState.Discharging: return "Descargando";
            case UPowerDeviceState.FullyCharged: return "Carga completa";
            case UPowerDeviceState.PendingCharge: return "En espera de carga";
            case UPowerDeviceState.PendingDischarge: return "En espera de descarga";
            case UPowerDeviceState.Empty: return "Batería agotada";
            default: return "Conectado";
        }
    }

    readonly property real timeRemainingSeconds: {
        if (isCharging) {
            return displayDevice?.timeToFull ?? 0;
        } else {
            return displayDevice?.timeToEmpty ?? 0;
        }
    }

    readonly property string timeRemainingFormatted: {
        const secs = root.timeRemainingSeconds;
        if (secs <= 0) return "";
        const mins = Math.round(secs / 60);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        if (h > 0) {
            return `${h}h ${m}m restantes`;
        }
        return `${m}m restantes`;
    }

    readonly property real changeRateWatts: Math.abs(displayDevice?.changeRate ?? 0.0)
    readonly property real healthPct: displayDevice?.healthPercentage ?? 100.0

    // Power Profiles (PowerProfiles daemon integration)
    readonly property PowerProfile currentProfile: PowerProfiles.profile
    readonly property string currentProfileString: {
        switch (PowerProfiles.profile) {
            case PowerProfile.PowerSaver:  return "Ahorro de energía";
            case PowerProfile.Balanced:    return "Equilibrado";
            case PowerProfile.Performance: return "Rendimiento";
            default:                       return "Equilibrado";
        }
    }

    function setProfile(profile: PowerProfile): void {
        PowerProfiles.profile = profile;
    }

    function setProfileByName(name: string): void {
        switch (name.toLowerCase()) {
            case "powersaver":
            case "ahorro":
                PowerProfiles.profile = PowerProfile.PowerSaver;
                break;
            case "balanced":
            case "equilibrado":
                PowerProfiles.profile = PowerProfile.Balanced;
                break;
            case "performance":
            case "rendimiento":
                if (PowerProfiles.hasPerformanceProfile) {
                    PowerProfiles.profile = PowerProfile.Performance;
                }
                break;
        }
    }

    function cycleProfile(): void {
        if (PowerProfiles.profile === PowerProfile.PowerSaver) {
            PowerProfiles.profile = PowerProfile.Balanced;
        } else if (PowerProfiles.profile === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile) {
            PowerProfiles.profile = PowerProfile.Performance;
        } else {
            PowerProfiles.profile = PowerProfile.PowerSaver;
        }
    }

    signal batteryChanged(pct: int, isCharging: bool)
    signal profileChanged(profile: string)

    onBatteryPctChanged: root.batteryChanged(root.batteryPct, root.isCharging)
    onIsChargingChanged: root.batteryChanged(root.batteryPct, root.isCharging)
    onCurrentProfileStringChanged: root.profileChanged(root.currentProfileString)
}
