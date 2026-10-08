// Apps tab of the dashboard: apps that are closed-but-alive (tray + windows in other workspaces + watched processes),
// from services/BackgroundApps.qml. Click = focus / activate / open · middle = secondary · right or ⋮ = the app's own
// tray menu (OBS, Telegram… put their actions there, e.g. start/stop recording) · ✕ closes its windows.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    // the process table is only read while this tab is open
    Component.onCompleted: BackgroundApps.setWatching(true)
    Component.onDestruction: BackgroundApps.setWatching(false)

    property var menuEntry: null
    property Item menuSpot: null

    QsMenuAnchor {
        id: trayMenu
        menu: root.menuEntry?.trayItem?.menu ?? null
        anchor.item: root.menuSpot
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: BackgroundApps.count === 0
        spacing: Theme.spacingXs
        Glyph { Layout.alignment: Qt.AlignHCenter; icon: Icons.apps; size: Theme.iconLg + Theme.spacingSm; color: Theme.muted }
        UiText { Layout.alignment: Qt.AlignHCenter; text: "Sin apps en segundo plano"; color: Theme.textDim }
    }

    Flickable {
        anchors.fill: parent
        visible: BackgroundApps.count > 0
        contentWidth: width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: grid
            width: parent.width
            columns: 2
            columnSpacing: Theme.spacingSm
            rowSpacing: Theme.spacingSm

            Repeater {
                model: ScriptModel { values: BackgroundApps.entries; objectProp: "key" }
                delegate: AppRow {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    entry: modelData
                    iconSource: BackgroundApps.icon(modelData, false)
                    fallbackSource: BackgroundApps.icon(modelData, true)
                    stateText: BackgroundApps.stateText(modelData)
                    menuOpen: trayMenu.visible && root.menuEntry?.key === modelData.key
                    onActivated: { root.menuEntry = modelData; root.menuSpot = row; BackgroundApps.activate(modelData, trayMenu); }
                    onSecondary: BackgroundApps.secondaryActivate(modelData)
                    onScrolled: (dx, dy) => BackgroundApps.scroll(modelData, dx, dy)
                    onCloseRequested: BackgroundApps.closeWindows(modelData)
                    onMenuRequested: {
                        if (!modelData.trayItem?.hasMenu) return;
                        root.menuEntry = modelData;
                        root.menuSpot = row;
                        if (trayMenu.visible) trayMenu.close(); else trayMenu.open();
                    }
                }
            }
        }
    }
}
