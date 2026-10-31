// Bottom key legend of the full-screen views (Gravity launcher, Alt+Tab, workspaces overview, clipboard ring):
// [KEY] LABEL   [KEY] LABEL …   — keycap in mono on a dark chip, the label in tracked uppercase mono.
// hints: [["ENTER", "abrir"], ["ESC", "cerrar"]]
import QtQuick
import ".."

Row {
    id: root
    property var hints: []
    property real factor: 1

    spacing: 26 * factor

    Repeater {
        model: root.hints
        delegate: Row {
            id: hint
            required property var modelData
            spacing: 10 * root.factor

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 26 * root.factor
                width: Math.max(height, key.implicitWidth + 16 * root.factor)
                radius: 6 * root.factor
                color: Theme.alpha(Theme.text, 0.07)
                UiText {
                    id: key
                    anchors.centerIn: parent
                    text: hint.modelData[0]
                    mono: true
                    size: Theme.sizeCaption * root.factor + 1
                    weight: Theme.weightSemiBold
                    color: Theme.text
                    font.letterSpacing: 1.2 * root.factor
                }
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: hint.modelData[1].toUpperCase()
                mono: true
                size: Theme.sizeCaption * root.factor + 1
                color: Theme.textDim
                font.letterSpacing: 2.4 * root.factor
            }
        }
    }
}
