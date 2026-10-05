// Notification card: icon · title · body · app · time · actions · dismiss
// Bodies are rendered as plain text (no markup injection).
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    required property var notification
    property bool popup: false          // popup style: popover background + border
    readonly property string iconSrc: Notifs.iconFor(notification)
    readonly property bool critical: Notifs.isCritical(notification)
    readonly property var defaultAction: (notification?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property var buttons: (notification?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property bool hovered: hover.hovered

    implicitHeight: col.implicitHeight + Theme.spacingMd * 2
    radius: Theme.rowRadius + Theme.spacingXs
    color: popup ? Theme.popoverBg : (hovered ? Theme.surfaceHi : Theme.surface2)
    border.width: popup || critical ? 1 : 0
    border.color: critical ? Theme.alpha(Theme.error, 0.6) : Theme.hairline
    Behavior on color { ColorAnimation { duration: Theme.durHover } }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.MiddleButton) Notifs.dismiss(root.notification);
            else if (root.defaultAction) Notifs.invokeAction(root.notification, root.defaultAction);
            else if (root.popup) Notifs.dismissPopup(root.notification);
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm + 2

            Item {
                Layout.preferredWidth: Theme.notifIcon
                Layout.preferredHeight: Theme.notifIcon
                Layout.alignment: Qt.AlignTop
                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.capsuleRadius
                    color: Theme.surface3
                    visible: root.iconSrc.length > 0
                    IconImage {
                        anchors.fill: parent
                        source: root.iconSrc
                        asynchronous: true
                    }
                }
                Glyph {
                    anchors.centerIn: parent
                    visible: root.iconSrc.length === 0
                    icon: Icons.bell
                    size: Theme.iconLg
                    color: root.critical ? Theme.error : Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXs / 2

                UiText {
                    Layout.fillWidth: true
                    text: root.notification?.summary || root.notification?.appName || "Notificación"
                    weight: Theme.weightSemiBold
                    color: root.critical ? Theme.error : Theme.text
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.notification?.body ?? ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.popup ? 3 : 5
                    elide: Text.ElideRight
                    color: Theme.textSoft
                    font.family: Theme.fontUi
                    font.pixelSize: Math.round(Theme.sizeBody)
                }
                UiText {
                    Layout.fillWidth: true
                    text: [root.notification?.appName ?? "", Notifs.relativeTime(root.notification)].filter(s => s.length > 0).join(" · ")
                    size: Theme.sizeCaption
                    color: Theme.textDim
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignTop
                icon: Icons.close
                size: Theme.capsuleHeight - Theme.spacingXs
                iconSize: Theme.iconSm
                radius: Theme.capsuleRadius
                bgColor: Theme.transparent
                opacity: root.hovered || root.critical ? 1 : 0.5
                onClicked: Notifs.dismiss(root.notification)
            }
        }

        // action buttons
        Flow {
            visible: root.buttons.length > 0
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Repeater {
                model: root.buttons
                delegate: Capsule {
                    required property var modelData
                    onClicked: Notifs.invokeAction(root.notification, modelData)
                    UiText {
                        text: modelData.text
                        size: Theme.sizeCaption + 1
                        weight: Theme.weightMedium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
