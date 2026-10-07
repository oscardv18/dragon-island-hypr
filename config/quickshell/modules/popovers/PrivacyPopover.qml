// Privacidad: which apps are using the microphone, the camera or a screen share (Privacy service, PipeWire)
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Privacidad"
    popWidth: Theme.popoverWidthSm

    readonly property var labels: ({
        mic:    { text: "Micrófono",           icon: Icons.microphone,  color: Theme.warn },
        camera: { text: "Cámara",              icon: Icons.webcam,      color: Theme.ok },
        screen: { text: "Pantalla compartida", icon: Icons.screenShare, color: Theme.warn }
    })

    UiText {
        visible: !Privacy.active
        Layout.fillWidth: true
        text: "Ninguna app usa el micrófono, la cámara ni comparte la pantalla"
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        color: Theme.textDim
    }

    Repeater {
        model: Privacy.kinds
        delegate: Card {
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                Glyph { icon: root.labels[modelData.key].icon; size: Theme.iconMd; color: root.labels[modelData.key].color }
                UiText { Layout.fillWidth: true; text: root.labels[modelData.key].text; weight: Theme.weightSemiBold }
            }
            Repeater {
                model: modelData.apps
                delegate: UiText {
                    required property string modelData
                    Layout.fillWidth: true
                    text: modelData
                    color: Theme.textSoft
                }
            }
        }
    }
}
