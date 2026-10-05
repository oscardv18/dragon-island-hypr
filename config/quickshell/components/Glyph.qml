// Nerd Font icon (glyph names live in Icons.qml)
import QtQuick
import ".."

Text {
    property string icon: ""
    property real size: Theme.iconMd

    text: icon
    color: Theme.text
    font.family: Theme.fontMono
    font.pixelSize: Math.round(size)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
}
