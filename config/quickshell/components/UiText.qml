// Text with the UI typography defaults (Outfit). `caption` = 11 px uppercase, tracked, dim.
import QtQuick
import ".."

Text {
    property real size: Theme.sizeBody
    property bool mono: false
    property bool caption: false
    property int weight: Theme.weightRegular

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
}
