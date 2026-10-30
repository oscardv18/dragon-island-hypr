// =============================================================================
// dragon-island — ClipCard.qml: one clipboard entry on the Gravity clipboard ring (docs/design/12-portapapeles.png)
// Kind chip (icon + label in its colour), the content: mono text (commands, paths, links in cyan), a colour swatch
// filling the card with its value, an image thumbnail. Secrets stay masked until Space. Pinned: a pin in the corner.
// =============================================================================
import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

Item {
    id: card

    required property var ring             // ClipOrbit
    required property var entry            // Clipboard entry { id, text, isImage, meta }
    required property int index

    readonly property real gs: ring.gs
    readonly property var info: Clipboard.info(entry)
    readonly property int n: ring.count
    readonly property real raw: index - ring.pos
    readonly property real d: raw - n * Math.round(raw / Math.max(1, n))
    readonly property real theta: Math.PI / 2 + d * ring.step
    readonly property real depth: Math.sin(theta)
    readonly property real front: (depth + 1) / 2
    readonly property real near: Math.max(0, 1 - Math.abs(d))
    readonly property bool chosen: index === ring.chosenIndex
    readonly property bool masked: info.secret && !(chosen && ring.revealed)

    readonly property real sideW: Theme.clipCardSide * gs * (0.75 + 0.25 * front)
    width: sideW + (Theme.clipCard * gs - sideW) * near
    height: width * (Theme.clipCardH / Theme.clipCard) + (1 - near) * Theme.clipCardSideExtra * gs
    x: ring.cx + Math.cos(theta) * Theme.clipRingRx * gs - width / 2
    y: ring.cy + Math.sin(theta) * Theme.clipRingRy * gs - height / 2
    z: 10 + depth * 5 + near * 10
    visible: Math.abs(d) <= Theme.clipMax / 2
    opacity: 0.3 + 0.7 * front

    readonly property color tint: Theme.clipKindColors[info.kind] ?? Theme.textSoft
    readonly property bool isColor: info.kind === "color"

    Component.onCompleted: if (entry.isImage) Clipboard.requestThumbnail(entry)

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.switcherRadius * card.gs
        // a colour entry fills the card with itself (hex only: QML does not parse rgb() / hsl())
        color: card.isColor && /^#[0-9a-f]{3,8}$/i.test((card.entry.text || "").trim()) ? (card.entry.text || "").trim() : Theme.switcherCardFill
        border.width: card.chosen ? 2 : 1
        border.color: card.chosen ? card.tint : Theme.gravityTileEdge
        clip: true
        layer.enabled: card.depth < -0.2
        layer.effect: MultiEffect { blurEnabled: true; blur: Theme.gravityBackBlur * Math.min(1, -card.depth); blurMax: 16 }

        Image {
            visible: card.entry.isImage
            anchors.fill: parent
            anchors.margins: frame.border.width
            source: card.entry.isImage ? Clipboard.thumbnail(card.entry) : ""
            sourceSize.width: 480
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // kind chip
        Rectangle {
            id: chip
            x: Theme.spacingMd * card.gs
            y: Theme.spacingMd * card.gs
            height: Theme.gravityChip * card.gs
            width: chipRow.implicitWidth + Theme.spacingMd * card.gs
            radius: Theme.keyCapRadius * card.gs
            color: Theme.alpha(Theme.islandInk, 0.8)
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Theme.spacingXs * card.gs
                Glyph { anchors.verticalCenter: parent.verticalCenter; icon: card.ring.kindIcon(card.info.kind); size: Theme.iconMd * card.gs; color: card.chosen ? card.tint : Theme.textSoft }
                UiText { anchors.verticalCenter: parent.verticalCenter; text: card.info.label; size: Theme.sizeBody * Math.max(1, card.gs); weight: Theme.weightMedium; color: card.chosen ? Theme.text : Theme.textSoft }
            }
        }
        Glyph {
            visible: Clipboard.isPinned(card.entry)
            anchors { right: parent.right; top: parent.top; margins: Theme.spacingMd * card.gs }
            icon: Icons.pin
            size: Theme.iconMd * card.gs
            color: Theme.warn
        }

        // content
        Text {
            visible: !card.entry.isImage
            anchors { left: parent.left; right: parent.right; top: chip.bottom; bottom: parent.bottom; margins: Theme.spacingMd * card.gs; topMargin: Theme.spacingSm * card.gs }
            text: card.isColor ? (card.entry.text || "").trim().toUpperCase()
                : card.masked ? card.info.preview
                : (card.entry.text || "")
            verticalAlignment: card.isColor ? Text.AlignBottom : Text.AlignTop
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideRight
            maximumLineCount: card.isColor ? 1 : Math.max(1, Math.floor(height / (font.pixelSize * 1.35)))
            lineHeight: 1.15
            textFormat: Text.PlainText
            font.family: card.info.kind === "text" && !card.masked ? Theme.fontUi : Theme.fontMono
            font.pixelSize: Math.round((card.chosen ? Theme.sizeGreeting : Theme.sizeBody + 1) * Math.max(0.8, card.gs) * (0.75 + 0.25 * card.near))
            color: card.isColor ? Theme.islandInk : card.info.kind === "link" ? Theme.cyan : card.masked ? Theme.textDim : Theme.text
        }
        UiText {
            visible: card.masked && card.chosen
            anchors { right: parent.right; bottom: parent.bottom; margins: Theme.spacingMd * card.gs }
            text: "Espacio: mostrar"
            mono: true
            size: Theme.sizeCaption * Math.max(1, card.gs)
            color: Theme.textDim
        }
    }
    // soft glow in the kind colour around the chosen card
    Rectangle {
        visible: card.chosen
        z: -1
        anchors.fill: parent
        anchors.margins: -Theme.spacingSm * card.gs
        radius: frame.radius + Theme.spacingSm * card.gs
        color: Theme.transparent
        border.width: Theme.spacingSm * card.gs
        border.color: Theme.alpha(card.tint, 0.12)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.chosen ? card.ring.paste() : card.ring.choose(card.index)
        onWheel: wheel => card.ring.wheel(wheel.angleDelta.y)
    }
}
