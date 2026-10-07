// Right column of the calendar popover: notifications (No molestar, cards, "Borrar todo") and updates.
// Scales from 0 to 100 tracked notifications (ListView: only the visible cards are created).
import QtQuick
import Quickshell
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

ColumnLayout {
    id: root
    spacing: Theme.spacingMd

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        UiText { Layout.fillWidth: true; text: "Notificaciones"; size: Theme.sizeTitle; weight: Theme.weightSemiBold }
        UiText { text: "No molestar"; size: Theme.sizeCaption + 1; color: Theme.textDim }
        ToggleSwitch { checked: Notifs.dnd; onToggled: Notifs.toggleDnd() }
    }

    ColumnLayout {
        visible: Notifs.count === 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacingMd
        Layout.bottomMargin: Theme.spacingMd
        spacing: Theme.spacingSm
        Glyph { Layout.alignment: Qt.AlignHCenter; icon: Notifs.dnd ? Icons.bellOff : Icons.bell; size: Theme.sizeHero * 0.7; color: Theme.muted }
        UiText { Layout.alignment: Qt.AlignHCenter; text: "Sin notificaciones"; color: Theme.textDim }
    }

    ListView {
        visible: Notifs.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, Theme.notificationsListHeight)
        clip: true
        spacing: Theme.spacingSm
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel { values: Notifs.notifications; comparisonMode: ObjectComparison.Identity }
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

    // ---- updates ----
    UiText { caption: true; text: "Actualizaciones" }
    Card {
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
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
                UiText {
                    Layout.fillWidth: true
                    visible: Updates.count > 0
                    text: `${Updates.repoCount} repositorios · ${Updates.aurCount} AUR`
                    size: Theme.sizeCaption + 1
                    color: Theme.textDim
                }
            }
            Capsule {
                visible: Updates.count > 0
                brand: true
                onClicked: Updates.run()
                UiText { text: "Actualizar"; size: Theme.sizeCaption + 1; weight: Theme.weightMedium; color: Theme.onBrand; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
