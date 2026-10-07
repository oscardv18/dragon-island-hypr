// Sonido: output + mic sliders · output devices (active = accent dot) · per-app mixer
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Sonido"

    headerRight: UiText {
        text: Audio.muted ? "Silenciado" : `${Audio.volumePct}%`
        mono: !Audio.muted
        color: Audio.muted ? Theme.textDim : Theme.textSoft
    }

    Card {
        Layout.fillWidth: true
        spacing: Theme.spacingMd

        Slider {
            Layout.fillWidth: true
            icon: Icons.volumeFor(Audio.volume, Audio.muted)
            value: Audio.volume
            dimmed: Audio.muted
            enabled: Audio.sink !== null
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()
        }
        Slider {
            Layout.fillWidth: true
            icon: Audio.micMuted ? Icons.micOff : Icons.mic
            value: Audio.micVolume
            dimmed: Audio.micMuted
            enabled: Audio.source !== null
            onMoved: v => Audio.setMicVolume(v)
            onIconClicked: Audio.toggleMicMute()
        }
    }

    // microphone in use (the bar shows an orange dot on the volume capsule)
    Card {
        visible: Privacy.mic
        Layout.fillWidth: true
        spacing: Theme.spacingXs
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            Glyph { icon: Icons.microphone; size: Theme.iconMd; color: Theme.warn }
            UiText { Layout.fillWidth: true; text: "Micrófono en uso"; weight: Theme.weightSemiBold }
        }
        Repeater {
            model: Privacy.micApps
            delegate: UiText {
                required property string modelData
                Layout.fillWidth: true
                text: modelData
                color: Theme.textSoft
            }
        }
    }

    UiText { caption: true; text: "Salida" }
    UiText {
        visible: Audio.sinks.length === 0
        text: Audio.ready ? "No hay dispositivos de salida" : "Conectando con PipeWire…"
        color: Theme.textDim
    }
    Repeater {
        model: Audio.sinks
        delegate: ListRow {
            required property var modelData
            Layout.fillWidth: true
            icon: Icons.speaker
            title: Audio.nodeName(modelData)
            active: modelData === Audio.sink
            onClicked: Audio.setDefaultSink(modelData)
        }
    }

    UiText { caption: true; text: "Aplicaciones" }
    UiText {
        visible: Audio.streams.length === 0
        text: "Ninguna aplicación está reproduciendo audio"
        color: Theme.textDim
    }
    Repeater {
        model: Audio.streams
        delegate: Rectangle {
            id: streamRow
            required property var modelData
            readonly property string iconName: Audio.nodeIcon(modelData)
            Layout.fillWidth: true
            implicitHeight: Theme.rowHeight + Theme.spacingMd
            radius: Theme.rowRadius
            color: Theme.surface2

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingMd
                anchors.topMargin: Theme.spacingXs + 2
                anchors.bottomMargin: Theme.spacingXs
                spacing: 0

                UiText {
                    Layout.fillWidth: true
                    text: Audio.nodeName(streamRow.modelData)
                    size: Theme.sizeCaption + 1
                    weight: Theme.weightMedium
                }
                Slider {
                    Layout.fillWidth: true
                    icon: streamRow.modelData.audio?.muted ? Icons.volumeOff : Icons.volumeHigh
                    value: streamRow.modelData.audio?.volume ?? 0
                    dimmed: streamRow.modelData.audio?.muted ?? false
                    onMoved: v => Audio.setNodeVolume(streamRow.modelData, v)
                    onIconClicked: Audio.toggleNodeMute(streamRow.modelData)
                }
            }
        }
    }
}
