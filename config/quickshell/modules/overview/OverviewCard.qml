// =============================================================================
// dragon-island — OverviewCard.qml: one workspace in the overview row (docs/design/11-escritorios.png)
// The wallpaper with the workspace's windows drawn as rectangles in their real proportions (WorkspacePreview.layout),
// «N · app dominante» under it («· actual» on the focused one, «Vacío» when empty). Cyan edge = chosen (keyboard /
// pointer); dashed cyan + «Soltar aquí» = a window is being dragged over it. Window rectangles can be dragged out.
// =============================================================================
import QtQuick
import QtQuick.Shapes
import "../.."
import "../../services"
import "../../components"

Item {
    id: card

    required property var host             // OverviewWindow
    required property int ws
    readonly property real gs: host.gs
    readonly property var wins: host.layouts[ws - 1] ?? []
    readonly property bool current: Hypr.focusedWorkspaceId === ws
    readonly property bool chosen: host.previewWs === ws
    readonly property bool dropHere: host.dragging && host.dropWs === ws && host.dragFrom !== ws

    width: Theme.overviewCardW * gs
    height: Theme.overviewCardH * gs + label.height + Theme.spacingSm * gs

    Rectangle {
        id: frame
        width: parent.width
        height: Theme.overviewCardH * card.gs
        radius: Theme.overviewRadius * card.gs
        color: Theme.switcherCardFill
        border.width: card.chosen || card.current ? 2 : 1
        border.color: card.chosen ? Theme.cyan : card.current ? Theme.lavender : Theme.gravityTileEdge
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: frame.border.width
            source: Overview.wallpaper
            sourceSize.width: 440
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false                    // the link changes target with every new wallpaper
            opacity: 0.9
        }

        Repeater {
            model: card.wins
            delegate: Rectangle {
                id: rect
                required property var modelData
                x: modelData.x * frame.width
                y: modelData.y * frame.height
                width: Math.max(6, modelData.w * frame.width)
                height: Math.max(6, modelData.h * frame.height)
                radius: Theme.spacingXs * card.gs
                color: Theme.overviewWindow
                border.width: 1
                border.color: card.host.dragAddr === modelData.address ? Theme.cyan : Theme.gravityTileEdge
                opacity: card.host.dragAddr === modelData.address ? 0.4 : 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: card.host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: mouse => card.host.dragStart(rect.modelData, card.ws, mapToItem(card.host.contentItem, mouse.x, mouse.y))
                    onPositionChanged: mouse => card.host.dragMove(mapToItem(card.host.contentItem, mouse.x, mouse.y))
                    onReleased: card.host.dragEnd(card.ws)
                }
            }
        }

        // empty: a plus in the middle
        UiText {
            visible: card.wins.length === 0
            anchors.centerIn: parent
            text: "+"
            size: Theme.sizeHero * 0.7 * Math.max(1, card.gs)
            weight: Theme.weightRegular
            color: Theme.alpha(Theme.text, 0.75)
        }
    }

    // dashed cyan edge while a window is dragged over this card
    Shape {
        visible: card.dropHere
        x: -Theme.spacingXs * card.gs
        y: -Theme.spacingXs * card.gs
        width: frame.width + 2 * Theme.spacingXs * card.gs
        height: frame.height + 2 * Theme.spacingXs * card.gs
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.overviewDrop
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 2]
            fillColor: Theme.alpha(Theme.overviewDrop, 0.08)
            PathRectangle {
                width: frame.width + 2 * Theme.spacingXs * card.gs
                height: frame.height + 2 * Theme.spacingXs * card.gs
                radius: (Theme.overviewRadius + Theme.spacingXs) * card.gs
            }
        }
    }

    UiText {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: frame.height + Theme.spacingSm * card.gs
        text: card.dropHere ? `${card.ws} · Soltar aquí`
            : [`${card.ws}`, card.wins.length === 0 ? "Vacío" : WorkspacePreview.dominantApp(card.ws), card.current ? "actual" : ""].filter(x => x).join(" · ")
        size: Theme.sizeBodyLg * Math.max(1, card.gs)
        weight: card.current || card.chosen || card.dropHere ? Theme.weightSemiBold : Theme.weightRegular
        color: card.dropHere || card.chosen ? Theme.cyan : card.current ? Theme.text : Theme.textSoft
    }

    // the card itself: hover previews it, click goes there (window rectangles above take their own presses)
    MouseArea {
        anchors.fill: frame
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: card.host.hoverWs = card.ws
        onExited: if (card.host.hoverWs === card.ws) card.host.hoverWs = 0
        onClicked: Overview.go(card.ws)
    }
}
