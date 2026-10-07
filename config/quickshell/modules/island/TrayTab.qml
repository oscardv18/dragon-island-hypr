// Tray tab: the system tray (StatusNotifierItems). Left = activate (or menu if the item only has one),
// right = menu (QsMenuAnchor), middle = secondary, wheel = scroll. Logic lives in services/Tray.qml.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        visible: !Tray.hasItems
        spacing: Theme.spacingXs
        Glyph { Layout.alignment: Qt.AlignHCenter; icon: Icons.apps; size: Theme.iconLg + Theme.spacingSm; color: Theme.muted }
        UiText { Layout.alignment: Qt.AlignHCenter; text: "Sin aplicaciones en la bandeja"; color: Theme.textDim }
    }

    Flow {
        anchors.fill: parent
        spacing: Theme.spacingSm
        visible: Tray.hasItems

        Repeater {
            model: ScriptModel {
                values: Tray.items
                comparisonMode: ObjectComparison.Identity
            }
            delegate: Item {
                id: trayItem
                required property var modelData
                // Apps swap icons (e.g. VPN connected): retry the primary source each time
                readonly property string rawIcon: modelData.icon
                property bool iconFailed: false
                onRawIconChanged: iconFailed = false
                width: Theme.notchTile + Theme.spacingSm
                height: Theme.notchTile + Theme.spacingSm

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.tileRadius - 4
                    color: trayMouse.containsMouse || menuAnchor.visible ? Theme.surfaceHi : Theme.surface2
                    Behavior on color { ColorAnimation { duration: Theme.durHover } }
                }
                IconImage {
                    anchors.centerIn: parent
                    source: Tray.iconSource(trayItem.modelData, trayItem.iconFailed)
                    implicitSize: Theme.iconLg + Theme.spacingXs
                    asynchronous: true
                    onStatusChanged: if (status === Image.Error) trayItem.iconFailed = true
                }
                Rectangle {
                    visible: Tray.needsAttention(trayItem.modelData)
                    width: Theme.pillDot + 2
                    height: width
                    radius: width / 2
                    color: Theme.warn
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingXs
                }

                Item {
                    id: menuSpot
                    y: trayItem.height + Theme.popoverGap
                    width: trayItem.width
                }
                QsMenuAnchor {
                    id: menuAnchor
                    menu: trayItem.modelData.menu
                    anchor.item: menuSpot
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: m => {
                        if (m.button === Qt.RightButton) Tray.openMenu(menuAnchor);
                        else if (m.button === Qt.MiddleButton) Tray.secondaryActivate(trayItem.modelData);
                        else Tray.click(trayItem.modelData, menuAnchor);
                    }
                    onWheel: w => Tray.scroll(trayItem.modelData, w.angleDelta.x, w.angleDelta.y)
                }
            }
        }
    }
}
