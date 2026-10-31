// =============================================================================
// dragon-island — NotificationWindow.qml
// Notification popups (namespace "dragon-notifications") that leave the island (docs/design/28-emergentes.png).
// Up to 3 cards under the right island, on the focused monitor only, hidden while a panel is open; the rest are
// grouped as «+N» on the third card. Each card is its OWN layer window, as big as the card (alpha 0 around it), so
// there is one blur region per window and the 8 px between cards stay clear.
//
// Arrival: the island widens with a cyan halo and shows the sender (IslandState "notification"); the card asks
// NotifFx for its drop, which the ISLAND window draws from the notch to the card's top (440 ms, orbita); when it lands:
//   trace  the outline is drawn in cyan from the top centre to the sides and down (320 ms)
//   fill   the glass fills from top to bottom (300 ms, emergente) and the cyan outline fades
//   rows   icon / title, body, actions in cascade (45 ms apart) and a band of light sweeps the card once
//   time   a 2 px line at the bottom (cyan → lavender) shrinks over Theme.durNotif; the pointer on the card pauses it
// Leaving (time up, close, swipe): content out (120 ms) → collapse into a horizontal line (200 ms, salida) → the
// drop flies back to the island (320 ms) → the island pulses «Guardada en el centro».
// New cards push the older ones down (240 ms, estandar). Critical: the outline stays amber, it never closes alone.
// DND: Notifs.popups stays empty (no drop, no card); the island keeps the counter. reduceMotion: plain fades.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "../.."
import "../../services"
import "../../components"

