// Notification card (docs/design/28-emergentes.png), the same in the popups and in the notification centre:
//   icon in a ring · title (summary) · mono caption (app · URGENTE) · time on the right · body (plain text, no markup)
//   · actions as HUD chips. Middle click dismisses; a click runs the default action.
// `popup: true` = the card of NotificationWindow: no background of its own (the window traces / fills it) and its
// three rows fade in with `rows` (0 → 1, 45 ms apart). In the centre it has its own HUD card background.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    required property var notification
    property bool popup: false
    property real rows: 1                       // popup: cascade progress of the three rows
    readonly property string iconSrc: Notifs.iconFor(notification)
    readonly property bool critical: Notifs.isCritical(notification)
    readonly property var defaultAction: (notification?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property var buttons: (notification?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property bool hovered: hover.hovered
    signal closeRequested()

    function rowT(i: int): real {
        const step = Theme.durCardStagger / Math.max(1, Theme.durCardStagger * 2 + Theme.durRowIn);
        return Math.max(0, Math.min(1, (root.rows - i * step) / Math.max(0.01, 1 - 2 * step)));
    }

    implicitHeight: col.implicitHeight + Theme.spacingMd * 2
    radius: Theme.hudRadius
    color: popup ? Theme.transparent : (hovered ? Theme.hudRowHover : Theme.hudCard)
    border.width: popup ? 0 : 1
    border.color: critical ? Theme.alpha(Theme.warn, 0.6) : Theme.hudCardEdge
    Behavior on color { ColorAnimation { duration: Theme.durHover } }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.MiddleButton) Notifs.dismiss(root.notification);
            else if (root.defaultAction) Notifs.invokeAction(root.notification, root.defaultAction);
            else if (root.popup) root.closeRequested();
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        // ---- row 1: icon · title + caption · time · close ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd
            opacity: root.rowT(0)
            transform: Translate { y: Theme.hudRowShift * (1 - root.rowT(0)) }

            Rectangle {
                Layout.preferredWidth: Theme.notifIcon
                Layout.preferredHeight: Theme.notifIcon
                Layout.alignment: Qt.AlignTop
                radius: width / 2
                color: Theme.hudRowFill
                border.width: 1
                border.color: root.critical ? Theme.alpha(Theme.warn, 0.6) : Theme.alpha(Theme.cyan, 0.35)
                ClippingRectangle {
                    anchors.centerIn: parent
                    width: parent.width - 10
                    height: width
                    radius: width / 2
                    color: Theme.transparent
                    visible: root.iconSrc.length > 0
                    IconImage { anchors.fill: parent; source: root.iconSrc; asynchronous: true }
                }
                Glyph {
                    anchors.centerIn: parent
                    visible: root.iconSrc.length === 0
                    icon: Icons.bell
                    size: Theme.iconMd
                    color: root.critical ? Theme.warn : Theme.cyan
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                UiText {
                    Layout.fillWidth: true
                    text: root.notification?.summary || root.notification?.appName || "Notificación"
                    weight: Theme.weightSemiBold
                    color: root.critical ? Theme.warn : Theme.text
                }
                HudCaption {
                    Layout.fillWidth: true
                    text: [root.notification?.appName ?? "", root.critical ? "urgente" : ""].filter(s => s.length > 0).join(" · ")
                    color: root.critical ? Theme.warn : Theme.textDim
                }
            }
            HudCaption { Layout.alignment: Qt.AlignTop; text: Notifs.relativeTime(root.notification) }
            IconButton {
                Layout.alignment: Qt.AlignTop
                icon: Icons.close
                size: Theme.capsuleHeight - Theme.spacingXs * 2
                iconSize: Theme.iconSm - 2
                radius: Theme.capsuleRadius
                bgColor: Theme.transparent
                opacity: root.hovered || root.critical ? 1 : 0.4
                onClicked: root.popup ? root.closeRequested() : Notifs.dismiss(root.notification)
            }
        }

        // ---- row 2: body ----
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.notifIcon + Theme.spacingMd
            visible: text.length > 0
            opacity: root.rowT(1)
            transform: Translate { y: Theme.hudRowShift * (1 - root.rowT(1)) }
            text: root.notification?.body ?? ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: root.popup ? 3 : 5
            elide: Text.ElideRight
            color: Theme.textSoft
            font.family: Theme.fontUi
            font.pixelSize: Math.round(Theme.sizeBody)
            lineHeight: 1.15
        }

        // ---- row 3: actions ----
        Flow {
            visible: root.buttons.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Theme.notifIcon + Theme.spacingMd
            spacing: Theme.spacingSm
            opacity: root.rowT(2)
            transform: Translate { y: Theme.hudRowShift * (1 - root.rowT(2)) }
            Repeater {
                model: root.buttons
                delegate: HudChip {
                    required property var modelData
                    required property int index
                    label: modelData.text
                    active: index === 0
                    onClicked: Notifs.invokeAction(root.notification, modelData)
                }
            }
        }
    }
}
