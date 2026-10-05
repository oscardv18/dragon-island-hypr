// Dashboard system card: CPU / RAM / Temp / Disk mini-bars
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Card {
    spacing: Theme.spacingSm + Theme.spacingXs / 2

    UiText { caption: true; text: "Sistema" }

    StatBar {
        Layout.fillWidth: true
        icon: Icons.cpu
        label: "CPU"
        valueText: `${SysStats.cpuPct}%`
        value: SysStats.cpuPct / 100
        color: Theme.cyan
    }
    StatBar {
        Layout.fillWidth: true
        icon: Icons.memory
        label: "RAM"
        valueText: `${SysStats.memUsedGb.toFixed(1)} / ${SysStats.memTotalGb.toFixed(0)} G`
        value: SysStats.memPct / 100
        color: Theme.violetSoft
    }
    StatBar {
        Layout.fillWidth: true
        icon: Icons.thermometer
        label: "Temp"
        valueText: SysStats.tempC >= 0 ? `${SysStats.tempC} °C` : "—"
        value: SysStats.tempC >= 0 ? SysStats.tempC / Theme.tempMaxC : 0
        color: SysStats.tempC >= Theme.tempHotC ? Theme.error : Theme.warn
    }
    StatBar {
        Layout.fillWidth: true
        icon: Icons.disk
        label: "Disco"
        valueText: `${SysStats.diskPct}%`
        value: SysStats.diskPct / 100
        color: Theme.ok
    }
}
