// Expanded notch content (NotchNook layout): top row = tabs "Nook | Tray" (left) and a gear (right);
// body = Nook tab (media · divider · calendar strip + quick toggles + system stats) or Tray tab.
// Width is the notch body (shape width minus the ears); the height is fixed by the shape.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property string screenName: ""
    property string tab: "nook"   // "nook" | "tray"

    implicitWidth: Theme.notchExpandedWidth

    // ---- top row: tabs + gear ----
    RowLayout {
        id: top
        x: Theme.notchPad
        y: Theme.spacingMd + 2
        width: root.width - Theme.notchPad * 2
        height: Theme.notchTabHeight
        spacing: Theme.spacingSm

        Repeater {
            model: [{ key: "nook", label: "Nook" }, { key: "tray", label: "Tray" }]
            delegate: Item {
                id: tabItem
                required property var modelData
                readonly property bool current: root.tab === modelData.key
                Layout.preferredWidth: label.implicitWidth + Theme.spacingLg * 2
                Layout.preferredHeight: Theme.notchTabHeight

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: tabItem.current ? Theme.surface3 : (tabMouse.containsMouse ? Theme.surface2 : Theme.transparent)
                    Behavior on color { ColorAnimation { duration: Theme.durHover } }
                }
                UiText {
                    id: label
                    anchors.centerIn: parent
                    text: tabItem.modelData.label
                    size: Theme.sizeBody
                    weight: Theme.weightSemiBold
                    color: tabItem.current ? Theme.text : Theme.textDim
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tab = tabItem.modelData.key
                }
            }
        }

        Item { Layout.fillWidth: true }

        // gear → session / power menu (the old dashboard header's lock / suspend / power buttons)
        IconButton {
            icon: Icons.cog
            size: Theme.notchTabHeight
            iconSize: Theme.iconMd
            radius: height / 2
            bgColor: Theme.transparent
            iconColor: Theme.textDim
            onClicked: ShellState.open("power", root.screenName)
        }
    }

    // ---- tab body ----
    Item {
        x: Theme.notchPad
        y: top.y + top.height + Theme.spacingMd
        width: root.width - Theme.notchPad * 2
        height: Theme.notchExpandedHeight - y - Theme.notchPad

        Loader {
            anchors.fill: parent
            sourceComponent: root.tab === "tray" ? trayTab : nookTab
        }
    }

    Component { id: nookTab; NookTab { screenName: root.screenName } }
    Component { id: trayTab; TrayTab {} }
}
