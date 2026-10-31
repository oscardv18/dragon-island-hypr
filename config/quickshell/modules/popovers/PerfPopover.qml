// Rendimiento (docs/design/28-emergentes.png / 28.1): the 270° CPU dial with ticks · RAM / GPU / TEMP as segmented
// bars (lavender, cyan, amber) · CPU area chart of the last 60 s · cores as heat cells (6 per row, with their number) ·
// top processes with a thin bar, CPU and memory · the power profile on the sliding pill.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Rendimiento"
    live: true

    onOpened: SysStats.wantDetails(true)
    onClosed: SysStats.wantDetails(false)

    function heat(p: int): color {
        if (p >= 70) return Theme.warn;
        if (p >= 40) return Theme.lavender;
        return Theme.cyan;
    }

    // ---- dial + RAM / GPU / TEMP ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingLg

        GaugeDial {
            Layout.alignment: Qt.AlignVCenter
            value: SysStats.cpuPct / 100
            label: "CPU"
            fill: root.filled
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacingMd
            Repeater {
                model: [
                    { label: "RAM", value: `${SysStats.memUsedGb.toFixed(1).replace(".", ",")} / ${Math.round(SysStats.memTotalGb)} G`, pct: SysStats.memPct, color: Theme.lavender },
                    { label: "GPU", value: SysStats.gpuPct >= 0 ? `${SysStats.gpuPct} %` : "—", pct: Math.max(0, SysStats.gpuPct), color: Theme.cyan },
                    { label: "Temp", value: SysStats.tempC >= 0 ? `${SysStats.tempC} °C` : "—", pct: Math.max(0, Math.min(100, SysStats.tempC * 100 / Theme.tempMaxC)), color: Theme.warn }
                ]
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spacingXs + 1
                    RowLayout {
                        Layout.fillWidth: true
                        HudCaption { Layout.fillWidth: true; text: modelData.label }
                        UiText { text: modelData.value; mono: true; size: Theme.sizeBody; weight: Theme.weightSemiBold }
                    }
                    SegmentBar { Layout.fillWidth: true; value: modelData.pct / 100; color: modelData.color; fill: root.filled }
                }
            }
        }
    }

    // ---- CPU · 60 s ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2
        RowLayout {
            Layout.fillWidth: true
            HudCaption { Layout.fillWidth: true; text: "CPU · 60 s" }
            HudCaption { text: `máx ${Math.max(0, ...SysStats.cpuHistory)}%` }
        }
        AreaChart { Layout.fillWidth: true; samples: SysStats.cpuHistory; max: 100; fill: root.filled }
    }

    // ---- cores: heat cells ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2
        HudCaption { text: `Núcleos · ${SysStats.corePcts.length}` }
        GridLayout {
            Layout.fillWidth: true
            columns: Theme.hudCellsPerRow
            columnSpacing: Theme.spacingXs + 1
            rowSpacing: Theme.spacingXs + 1
            Repeater {
                model: SysStats.corePcts.length
                delegate: Rectangle {
                    required property int index
                    readonly property int pct: SysStats.corePcts[index] ?? 0
                    readonly property color tone: root.heat(pct)
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.hudCell
                    radius: Theme.hudSegRadius * 3
                    color: Theme.alpha(tone, (0.10 + 0.40 * pct / 100) * root.filled)
                    border.width: 1
                    border.color: Theme.alpha(tone, 0.30)
                    Behavior on color { ColorAnimation { duration: Theme.durStd } }
                    UiText {
                        anchors.centerIn: parent
                        text: parent.pct
                        mono: true
                        size: Theme.sizeCaption
                        color: parent.pct >= 70 ? Theme.text : Theme.textSoft
                    }
                }
            }
        }
    }

    // ---- processes ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs
        HudCaption { text: "Procesos" }
        UiText { visible: SysStats.topProcs.length === 0; text: "Cargando…"; color: Theme.textDim }
        Repeater {
            model: SysStats.topProcs
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.hudRow - 10
                spacing: Theme.spacingMd
                UiText { Layout.preferredWidth: 96; text: modelData.name; color: Theme.textSoft }
                Item {
                    Layout.fillWidth: true
                    height: 3
                    Rectangle { anchors.fill: parent; radius: 1.5; color: Theme.hudSegOff }
                    Rectangle {
                        width: parent.width * Math.min(1, modelData.cpu / 100) * root.filled
                        height: parent.height
                        radius: 1.5
                        color: Theme.cyan
                        Behavior on width { NumberAnimation { duration: Theme.durStd } }
                    }
                }
                UiText { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: `${modelData.cpu.toFixed(1).replace(".", ",")}%`; mono: true; size: Theme.sizeCaption + 1; color: Theme.cyan }
                UiText { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: modelData.memMb >= 1024 ? `${(modelData.memMb / 1024).toFixed(1).replace(".", ",")} G` : `${modelData.memMb} M`; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft }
            }
        }
    }

    // ---- power profile ----
    Segmented {
        Layout.fillWidth: true
        visible: Power.hasPerformanceProfile
        model: Power.profiles.map(p => ({ key: p.key, label: p.key === "power-saver" ? "Ahorro" : (p.key === "performance" ? "Rendimiento" : "Equilibrado"), available: p.available }))
        current: Power.currentProfileKey
        onSelected: key => Power.setProfileByName(key)
    }
}
