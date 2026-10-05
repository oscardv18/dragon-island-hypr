// Batería: big % · time remaining · bar · consumption (W) · health · brightness · profile
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Batería"

    readonly property color tone: Power.isCharging ? Theme.ok
                                 : (Power.batteryPct <= 10 ? Theme.error : (Power.isLow ? Theme.warn : Theme.ok))

    UiText {
        visible: !Power.hasBattery
        Layout.fillWidth: true
        text: "Este equipo no tiene batería"
        color: Theme.textDim
    }

    RowLayout {
        visible: Power.hasBattery
        Layout.fillWidth: true
        spacing: Theme.spacingMd

        UiText {
            text: `${Power.batteryPct}%`
            mono: true
            size: Theme.sizeHero
            weight: Theme.weightBold
            color: root.tone
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXs / 2
            RowLayout {
                spacing: Theme.spacingXs
                Glyph { icon: Power.isCharging ? Icons.bolt : Icons.batteryFor(Power.batteryPct, false); size: Theme.iconMd; color: root.tone }
                UiText { text: Power.stateString; weight: Theme.weightMedium }
            }
            UiText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: Power.timeRemainingFormatted
                color: Theme.textDim
            }
        }
    }

    ProgressBar {
        visible: Power.hasBattery
        Layout.fillWidth: true
        thickness: Theme.trackHeight * 1.6
        value: Power.batteryFraction
        color: root.tone
    }

    RowLayout {
        visible: Power.hasBattery
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Card {
            Layout.fillWidth: true
            padding: Theme.spacingMd
            spacing: Theme.spacingXs
            UiText { caption: true; text: "Consumo" }
            UiText { text: Power.changeRateWatts > 0 ? `${Power.changeRateWatts.toFixed(1)} W` : "—"; mono: true; size: Theme.sizeTitle; weight: Theme.weightSemiBold }
        }
        Card {
            Layout.fillWidth: true
            padding: Theme.spacingMd
            spacing: Theme.spacingXs
            UiText { caption: true; text: "Salud" }
            UiText { text: Power.healthPct >= 0 ? `${Math.round(Power.healthPct)}%` : "—"; mono: true; size: Theme.sizeTitle; weight: Theme.weightSemiBold }
        }
    }

    Card {
        visible: Brightness.available
        Layout.fillWidth: true
        UiText { caption: true; text: "Brillo" }
        Slider {
            Layout.fillWidth: true
            icon: Icons.sun
            value: Brightness.brightnessReal
            onMoved: v => Brightness.setBrightnessReal(v)
        }
    }

    UiText { caption: true; text: "Perfil de energía" }
    Segmented {
        Layout.fillWidth: true
        model: Power.profiles.map(p => Object.assign({ icon: p.key === "power-saver" ? Icons.leaf : (p.key === "performance" ? Icons.rocket : Icons.balance) }, p))
        current: Power.currentProfileKey
        onSelected: key => Power.setProfileByName(key)
    }
}
