// Rounded album art with a music glyph fallback
import QtQuick
import Quickshell.Widgets
import ".."

ClippingRectangle {
    id: root
    property string source: ""
    property real iconSize: Theme.iconMd

    color: Theme.surface3
    radius: Theme.artSmallRadius

    Glyph {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        icon: Icons.music
        size: root.iconSize
        color: Theme.textDim
    }

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width * 2
        sourceSize.height: root.height * 2
        visible: status === Image.Ready
    }
}
