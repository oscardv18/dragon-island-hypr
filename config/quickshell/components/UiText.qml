// Text with the UI typography defaults (Outfit). `caption` = 11 px uppercase, tracked, dim.
import QtQuick
import QtQuick.Effects
import ".."

Text {
    property real size: Theme.sizeBody
    property bool mono: false
    property bool caption: false
    property int weight: Theme.weightRegular
    property bool shadow: false     // subtle drop shadow so text stays legible on glass (bar islands)

    color: caption ? Theme.textDim : Theme.text
    font.family: mono ? Theme.fontMono : Theme.fontUi
    font.pixelSize: Math.round(caption ? Theme.sizeCaption : size)
    font.weight: caption ? Theme.weightSemiBold : weight
    font.capitalization: caption ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: caption ? Theme.sizeCaption * Theme.captionTracking : 0
    elide: Text.ElideRight
    maximumLineCount: 1
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter

    layer.enabled: shadow
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.textShadow
        shadowBlur: 0.3
        shadowVerticalOffset: 1
        shadowHorizontalOffset: 0
    }
}
