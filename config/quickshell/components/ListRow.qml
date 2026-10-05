// List row (networks, devices, apps…): [active dot] icon · title/subtitle · trailing items
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

Item {
    id: root

    property string icon: ""
    property string iconSource: ""     // image instead of a glyph (app icons)
    property color iconColor: Theme.textSoft
    property string title: ""
    property string subtitle: ""
    property bool active: false        // e.g. current device: accent dot + accent icon
    property bool highlighted: false   // keyboard selection
    property bool interactive: true
    default property alias trailing: trailingRow.data
    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal rightClicked()

    implicitHeight: Theme.rowHeight
    implicitWidth: Theme.popoverWidthSm

    Rectangle {
        anchors.fill: parent
        radius: Theme.rowRadius
        color: root.highlighted || (root.interactive && root.hovered) ? Theme.surfaceHi : Theme.surface2
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => m.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingSm
        spacing: Theme.spacingSm

        Rectangle {
            visible: root.active
            Layout.preferredWidth: Theme.pillDot + 2
            Layout.preferredHeight: Theme.pillDot + 2
            radius: width / 2
            color: Theme.accent
        }

        Glyph {
            visible: root.icon.length > 0 && root.iconSource.length === 0
            icon: root.icon
            size: Theme.iconLg
            color: root.active ? Theme.accent : root.iconColor
            Layout.preferredWidth: Theme.iconLg + Theme.spacingXs
        }

        IconImage {
            visible: root.iconSource.length > 0
            source: root.iconSource
            implicitSize: Theme.iconLg + Theme.spacingSm
            asynchronous: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            UiText {
                Layout.fillWidth: true
                text: root.title
                weight: root.active ? Theme.weightSemiBold : Theme.weightMedium
            }
            UiText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.subtitle
                size: Theme.sizeCaption
                color: Theme.textDim
            }
        }

        Row {
            id: trailingRow
            spacing: Theme.spacingSm
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
