// A small stroke icon of the lock screen's top right (Wi-Fi, volume, suspend, power). Pure QtQuick like LockView.
import QtQuick
import "../../components"

Item {
    id: ti
    property string glyph: ""
    property real scaleFactor: 1
    property color color: "#edebf5"
    property bool clickable: false
    signal activated()
    width: 28 * scaleFactor
    height: width
    CoreIcon { anchors.centerIn: parent; name: ti.glyph; size: 15 * ti.scaleFactor; color: ti.color }
    MouseArea { anchors.fill: parent; enabled: ti.clickable; cursorShape: Qt.PointingHandCursor; onClicked: ti.activated() }
}
