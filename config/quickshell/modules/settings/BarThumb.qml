// Schematic miniature of a bar style for the Ajustes cards: a dusk gradient "desktop" with the style's side islands
// and centre island drawn to scale (≈ 1/6).
import QtQuick
import "../.."

Rectangle {
    id: root
    property string style: "B"
    readonly property real k: width / 220

    height: width * 0.48
    radius: 8
    clip: true
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.thumbDusk[0] }
        GradientStop { position: 0.55; color: Theme.thumbDusk[1] }
        GradientStop { position: 1.0; color: Theme.thumbDusk[2] }
    }

    // a tiled window under the bar (where the reserved space ends)
    Rectangle {
        x: 8 * root.k
        y: (root.style === "A" ? 31 : root.style === "B" ? 32 : root.style === "C" ? 24 : 18) * root.k * 0.55 + 6 * root.k
        width: parent.width - 16 * root.k
        height: parent.height
        radius: 4 * root.k
        color: Theme.thumbWindow
        border.width: 1
        border.color: Theme.glassBorder
    }

    // C: the joined strip
    Rectangle {
        visible: root.style === "C"
        width: parent.width
        height: 12 * root.k
        color: Theme.thumbStrip
    }
    // side islands
    Rectangle {
        visible: root.style !== "C"
        x: 6 * root.k
        y: (root.style === "D" ? 3 : 4) * root.k
        width: (root.style === "D" ? 34 : 64) * root.k
        height: (root.style === "D" ? 8 : 12) * root.k
        radius: height / 2
        color: Theme.thumbIsland
    }
    Rectangle {
        visible: root.style !== "C"
        x: parent.width - width - 6 * root.k
        y: (root.style === "D" ? 3 : 4) * root.k
        width: (root.style === "D" ? 22 : 64) * root.k
        height: (root.style === "D" ? 8 : 12) * root.k
        radius: height / 2
        color: Theme.thumbIsland
    }
    // centre island (D: the micro-island)
    Rectangle {
        x: (parent.width - width) / 2
        y: root.style === "B" ? 4 * root.k : (root.style === "D" ? 3 * root.k : -6 * root.k)
        width: (root.style === "D" ? 22 : 56) * root.k
        height: (root.style === "D" ? 8 : root.style === "C" ? 18 : 18) * root.k
        radius: root.style === "B" || root.style === "D" ? height / 2 : 6 * root.k
        color: Theme.islandInk
    }
}
