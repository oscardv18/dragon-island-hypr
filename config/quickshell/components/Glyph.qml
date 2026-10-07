// Nerd Font icon (glyph names live in Icons.qml)
import QtQuick
import QtQuick.Effects
import ".."

Text {
    property string icon: ""
    property real size: Theme.iconMd
    property bool shadow: false     // subtle drop shadow so icons stay legible on glass (bar islands)

    text: icon
    color: Theme.text
    font.family: Theme.fontMono
    font.pixelSize: Math.round(size)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText

    layer.enabled: shadow && Theme.textShadows
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.textShadow
        shadowBlur: 0.3
        shadowVerticalOffset: 1
        shadowHorizontalOffset: 0
    }
}
