// Agentes: the agents running in herdr, with their state; click one to jump to it (Herdr service)
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Agentes"
    popWidth: Theme.popoverWidthSm + 40

    readonly property var look: ({
        working: { text: "trabajando",    icon: Icons.bolt,     color: Theme.cyan },
        blocked: { text: "te necesita",   icon: Icons.bellRing, color: Theme.warn },
        done:    { text: "terminó",       icon: Icons.check,    color: Theme.ok },
        idle:    { text: "en espera",     icon: Icons.dots,     color: Theme.textSoft },
        unknown: { text: "sin clasificar", icon: Icons.dots,    color: Theme.textDim }
    })

    Repeater {
        model: Herdr.agents
        delegate: Rectangle {
            id: rowItem
            required property var modelData
            readonly property var st: root.look[modelData.state] ?? root.look.unknown
            Layout.fillWidth: true
            implicitHeight: line.implicitHeight + Theme.spacingSm * 2
            radius: Theme.radiusCard - 4
            color: rowMouse.containsMouse ? Theme.surfaceHi : Theme.surface2
            Behavior on color { ColorAnimation { duration: Theme.durHover } }

            RowLayout {
                id: line
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.spacingSm }
                spacing: Theme.spacingSm
                Glyph { icon: rowItem.st.icon; size: Theme.iconMd; color: rowItem.st.color }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    UiText { Layout.fillWidth: true; text: rowItem.modelData.name; weight: Theme.weightSemiBold; elide: Text.ElideRight }
                    UiText {
                        Layout.fillWidth: true
                        text: `${rowItem.modelData.workspace} · ${rowItem.st.text}`
                        color: Theme.textDim
                        size: Theme.sizeCaption + 1
                        elide: Text.ElideRight
                    }
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { ShellState.close(); Herdr.focusAgent(rowItem.modelData); }
            }
        }
    }

    UiText {
        visible: Herdr.agents.length === 0
        Layout.fillWidth: true
        text: "No hay agentes en herdr"
        color: Theme.textDim
    }
}
