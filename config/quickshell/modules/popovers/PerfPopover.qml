// Rendimiento: per-core bars · RAM / GPU / Temp tiles · top 4 processes · power profile
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Rendimiento"
    popWidth: Theme.popoverWidthLg

    onOpened: SysStats.wantDetails(true)
    onClosed: SysStats.wantDetails(false)

    headerRight: UiText {
        text: `${SysStats.cpuPct}%`
        mono: true
        size: Theme.sizeTitle
        weight: Theme.weightSemiBold
        color: Theme.cyan
    }

    // CPU over the last 30 s (15 samples, 2 s apart)
    Card {
        Layout.fillWidth: true
        UiText { caption: true; text: "CPU · últimos 30 s" }
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 3
            Repeater {
                model: SysStats.cpuHistory
                delegate: Item {
                    required property int modelData
                    width: (parent.width - 14 * 3) / 15
                    height: 36
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * modelData / 100)
                        radius: 2
                        color: modelData > 80 ? Theme.error : (modelData > 50 ? Theme.warn : Theme.cyan)
                        Behavior on height { NumberAnimation { duration: Theme.durHover } }
                    }
                }
            }
        }
    }

    // per-core bars
    Card {
        Layout.fillWidth: true
        UiText { caption: true; text: `Núcleos · ${SysStats.corePcts.length}` }
        GridLayout {
            Layout.fillWidth: true
            columns: SysStats.corePcts.length > 16 ? 8 : 4
            columnSpacing: Theme.spacingSm
            rowSpacing: Theme.spacingXs + 2
            Repeater {
                model: SysStats.corePcts.length
                delegate: ProgressBar {
                    required property int index
                    Layout.fillWidth: true
                    value: (SysStats.corePcts[index] ?? 0) / 100
                    color: (SysStats.corePcts[index] ?? 0) > 85 ? Theme.warn : Theme.cyan
                }
            }
        }
    }

    // RAM / GPU / Temp tiles
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Repeater {
            model: [
                { icon: Icons.memory, label: "RAM", value: `${SysStats.memUsedGb.toFixed(1)} G`, color: Theme.violetSoft, pct: SysStats.memPct },
                { icon: Icons.gpu, label: "GPU", value: SysStats.gpuPct >= 0 ? `${SysStats.gpuPct}%` : "—", color: Theme.accent, pct: Math.max(0, SysStats.gpuPct) },
                { icon: Icons.thermometer, label: "Temp", value: SysStats.tempC >= 0 ? `${SysStats.tempC}°` : "—", color: Theme.warn, pct: Math.max(0, SysStats.tempC) }
            ]
            delegate: Card {
                required property var modelData
                Layout.fillWidth: true
                padding: Theme.spacingMd
                spacing: Theme.spacingXs
                RowLayout {
                    spacing: Theme.spacingXs
                    Glyph { icon: modelData.icon; size: Theme.iconSm; color: modelData.color }
                    UiText { caption: true; text: modelData.label }
                }
                UiText { text: modelData.value; mono: true; size: Theme.sizeTitle; weight: Theme.weightSemiBold }
                ProgressBar { Layout.fillWidth: true; value: modelData.pct / 100; color: modelData.color }
            }
        }
    }

    // top processes
    Card {
        Layout.fillWidth: true
        UiText { caption: true; text: "Procesos" }
        UiText {
            visible: SysStats.topProcs.length === 0
            text: "Cargando…"
            color: Theme.textDim
        }
        Repeater {
            model: SysStats.topProcs
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                UiText { Layout.fillWidth: true; text: modelData.name; color: Theme.textSoft }
                UiText { text: `${modelData.cpu.toFixed(1)}%`; mono: true; size: Theme.sizeCaption + 1; color: Theme.cyan }
                UiText {
                    text: `${modelData.memMb} M`
                    mono: true
                    size: Theme.sizeCaption + 1
                    color: Theme.violetSoft
                    Layout.preferredWidth: Theme.sizeBody * 4
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    Segmented {
        Layout.fillWidth: true
        model: Power.profiles.map(p => Object.assign({ icon: p.key === "power-saver" ? Icons.leaf : (p.key === "performance" ? Icons.rocket : Icons.balance) }, p))
        current: Power.currentProfileKey
        onSelected: key => Power.setProfileByName(key)
    }
}
