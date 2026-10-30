// Small text button of the island panels: neutral (white 6 %, hover 8 %) or primary (a solid colour, dark text).
import QtQuick
import ".."

Rectangle {
    id: btn
    property string label: ""
    property bool primary: false
    property color tone: Theme.warn          // primary fill
    signal pressed()

    implicitHeight: 30
    implicitWidth: btnText.implicitWidth + Theme.spacingLg * 2
    radius: 8
    color: primary ? (btnMouse.containsMouse ? Qt.lighter(tone, 1.1) : tone) : (btnMouse.containsMouse ? Theme.hoverOverlay : Theme.neutralFill)
    UiText { id: btnText; anchors.centerIn: parent; text: btn.label; weight: Theme.weightMedium; color: btn.primary ? Theme.islandInk : Theme.text }
    MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.pressed() }
}
