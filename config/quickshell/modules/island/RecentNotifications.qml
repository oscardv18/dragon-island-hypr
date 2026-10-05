// Dashboard: last 3 notifications (click → notification center)
import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Card {
    id: root
    property string screenName: ""
    spacing: Theme.spacingSm

    RowLayout {
        Layout.fillWidth: true
        UiText { caption: true; text: "Notificaciones"; Layout.fillWidth: true }
        UiText {
            visible: Notifs.count > 0
            text: `${Notifs.count}`
            mono: true
            size: Theme.sizeCaption
            color: Theme.textDim
        }
    }

    UiText {
        visible: Notifs.count === 0
        text: Notifs.dnd ? "No molestar activado" : "Todo al día"
        color: Theme.textDim
        size: Theme.sizeCaption + 1
    }

    Repeater {
        model: ScriptModel {
            values: Notifs.notifications.slice(0, 3)
            comparisonMode: ObjectComparison.Identity
        }
        delegate: Item {
            id: rowItem
            required property var modelData
            readonly property string iconSrc: Notifs.iconFor(modelData)
            Layout.fillWidth: true
            implicitHeight: Theme.rowHeight - Theme.spacingSm

            Rectangle {
                anchors.fill: parent
                radius: Theme.rowRadius
                color: rowMouse.containsMouse ? Theme.surfaceHi : Theme.surface2
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingSm + 2
                anchors.rightMargin: Theme.spacingSm
                spacing: Theme.spacingSm

                Item {
                    Layout.preferredWidth: Theme.iconLg
                    Layout.preferredHeight: Theme.iconLg
                    IconImage {
                        anchors.fill: parent
                        visible: rowItem.iconSrc.length > 0
                        source: rowItem.iconSrc
                        asynchronous: true
                    }
                    Glyph {
                        anchors.centerIn: parent
                        visible: rowItem.iconSrc.length === 0
                        icon: Icons.bell
                        size: Theme.iconSm
                        color: Theme.textDim
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    UiText {
                        Layout.fillWidth: true
                        text: rowItem.modelData.summary || rowItem.modelData.appName
                        size: Theme.sizeCaption + 1
                        weight: Theme.weightMedium
                    }
                    UiText {
                        Layout.fillWidth: true
                        text: `${rowItem.modelData.appName} · ${Notifs.relativeTime(rowItem.modelData)}`
                        size: Theme.sizeCaption
                        color: Theme.textDim
                    }
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.open("notifications", root.screenName)
            }
        }
    }
}