Scope {
    id: root

    property var modelData
    readonly property string screenName: modelData?.name ?? ""
    readonly property real screenWidth: modelData?.width ?? 0

    readonly property bool isFocusedMonitor: Hypr.focusedMonitorName === "" || Hypr.focusedMonitorName === screenName
    readonly property bool panelHere: ShellState.anyOpen && (ShellState.panelScreen === "" || ShellState.panelScreen === screenName)
    readonly property bool active: isFocusedMonitor && !panelHere
    readonly property real top: Theme.barMarginTop + Theme.barHeight + Theme.hudGap

    // card heights by notification id, to stack the windows
    property var heights: ({})
    function setHeight(id, h: real): void {
        if (heights[id] === h) return;
        const next = Object.assign({}, heights);
        next[id] = h;
        heights = next;
    }
    function offsetFor(index: int): real {
        let y = 0;
        for (let i = 0; i < index; i++) y += (heights[items[i]?.id] ?? 80) + Theme.spacingSm;
        return y;
    }

    readonly property var items: active ? Notifs.popups.slice(0, Theme.maxPopups) : []
    readonly property int extra: active ? Math.max(0, Notifs.popups.length - Theme.maxPopups) : 0

    Variants {
        model: root.items

        delegate: PanelWindow {
            id: win

            required property var modelData
            readonly property int index: root.items.indexOf(modelData)
            readonly property bool calm: Settings.calmMotion || !Theme.animationsEnabled
            readonly property bool critical: Notifs.isCritical(modelData)
            readonly property real cardW: Theme.hudWidth
            readonly property real cardH: Math.max(1, card.implicitHeight)
            readonly property real cardX: root.screenWidth - Theme.barMarginSide - cardW / 2   // top centre, screen x
            readonly property bool landed: NotifFx.isReady(modelData.id)

            screen: root.modelData
            anchors { top: true; right: true }
            margins.top: root.top + root.offsetFor(Math.max(0, index))
            margins.right: Theme.barMarginSide
            Behavior on margins.top { enabled: !win.calm; NumberAnimation { duration: Theme.durPush; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
            implicitWidth: cardW
            implicitHeight: cardH
            exclusionMode: ExclusionMode.Ignore
            color: Theme.transparent

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dragon-notifications"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region { item: wrap }

            // ---- phases ----
            property real trace: 0      // outline drawn
            property real fill: 0       // glass filled from the top
            property real rows: 0       // content cascade
            property real sweep: 0      // light band position
            property real life: 1       // time line (1 → 0)
            property real fade: 1       // leaving: content out
            property real squash: 1     // leaving: height → a line
            property bool leaving: false

            function start(): void {
                if (calm) { trace = 1; fill = 1; rows = 1; sweep = 1; calmIn.start(); lifeAnim.restart(); return; }
                NotifFx.launch(modelData.id, root.screenName, cardX, root.top + root.offsetFor(Math.max(0, index)));
            }
            onLandedChanged: if (landed && !calm && trace === 0) arrive.start()
            function leave(): void {
                if (leaving) return;
                leaving = true;
                arrive.stop(); lifeAnim.stop();
                if (calm) calmOut.start(); else depart.start();
            }

            SequentialAnimation {
                id: arrive
                NumberAnimation { target: win; property: "trace"; to: 1; duration: Theme.durTrace; easing.type: Easing.InOutCubic }
                NumberAnimation { target: win; property: "fill"; to: 1; duration: Theme.durFillCard; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEmergente }
                ParallelAnimation {
                    NumberAnimation { target: win; property: "rows"; to: 1; duration: Theme.durCardStagger * 2 + Theme.durRowIn }
                    NumberAnimation { target: win; property: "sweep"; to: 1; duration: Theme.durSweep; easing.type: Easing.InOutCubic }
                }
                ScriptAction { script: lifeAnim.restart() }
            }
            NumberAnimation { id: calmIn; target: wrap; property: "opacity"; from: 0; to: 1; duration: Theme.durCalmFade }
            NumberAnimation { id: calmOut; target: wrap; property: "opacity"; to: 0; duration: Theme.durCalmFade; onFinished: Notifs.dismissPopup(win.modelData) }
            SequentialAnimation {
                id: depart
                NumberAnimation { target: win; property: "fade"; to: 0; duration: Theme.durCardFade; easing.type: Easing.OutCubic }
                NumberAnimation { target: win; property: "squash"; to: 0; duration: Theme.durCollapse; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveSalida }
                ScriptAction {
                    script: {
                        NotifFx.recall(win.modelData.id, root.screenName, win.cardX, win.margins.top + win.cardH / 2);
                        Notifs.dismissPopup(win.modelData);
                    }
                }
            }
            // the time line; hover pauses it (and the expiry with it). Critical cards never expire.
            NumberAnimation {
                id: lifeAnim
                target: win
                property: "life"
                from: 1; to: 0
                duration: Math.max(1, Notifs.popupDuration(win.modelData))
                paused: running && card.hovered
                onFinished: if (!win.critical && win.life <= 0.001) win.leave()
            }

            Component.onCompleted: { root.setHeight(modelData.id, cardH); if (Notifs.popupDuration(modelData) <= 0) lifeAnim.duration = 1; start(); }

            Item {
                id: wrap
                width: win.cardW
                height: win.cardH
                opacity: win.calm ? 0 : 1

                // collapsing into a line around the vertical centre
                Item {
                    id: body
                    width: parent.width
                    height: Math.max(Theme.notifTimeLine, parent.height * win.squash)
                    y: (parent.height - height) / 2
                    clip: true

                    // the full card, kept centred while `body` collapses around the middle
                    Item {
                    id: inner
                    y: (body.height - win.cardH) / 2
                    width: body.width
                    height: win.cardH

                    GlassShadow { anchors.fill: parent; radius: Theme.hudRadius; opacity: win.fill * win.fade }

                    // the glass, filled from the top
                    Item {
                        width: parent.width
                        height: win.cardH * win.fill
                        clip: true
                        Rectangle {
                            id: glass
                            width: body.width
                            height: win.cardH
                            radius: Theme.hudRadius
                            color: Theme.glassFill
                            border.width: 1
                            border.color: win.critical ? Theme.alpha(Theme.warn, 0.7) : Theme.glassBorder
                            GlassLight { cornerRadius: glass.radius }
                        }
                    }

                    // the cyan outline: drawn from the top centre to both sides and down, then fades (critical: stays amber)
                    Shape {
                        id: outline
                        width: body.width
                        height: win.cardH
                        preferredRendererType: Shape.CurveRenderer
                        visible: !win.calm
                        opacity: win.critical ? 1 : (1 - win.fill * 0.999) * win.fade
                        readonly property real r: Theme.hudRadius
                        readonly property real sw: 1.5
                        readonly property real half: (width / 2 - r) * 2 + (height - 2 * r) + Math.PI * r
                        readonly property color stroke: win.critical ? Theme.warn : Theme.cyan
                        ShapePath {
                            fillColor: Theme.transparent; strokeColor: outline.stroke; strokeWidth: outline.sw
                            strokeStyle: ShapePath.DashLine; capStyle: ShapePath.FlatCap
                            dashPattern: [Math.max(0.01, outline.half * win.trace / outline.sw), outline.half / outline.sw + 10]
                            startX: outline.width / 2; startY: outline.sw / 2
                            PathLine { x: outline.r; y: outline.sw / 2 }
                            PathArc { x: outline.sw / 2; y: outline.r; radiusX: outline.r; radiusY: outline.r; direction: PathArc.Counterclockwise }
                            PathLine { x: outline.sw / 2; y: outline.height - outline.r }
                            PathArc { x: outline.r; y: outline.height - outline.sw / 2; radiusX: outline.r; radiusY: outline.r; direction: PathArc.Counterclockwise }
                            PathLine { x: outline.width / 2; y: outline.height - outline.sw / 2 }
                        }
                        ShapePath {
                            fillColor: Theme.transparent; strokeColor: outline.stroke; strokeWidth: outline.sw
                            strokeStyle: ShapePath.DashLine; capStyle: ShapePath.FlatCap
                            dashPattern: [Math.max(0.01, outline.half * win.trace / outline.sw), outline.half / outline.sw + 10]
                            startX: outline.width / 2; startY: outline.sw / 2
                            PathLine { x: outline.width - outline.r; y: outline.sw / 2 }
                            PathArc { x: outline.width - outline.sw / 2; y: outline.r; radiusX: outline.r; radiusY: outline.r }
                            PathLine { x: outline.width - outline.sw / 2; y: outline.height - outline.r }
                            PathArc { x: outline.width - outline.r; y: outline.height - outline.sw / 2; radiusX: outline.r; radiusY: outline.r }
                            PathLine { x: outline.width / 2; y: outline.height - outline.sw / 2 }
                        }
                    }

                    // a band of light sweeps the card once
                    Item {
                        anchors.fill: parent
                        clip: true
                        visible: win.sweep > 0 && win.sweep < 1
                        Rectangle {
                            width: 70
                            height: parent.height * 1.6
                            y: -parent.height * 0.3
                            x: -width + (parent.width + width) * win.sweep
                            rotation: 18
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.transparent }
                                GradientStop { position: 0.5; color: Theme.alpha(Theme.text, 0.08) }
                                GradientStop { position: 1; color: Theme.transparent }
                            }
                        }
                    }

                    NotificationCard {
                        id: card
                        width: body.width
                        notification: win.modelData
                        popup: true
                        rows: win.rows
                        opacity: win.fade
                        onImplicitHeightChanged: root.setHeight(win.modelData.id, implicitHeight)
                        onCloseRequested: win.leave()
                    }

                    // time left: 2 px, cyan → lavender, shrinking (paused while hovered)
                    Rectangle {
                        visible: !win.critical && win.rows > 0.5
                        x: glass.radius / 2
                        y: win.cardH - Theme.notifTimeLine - 1
                        width: (body.width - glass.radius) * win.life
                        height: Theme.notifTimeLine
                        radius: 1
                        opacity: win.fade
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.cyan }
                            GradientStop { position: 1; color: Theme.lavender }
                        }
                    }

                    // «+N»: the cards beyond the third, on the last one
                    Rectangle {
                        visible: win.index === Theme.maxPopups - 1 && root.extra > 0
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingSm
                        width: extraText.implicitWidth + Theme.spacingMd
                        height: 18
                        radius: 9
                        color: Theme.alpha(Theme.cyan, 0.14)
                        border.width: 1
                        border.color: Theme.alpha(Theme.cyan, 0.45)
                        opacity: win.fade
                        HudCaption { id: extraText; anchors.centerIn: parent; text: `+${root.extra}`; color: Theme.cyan }
                    }
                    }
                }

                // swipe right to dismiss
                DragHandler {
                    id: swipe
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onTranslationChanged: body.x = Math.max(0, translation.x)
                    onActiveChanged: if (!active) { if (body.x > Theme.hudWidth * 0.25) win.leave(); body.x = 0; }
                }
            }
        }
    }
}
