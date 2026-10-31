// =============================================================================
// dragon-island — SwitcherCard.qml: one window on the Alt+Tab ring (docs/design/10-alttab.png)
// A capture of the window taken ONCE when the switcher shows (ScreencopyView, live: false; the app icon until it
// arrives), its label chip under the bottom edge. The chosen card is at the front, large, with a cyan edge; the rest
// follow the depth of their angle (smaller, dimmer, blurred at the back).
// =============================================================================
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../.."
import "../../components"

Item {
    id: card

    required property var ring           // SwitcherWindow
    required property var item           // Hypr.mruWindows() item
    required property int index

    readonly property real gs: ring.gs
    readonly property int n: ring.count
    readonly property real raw: index - ring.pos
    readonly property real d: raw - n * Math.round(raw / Math.max(1, n))        // wrapped distance to the front
    readonly property real theta: Math.PI / 2 + d * ring.step
    readonly property real depth: Math.sin(theta)
    readonly property real front: (depth + 1) / 2
    readonly property real near: Math.max(0, 1 - Math.abs(d))                  // 1 = the chosen one
    readonly property bool chosen: index === ring.chosenIndex

    readonly property real sideW: Theme.switcherCardSide * gs * (0.72 + 0.28 * front)
    readonly property real cardW: sideW + (Theme.switcherCard * gs - sideW) * near
    readonly property real cardH: cardW * Theme.switcherAspect

    visible: Math.abs(d) <= Theme.switcherMax / 2 && ring.reveal > 0.01
    width: cardW
    height: cardH
    x: ring.cx + Math.cos(theta) * Theme.switcherRingRx * gs - width / 2
    y: ring.cy + Math.sin(theta) * Theme.switcherRingRy * gs - height / 2
    z: 10 + depth * 5 + near * 10
    opacity: (0.35 + 0.65 * front) * ring.reveal
    scale: 0.88 + 0.12 * ring.reveal

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.switcherRadius * card.gs
        color: Theme.switcherCardFill
        border.width: card.chosen ? 2 : 1
        border.color: card.chosen ? Theme.cyan : Theme.gravityTileEdge
        clip: true

        layer.enabled: card.depth < -0.2
        layer.effect: MultiEffect { blurEnabled: true; blur: Theme.gravityBackBlur * Math.min(1, -card.depth); blurMax: 16 }

        IconImageFallback {
            anchors.centerIn: parent
            source: card.item.icon
            implicitSize: Math.min(parent.width, parent.height) * 0.3
        }
        ScreencopyView {
            anchors.fill: parent
            anchors.margins: frame.border.width
            captureSource: card.ring.open ? (card.item.toplevel?.wayland ?? null) : null
            live: false
            constraintSize: Qt.size(width, height)
        }
    }
    // cyan glow around the chosen card
    Rectangle {
        visible: card.chosen
        anchors.fill: parent
        anchors.margins: -Theme.spacingSm * card.gs
        radius: frame.radius + Theme.spacingSm * card.gs
        color: Theme.transparent
        border.width: Theme.spacingSm * card.gs
        border.color: Theme.alpha(Theme.cyan, 0.12)
        z: -1
    }

    // label chip on the bottom edge
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height / 2
        height: Theme.gravityChip * 1.3 * card.gs
        width: chipRow.implicitWidth + Theme.spacingLg * card.gs
        radius: height / 2
        color: Theme.switcherCardFill
        border.width: 1
        border.color: Theme.gravityTileEdge
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spacingSm * card.gs
            IconImageFallback {
                anchors.verticalCenter: parent.verticalCenter
                source: card.item.icon
                implicitSize: Theme.iconMd * Math.max(1, card.gs)
                opacity: 1
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, card.width * 0.8)
                text: card.chosen ? card.item.appName : [card.item.appName, card.ring.shortTitle(card.item)].filter(x => x).join(" · ")
                size: Theme.sizeBody * Math.max(1, card.gs)
                weight: card.chosen ? Theme.weightSemiBold : Theme.weightMedium
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.ring.pick(card.index)
        onWheel: wheel => card.ring.wheel(wheel.angleDelta.y)
    }
}
