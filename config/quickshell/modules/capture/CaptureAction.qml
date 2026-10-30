// A button of the capture bars: icon + label; checked (the current mode) on white 8 %, primary (Copiar) in cyan.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: btn
    property string icon: ""
    property string label: ""
    property bool checked: false
    property bool primary: false
    signal pressed()

    implicitHeight: 34
    implicitWidth: row.implicitWidth + Theme.spacingMd * 2
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    radius: 10
    color: primary ? Theme.alpha(Theme.cyan, mouse.containsMouse ? 0.30 : 0.20)
                   : (checked ? Theme.hoverOverlay : (mouse.containsMouse ? Theme.neutralFill : Theme.transparent))
    border.width: primary ? 1 : 0
    border.color: Theme.alpha(Theme.cyan, 0.55)
    Behavior on color { ColorAnimation { duration: Theme.durHover } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacingSm
        Glyph { visible: btn.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; icon: btn.icon; size: Theme.iconMd; color: btn.checked || btn.primary ? Theme.text : Theme.textSoft }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: btn.label; weight: btn.checked || btn.primary ? Theme.weightSemiBold : Theme.weightRegular; color: btn.checked || btn.primary ? Theme.text : Theme.textSoft }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.pressed() }
}
