// The HUD caption: monospaced, uppercase, tracked, dim (docs/design/28-emergentes.png: «RENDIMIENTO», «NÚCLEOS · 12»).
import QtQuick
import ".."

Text {
    property real size: Theme.sizeCaption - 1
    color: Theme.textDim
    font.family: Theme.fontMono
    font.pixelSize: Math.round(size)
    font.weight: Theme.weightMedium
    font.capitalization: Font.AllUppercase
    font.letterSpacing: size * 0.18
    elide: Text.ElideRight
    maximumLineCount: 1
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
}
