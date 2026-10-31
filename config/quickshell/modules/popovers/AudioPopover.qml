// Sonido (docs/design/29-paneles-sonido.png): the whole mixer.
//   · general volume as 18 segments (click or drag sets it; up to 150 % with «Refuerzo», the cells past 100 % in amber),
//     «Silenciar» · outputs (speakers, USB, Bluetooth with its battery when the device reports it) · microphones with
//     their volume and a LIVE level meter (Quickshell's PwNodePeakMonitor, only while the panel is open) · «Supresión
//     de ruido» when a noise filter source exists (filter-chain / rnnoise / EasyEffects; hidden otherwise) · volume and
//     mute per application.
//   · No equaliser: PipeWire has no EQ of its own and the clean ways (EasyEffects presets, a filter-chain per profile)
//     need an extra service and config the shell would have to own — left out on purpose (HANDOFF 8h).
// The switch in the header is mute (on = sound). Right click on the bar's volume capsule opens it (left = mute).
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Sonido"

    property bool boost: Audio.volume > 1.001

    headerRight: ToggleSwitch { checked: !Audio.muted; enabled: Audio.sink !== null; onToggled: Audio.toggleMute() }

    function btBattery(node): int {
        if (Audio.kindOf(node) !== "bluetooth") return -1;
        const desc = (node?.description ?? "").toLowerCase();
        const d = Bluetooth.connectedDevices.find(x => desc.indexOf((x.name || "").toLowerCase()) >= 0);
        return d ? Bluetooth.batteryPct(d) : -1;
    }

    // ---- general volume ----
    HudCard {
        spacing: Theme.spacingMd
        RowLayout {
            Layout.fillWidth: true
            HudCaption { Layout.fillWidth: true; text: "Volumen general" }
            UiText { text: Audio.muted ? "—" : Audio.volumePct; mono: true; size: Theme.sizeTitle + 2; weight: Theme.weightSemiBold; color: Audio.volume > 1.001 ? Theme.warn : Theme.text }
            UiText { text: "%"; mono: true; size: Theme.sizeCaption + 1; color: Theme.textDim; visible: !Audio.muted }
        }
        SegmentBar {
            Layout.fillWidth: true
            segHeight: 20
            segments: root.boost ? 27 : 18
            max: root.boost ? Audio.boostMax : 1
            value: Audio.muted ? 0 : Audio.volume
            color: Theme.cyan
            fill: root.filled
            interactive: Audio.sink !== null
            onMoved: v => { if (Audio.muted) Audio.toggleMute(); Audio.setVolumeBoost(v); }
        }
        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingXs + 2
            HudChip { label: Audio.muted ? "Activar sonido" : "Silenciar"; active: Audio.muted; onClicked: Audio.toggleMute() }
            HudChip { label: "Refuerzo 150 %"; active: root.boost; onClicked: { root.boost = !root.boost; if (!root.boost && Audio.volume > 1) Audio.setVolumeBoost(1); } }
        }
    }

    // ---- outputs ----
    HudCaption { text: "Salida" }
    UiText { visible: Audio.sinks.length === 0; text: Audio.ready ? "No hay dispositivos de salida" : "Conectando con PipeWire…"; color: Theme.textDim }
    Repeater {
        model: Audio.sinks
        delegate: HudRow {
            required property var modelData
            readonly property int battery: root.btBattery(modelData)
            title: Audio.nodeName(modelData)
            detail: Audio.detailOf(modelData)
            selected: modelData === Audio.sink
            leading: RadioDot { checked: modelData === Audio.sink }
            UiText { visible: battery >= 0; text: `${battery} %`; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft }
            onClicked: Audio.setDefaultSink(modelData)
        }
    }

    // ---- microphones ----
    HudCaption { text: "Entrada · micrófonos"; visible: Audio.sources.length > 0 }
    Repeater {
        model: Audio.sources
        delegate: HudRow {
            id: micRow
            required property var modelData
            readonly property bool current: modelData === Audio.source || (Audio.noiseSuppression && modelData === Audio._lastHardwareSource)
            implicitHeight: Theme.hudRow + 14
            selected: current
            leading: RadioDot { checked: micRow.current }
            title: Audio.nodeName(modelData)
            onClicked: Audio.setDefaultSource(modelData)
            UiText { text: `${Math.round((modelData.audio?.volume ?? 0) * 100)} %`; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft }

            // live level under the name (peak of the node, green): only while the panel is open
            PwNodePeakMonitor { id: peak; node: micRow.modelData; enabled: root.shown && !(micRow.modelData.audio?.muted ?? false) }
            SegmentBar {
                parent: micRow
                x: Theme.spacingMd + 26
                y: micRow.height - 12
                width: micRow.width - x - 70
                segHeight: 4
                segments: 24
                value: Math.min(1, Math.sqrt(peak.peak))
                color: Theme.ok
            }
        }
    }
    RowLayout {
        visible: Audio.source !== null
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        HudCaption { text: "Ganancia" }
        SegmentBar {
            Layout.fillWidth: true
            value: Audio.micMuted ? 0 : Audio.micVolume
            color: Theme.lavender
            fill: root.filled
            interactive: true
            onMoved: v => Audio.setMicVolume(v)
        }
        HudChip { label: Audio.micMuted ? "Activar" : "Silenciar"; active: Audio.micMuted; onClicked: Audio.toggleMicMute() }
    }
    RowLayout {
        visible: Audio.noiseFilter !== null
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.hudRow
        UiText { Layout.fillWidth: true; text: "Supresión de ruido"; weight: Theme.weightMedium }
        ToggleSwitch { checked: Audio.noiseSuppression; onToggled: Audio.setNoiseSuppression(!Audio.noiseSuppression) }
    }

    // microphone in use (the bar shows an orange dot on the volume capsule)
    HudRow {
        visible: Privacy.mic
        clickable: false
        title: "Micrófono en uso"
        titleColor: Theme.warn
        detail: Privacy.micApps.join(" · ")
        leading: Glyph { icon: Icons.microphone; size: Theme.iconMd; color: Theme.warn }
    }

    // ---- applications ----
    HudCaption { text: "Aplicaciones" }
    UiText { visible: Audio.streams.length === 0; text: "Ninguna aplicación está reproduciendo audio"; color: Theme.textDim }
    Repeater {
        model: Audio.streams
        delegate: RowLayout {
            id: appRow
            required property var modelData
            readonly property string name: Audio.nodeName(modelData)
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.hudRow - 6
            spacing: Theme.spacingMd
            Rectangle {
                width: 22; height: 22; radius: 6
                color: Theme.hudRowFill
                border.width: 1
                border.color: Theme.hudCardEdge
                UiText { anchors.centerIn: parent; text: appRow.name.charAt(0).toUpperCase(); mono: true; size: Theme.sizeCaption + 1; weight: Theme.weightSemiBold; color: Theme.warn }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Audio.toggleNodeMute(appRow.modelData) }
            }
            UiText { Layout.preferredWidth: 80; text: appRow.name; color: (appRow.modelData.audio?.muted ?? false) ? Theme.textDim : Theme.text }
            SegmentBar {
                Layout.fillWidth: true
                segHeight: 6
                value: (appRow.modelData.audio?.muted ?? false) ? 0 : (appRow.modelData.audio?.volume ?? 0)
                color: Theme.lavender
                fill: root.filled
                interactive: true
                onMoved: v => Audio.setNodeVolume(appRow.modelData, v)
            }
            UiText { Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight; text: (appRow.modelData.audio?.muted ?? false) ? "—" : `${Math.round((appRow.modelData.audio?.volume ?? 0) * 100)}%`; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft }
        }
    }
}
