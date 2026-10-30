// =============================================================================
// dragon-island — OverviewWindow.qml (namespace "dragon-overview", layer Overlay) · docs/design/11-escritorios.png
// SUPER + Tab: the five workspaces as cards in a row (OverviewCard) and, under them, «VISTA PREVIA»: the card under
// the pointer (or the keyboard's) drawn large with real captures of its windows (ScreencopyView, live: false, only
// for that workspace). Drag a window — from a card or from the preview — onto another card to move it there
// (Overview.move → movetoworkspacesilent); the target card turns dashed cyan, «Soltar aquí».
// Keys: ← → or 1–5 choose · Enter goes to that workspace · Esc closes. One blur region (the backdrop).
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool open: Overview.shown && (ShellState.panelScreen === "" || ShellState.panelScreen === screenName)
    visible: open || lingering.running
    onOpenChanged: if (open) { keys.forceActiveFocus(); hoverWs = 0; dragEndNow(); } else lingering.restart()
    Timer { id: lingering; interval: Theme.durOut + 60 }
    mask: open ? null : idle
    Region { id: idle }

    readonly property real gs: Math.min(width / Theme.gravityDesignW, height / Theme.gravityDesignH)
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: win.open ? Theme.durEmerge : Theme.durOut
            easing.type: Easing.BezierSpline
            easing.bezierCurve: win.open ? Theme.curveEmergente : Theme.curveSalida
        }
    }

    // every workspace's windows with their geometry (only while open)
    readonly property var layouts: open ? [1, 2, 3, 4, 5].map(i => WorkspacePreview.layout(i)) : []
    property int hoverWs: 0
    readonly property int previewWs: dragging ? dragFrom : (hoverWs > 0 ? hoverWs : Overview.selected)

    // ---- dragging a window ----
    property string dragAddr: ""
    property var dragWin: null
    property int dragFrom: 0
    property bool dragging: false
    property int dropWs: 0
    property point dragPos: Qt.point(0, 0)
    property point _pressPos: Qt.point(0, 0)
    function dragStart(w, ws: int, p: point): void {
        dragWin = w; dragAddr = w.address; dragFrom = ws; _pressPos = p; dragPos = p; dragging = false; dropWs = 0;
    }
    function dragMove(p: point): void {
        if (dragAddr === "") return;
        dragPos = p;
        if (!dragging && Math.hypot(p.x - _pressPos.x, p.y - _pressPos.y) > Theme.spacingSm) dragging = true;
        if (dragging) dropWs = cardAt(p);
    }
    function dragEnd(srcWs: int): void {
        const moved = dragging && dropWs > 0 && dropWs !== dragFrom;
        if (moved) Overview.move(dragAddr, dropWs);
        else if (!dragging && dragAddr !== "") Overview.go(srcWs);          // a plain click on a window: go there
        dragEndNow();
    }
    function dragEndNow(): void { dragAddr = ""; dragWin = null; dragging = false; dropWs = 0; }
    function cardAt(p: point): int {
        const r = cards.mapFromItem(win.contentItem, p.x, p.y);
        if (r.y < -Theme.spacingLg * gs || r.y > Theme.overviewCardH * gs + Theme.spacingLg * gs) return 0;
        const pitch = (Theme.overviewCardW + Theme.overviewGap) * gs;
        const i = Math.floor(r.x / pitch);
        return i >= 0 && i < Hypr.workspaceCount && r.x - i * pitch <= Theme.overviewCardW * gs ? i + 1 : 0;
    }

    // ---- backdrop ----
    Rectangle {
        anchors.fill: parent
        color: Theme.gravityBackdrop
        opacity: win.reveal
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Overview.close()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Left) Overview.step(-1);
            else if (k === Qt.Key_Right) Overview.step(1);
            else if (k >= Qt.Key_1 && k <= Qt.Key_5) Overview.select(k - Qt.Key_0);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) Overview.go(Overview.selected);
            else if (k === Qt.Key_Escape) Overview.close();
            else return;
            win.hoverWs = 0;
            e.accepted = true;
        }
    }

    // ---- the five cards ----
    Row {
        id: cards
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.overviewTop * win.gs + (1 - win.reveal) * -Theme.overviewTop * win.gs
        spacing: Theme.overviewGap * win.gs
        opacity: win.reveal
        Repeater {
            model: Hypr.workspaceCount
            delegate: OverviewCard {
                required property int index
                host: win
                ws: index + 1
            }
        }
    }

    // ---- «VISTA PREVIA»: the chosen workspace, large, with real captures ----
    Rectangle {
        id: preview
        readonly property var wins: win.layouts[win.previewWs - 1] ?? []
        width: Theme.overviewPreviewW * win.gs
        height: width * (win.height / Math.max(1, win.width))
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.overviewPreviewTop * win.gs
        radius: Theme.gravityPanelRadius * win.gs
        color: Theme.switcherCardFill
        border.width: 1
        border.color: Theme.gravityTileEdge
        clip: true
        opacity: win.reveal
        scale: 0.96 + 0.04 * win.reveal

        Image {
            anchors.fill: parent
            source: Overview.wallpaper
            sourceSize.width: 1280
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
        Repeater {
            model: preview.wins
            delegate: Rectangle {
                id: shot
                required property var modelData
                x: modelData.x * preview.width
                y: modelData.y * preview.height
                width: Math.max(12, modelData.w * preview.width)
                height: Math.max(12, modelData.h * preview.height)
                radius: Theme.spacingSm * win.gs
                color: Theme.overviewWindow
                border.width: 1
                border.color: win.dragAddr === modelData.address ? Theme.cyan : Theme.gravityTileEdge
                opacity: win.dragAddr === modelData.address && win.dragging ? 0.4 : 1
                clip: true
                IconImageFallback { anchors.centerIn: parent; source: shot.modelData.icon }
                ScreencopyView {
                    anchors.fill: parent
                    anchors.margins: 1
                    captureSource: win.open ? (shot.modelData.toplevel?.wayland ?? null) : null
                    live: false
                    constraintSize: Qt.size(width, height)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: win.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: mouse => win.dragStart(shot.modelData, win.previewWs, mapToItem(win.contentItem, mouse.x, mouse.y))
                    onPositionChanged: mouse => win.dragMove(mapToItem(win.contentItem, mouse.x, mouse.y))
                    onReleased: win.dragEnd(win.previewWs)
                }
            }
        }
        UiText {
            visible: preview.wins.length === 0
            anchors.centerIn: parent
            text: "Escritorio vacío"
            size: Theme.sizeTitle * Math.max(1, win.gs)
            color: Theme.textSoft
        }
        Rectangle {
            x: Theme.spacingLg * win.gs
            anchors { bottom: parent.bottom; bottomMargin: Theme.spacingLg * win.gs }
            height: Theme.gravityChip * win.gs
            width: previewLabel.implicitWidth + Theme.spacingLg * win.gs
            radius: Theme.keyCapRadius * win.gs
            color: Theme.alpha(Theme.islandInk, 0.8)
            UiText {
                id: previewLabel
                anchors.centerIn: parent
                text: `ESCRITORIO ${win.previewWs} · VISTA PREVIA`
                mono: true
                size: Theme.sizeCaption * Math.max(1, win.gs) + 1
                color: Theme.text
                font.letterSpacing: 2 * win.gs
            }
        }
    }

    // ---- the dragged window, under the pointer ----
    Rectangle {
        visible: win.dragging
        z: 100
        width: Theme.overviewCardW * 0.6 * win.gs
        height: width * 0.62
        x: win.dragPos.x - width / 2
        y: win.dragPos.y - height / 2
        radius: Theme.spacingSm * win.gs
        color: Theme.overviewWindow
        border.width: 1.5
        border.color: Theme.cyan
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingXs * win.gs
            IconImageFallback { anchors.horizontalCenter: parent.horizontalCenter; source: win.dragWin?.icon ?? ""; implicitSize: Theme.iconLg * 1.6 * win.gs; opacity: 1 }
            UiText { anchors.horizontalCenter: parent.horizontalCenter; text: win.dragWin?.appName ?? ""; size: Theme.sizeBody * Math.max(1, win.gs); weight: Theme.weightSemiBold }
        }
    }

    KeyHints {
        z: 60
        opacity: win.reveal
        factor: Math.max(1, win.gs)
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.spacingLg * win.gs }
        hints: [["SUPER+TAB", "abrir"], ["ARRASTRAR", "mover ventana"], ["ENTER", "ir al escritorio"]]
    }
}
