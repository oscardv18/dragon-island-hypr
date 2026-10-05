// Dashboard quick toggle: min-height 64, radius 18; brand gradient when on
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool checked: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal secondaryClicked()   // right click: open the related popover

    implicitHeight: Theme.tileMinHeight
    implicitWidth: Theme.tileMinWidth
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: Theme.tileRadius
        visible: !root.checked
        color: root.hovered ? Theme.surfaceHi : Theme.surface2
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
    }

    BrandFill {
        anchors.fill: parent
        radius: Theme.tileRadius
        visible: root.checked
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.tileRadius
        visible: root.checked
        color: Theme.hoverOverlay
        opacity: root.hovered ? 1 : 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        spacing: Theme.spacingSm

        Glyph {
            icon: root.icon
            size: Theme.iconLg
            color: root.checked ? Theme.onBrand : Theme.textSoft
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            UiText {
                Layout.fillWidth: true
                text: root.label
                weight: Theme.weightSemiBold
                color: root.checked ? Theme.onBrand : Theme.text
            }
            UiText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.sublabel
                size: Theme.sizeCaption
                color: root.checked ? Theme.alpha(Theme.onBrand, 0.8) : Theme.textDim
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => m.button === Qt.RightButton ? root.secondaryClicked() : root.clicked()
    }
}
