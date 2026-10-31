// Batería (HUD): charge by segments · time remaining · consumption in watts · health · the power profile on the sliding
// pill · screen brightness, one segmented bar per controllable screen (the built-in backlight and every DDC/CI monitor
// that ddcutil found; click / drag / wheel sets it, DDC writes are debounced by services/Brightness.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Batería"
    live: Power.hasBattery

    property string screenName: ""

    readonly property color tone: Power.isCharging ? Theme.ok
                                 : (Power.batteryPct <= 10 ? Theme.error : (Power.isLow ? Theme.warn : Theme.ok))
    // every screen whose brightness can be set: the built-in panel (backlight) and the DDC monitors
    readonly property var screens: {
        const list = [];
        for (const s of Quickshell.screens) if (Brightness.controllableOn(s.name)) list.push({ name: s.name, ddc: Brightness.ddcDisplays.some(d => d.connector === s.name) });
        return list;
    }

    UiText { visible: !Power.hasBattery; Layout.fillWidth: true; text: "Este equipo no tiene batería"; color: Theme.textDim }

    HudCard {
        visible: Power.hasBattery
        spacing: Theme.spacingMd
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd
            Row {
                Text { text: Power.batteryPct; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.sizeHero - 6; font.weight: Theme.weightSemiBold }
                Text { text: "%"; color: Theme.textDim; font.family: Theme.fontMono; font.pixelSize: Theme.sizeTitle; anchors.baseline: parent.children[0].baseline }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                UiText { Layout.fillWidth: true; text: Power.stateString; weight: Theme.weightMedium; color: root.tone }
                HudCaption { Layout.fillWidth: true; text: Power.timeRemainingFormatted.length > 0 ? (Power.isCharging ? `llena en ${Power.timeRemainingFormatted}` : `quedan ${Power.timeRemainingFormatted}`) : "" }
            }
            Glyph { icon: Power.isCharging ? Icons.batteryCharging : Icons.bolt; size: Theme.iconLg; color: root.tone }
        }
        SegmentBar { Layout.fillWidth: true; segHeight: 14; segments: 20; value: Power.batteryFraction; color: root.tone; fill: root.filled }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacingMd
            rowSpacing: 1
            HudCaption { text: "Consumo" }
            HudCaption { text: "Salud" }
            UiText { text: Power.changeRateWatts > 0 ? `${Power.changeRateWatts.toFixed(1).replace(".", ",")} W` : "—"; mono: true; weight: Theme.weightSemiBold }
            UiText { text: Power.healthPct >= 0 ? `${Math.round(Power.healthPct)} %` : "—"; mono: true; weight: Theme.weightSemiBold }
        }
    }

    // ---- brightness ----
    HudCaption { visible: root.screens.length > 0; text: "Brillo" }
    Repeater {
        model: root.screens
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.spacingMd
            Glyph { icon: Icons.sun; size: Theme.iconMd; color: Theme.sunWarm }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    HudCaption { Layout.fillWidth: true; text: modelData.ddc ? `${modelData.name} · DDC` : (root.screens.length > 1 ? `${modelData.name} · pantalla interna` : "Pantalla") }
                    UiText { text: `${Math.round(Brightness.levelFor(modelData.name) * 100)} %`; mono: true; size: Theme.sizeCaption + 1 }
                }
                SegmentBar {
                    Layout.fillWidth: true
                    value: Brightness.levelFor(modelData.name)
                    color: Theme.sunWarm
                    fill: root.filled
                    interactive: true
                    onMoved: v => Brightness.setLevelFor(modelData.name, Math.max(0.05, v))
                }
            }
        }
    }

    // ---- power profile ----
    HudCaption { visible: Power.hasPerformanceProfile; text: "Perfil de energía" }
    Segmented {
        Layout.fillWidth: true
        visible: Power.hasPerformanceProfile
        model: Power.profiles.map(p => ({ key: p.key, label: p.key === "power-saver" ? "Ahorro" : (p.key === "performance" ? "Rendimiento" : "Equilibrado"), available: p.available }))
        current: Power.currentProfileKey
        onSelected: key => Power.setProfileByName(key)
    }
}
