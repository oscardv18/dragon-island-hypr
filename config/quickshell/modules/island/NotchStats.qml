// System stats: CPU / RAM / Temp / Disco as one row of compact bars
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

GridLayout {
    columns: 4
    columnSpacing: Theme.spacingMd
    rowSpacing: Theme.spacingXs
    uniformCellWidths: true

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
        valueText: `${SysStats.memUsedGb.toFixed(1)} G`
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
