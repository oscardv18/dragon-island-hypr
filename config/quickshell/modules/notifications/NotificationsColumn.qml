// The notification centre's body (NotificationsPopover; HUD vocabulary): No molestar, the cards (ListView: only the
// visible ones are created, 0 – 100 tracked), «Borrar todo» and the pending updates.
import QtQuick
import Quickshell
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

ColumnLayout {
    id: root
    property bool framed: false     // inside a PopoverFrame (its header holds the title)
    spacing: Theme.spacingMd

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.hudRow
        spacing: Theme.spacingSm
        Glyph { icon: Notifs.dnd ? Icons.bellOff : Icons.bell; size: Theme.iconMd; color: Notifs.dnd ? Theme.warn : Theme.textSoft }
        UiText { Layout.fillWidth: true; text: "No molestar"; weight: Theme.weightMedium }
        HudCaption { visible: Notifs.dnd; text: "silencio"; color: Theme.warn }
        ToggleSwitch { checked: Notifs.dnd; onToggled: Notifs.toggleDnd() }
    }

    Item {
        visible: Notifs.count === 0
        Layout.fillWidth: true
        implicitHeight: emptyCol.implicitHeight + Theme.spacingMd * 2
        Column {
            id: emptyCol
            anchors.centerIn: parent
            spacing: Theme.spacingSm
            Glyph { anchors.horizontalCenter: parent.horizontalCenter; icon: Notifs.dnd ? Icons.bellOff : Icons.bell; size: Theme.sizeHero * 0.7; color: Theme.muted }
            UiText { anchors.horizontalCenter: parent.horizontalCenter; text: "Sin notificaciones"; color: Theme.textDim }
        }
    }

    ListView {
        visible: Notifs.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Theme.notificationsListHeight)
        clip: true
        spacing: Theme.spacingSm
        boundsBehavior: Flickable.StopAtBounds
        // Notifs.entries: single cards, and one card per group (captures, or an app with 3 or more)
        model: Notifs.entries
        delegate: Loader {
            required property var modelData
            width: ListView.view.width
            sourceComponent: modelData.group ? groupCard : singleCard
            Component { id: singleCard; NotificationCard { notification: modelData.n; opacity: modelData.inGroup ? 0.85 : 1 } }
            Component { id: groupCard; NotificationGroup { entry: modelData } }
        }
    }

    RowLayout {
        visible: Notifs.count > 0
        Layout.fillWidth: true
        HudCaption { Layout.fillWidth: true; text: Notifs.count === 1 ? "1 notificación" : `${Notifs.count} notificaciones` }
        HudChip { label: "Borrar todo"; icon: Icons.broom; onClicked: Notifs.clearAll() }
    }

    // ---- updates ----
    HudCaption { text: "Actualizaciones" }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: updRow.implicitHeight + Theme.spacingMd * 2
        radius: Theme.hudCardRadius
        color: Theme.hudCard
        border.width: 1
        border.color: Theme.hudCardEdge
        RowLayout {
            id: updRow
            anchors.fill: parent
            anchors.margins: Theme.spacingMd
            spacing: Theme.spacingSm
            Glyph { icon: Icons.update; size: Theme.iconLg; color: Updates.count > 0 ? Theme.cyan : Theme.ok }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                UiText {
                    Layout.fillWidth: true
                    text: Updates.checking ? "Buscando…" : (Updates.count === 0 ? "Todo al día" : (Updates.count === 1 ? "1 actualización" : `${Updates.count} actualizaciones`))
                    weight: Theme.weightSemiBold
                }
                HudCaption {
                    Layout.fillWidth: true
                    visible: Updates.count > 0
                    text: `${Updates.repoCount} repositorios · ${Updates.aurCount} AUR`
                }
            }
            HudChip { visible: Updates.count > 0; label: "Actualizar"; active: true; onClicked: Updates.run() }
        }
    }
}
