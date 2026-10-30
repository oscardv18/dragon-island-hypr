// =============================================================================
// dragon-island — PaletteStrip.qml
// A row of five colours of a wallpaper thumbnail, shown while it is hovered in the pickers (orbital and grid).
// Only a preview: Quickshell's ColorQuantizer on the small thumbnail (file:// only, it cannot read image://). The
// real palette is still the one bin/dragon-palette makes when the wallpaper is applied. The quantizer is only
// loaded while `active`, and each thumbnail is quantized once (WallPalette.previews caches it).
// =============================================================================
import QtQuick
import Quickshell
import ".."
import "../services"

Item {
    id: root

    property string source: ""          // file:// URL of the thumbnail
    property bool active: false
    readonly property var colors: WallPalette.previews[source] ?? []

    implicitHeight: Theme.orbitalStrip
    opacity: active && colors.length > 0 ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }

    Loader {
        active: root.active && root.source.length > 0 && WallPalette.previews[root.source] === undefined
        sourceComponent: ColorQuantizer {
            source: root.source
            depth: 3
            rescaleSize: 64
            // 8 buckets → 5 colours from dark to light, like the palette swatches in Ajustes
            onColorsChanged: {
                if (colors.length === 0) return;
                const sorted = colors.slice().sort((a, b) => a.hslLightness - b.hslLightness);
                const pick = [];
                for (let i = 0; i < 5; i++) pick.push(sorted[Math.round(i * (sorted.length - 1) / 4)]);
                WallPalette.cachePreview(root.source, pick);
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: root.colors
            delegate: Rectangle {
                required property color modelData
                required property int index
                width: (root.width - 2 * 4) / 5
                height: root.height
                radius: height / 2
                color: modelData
                border.width: 1
                border.color: Theme.glassBorder
            }
        }
    }
}
