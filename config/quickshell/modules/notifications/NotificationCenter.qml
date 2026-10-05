// Notificaciones (bell popover): DND toggle · cards · "Borrar todo"
// Scales from 0 to 100 tracked notifications (ListView, only visible cards are created).
import QtQuick
import Quickshell
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Notificaciones"
    popWidth: Theme.popoverWidthLg

    onOpened: Notifs.markAllRead()
    onClosed: Notifs.markAllRead()

    headerRight: Row {
        spacing: Theme.spacingSm
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: "No molestar"
            size: Theme.sizeCaption + 1
            color: Theme.textDim
        }
        ToggleSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: Notifs.dnd
            onToggled: Notifs.toggleDnd()
        }
    }

    ColumnLayout {
        visible: Notifs.count === 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacingLg
        Layout.bottomMargin: Theme.spacingLg
        spacing: Theme.spacingSm
        Glyph {
            Layout.alignment: Qt.AlignHCenter
            icon: Notifs.dnd ? Icons.bellOff : Icons.bell
            size: Theme.sizeHero * 0.8
            color: Theme.muted
        }
        UiText {
            Layout.alignment: Qt.AlignHCenter
            text: "Sin notificaciones"
            color: Theme.textDim
        }
    }

    ListView {
        id: list
        visible: Notifs.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Theme.popoverMaxListHeight)
        clip: true
        spacing: Theme.spacingSm
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: Notifs.notifications
            comparisonMode: ObjectComparison.Identity
        }
        delegate: NotificationCard {
            required property var modelData
            width: ListView.view.width
            notification: modelData
        }
    }

    RowLayout {
        visible: Notifs.count > 0
        Layout.fillWidth: true
        UiText {
            Layout.fillWidth: true
            text: Notifs.count === 1 ? "1 notificación" : `${Notifs.count} notificaciones`
            size: Theme.sizeCaption + 1
            color: Theme.textDim
        }
        Capsule {
            onClicked: Notifs.clearAll()
            Glyph { icon: Icons.broom; size: Theme.iconSm; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
            UiText { text: "Borrar todo"; size: Theme.sizeCaption + 1; weight: Theme.weightMedium; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
