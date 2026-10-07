// =============================================================================
// dragon-island — DockWindow.qml (namespace "dragon-dock")
// Arc dock: a glass arc (520 × 90, QtQuick.Shapes) that rises from the screen edge, pinned apps on the left of
// the centre button, open / minimised apps on the right, then the downloads stack. Icons sit on a shallow
// curve with a slight tilt; the one under the pointer grows and so do its neighbours (along the curve).
// The content is drawn for the bottom edge and the whole frame is rotated for "left" / "right".
// Hiding: it sinks into the edge with a spring when a tiled / fullscreen window is on the workspace; the 3 px
// hot zone (DockEdge) brings it back; leaving waits 600 ms. Layer Top: fullscreen windows cover it.
// =============================================================================
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""
    readonly property string pos: Dock.position
    readonly property bool horizontal: pos === "bottom"

    anchors {
        bottom: true                       // bottom edge, or the full height for left / right
        left: pos === "bottom" || pos === "left"
        right: pos === "bottom" || pos === "right"
        top: pos !== "bottom"
    }
    implicitWidth: horizontal ? 0 : Theme.dockWindowHeight
    implicitHeight: horizontal ? Theme.dockWindowHeight : 0
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dragon-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // only the arc (and the menu / downloads fan while open) takes the pointer; the rest of the window is click-through
    mask: Region {
        Region { item: Dock.wanted ? hit : strip }
        Region { item: menu.visible ? menu : null }
    }

    // ------------------------------------------------------------ slots along the arc
    readonly property var left: Dock.pinnedItems
    readonly property var right: Dock.openItems
    readonly property var items: left.concat(right)                       // pinned first, then the other open apps
    readonly property int capacity: Theme.dockSlotsPerSide * 2
    readonly property int maxOff: Math.max(0, items.length - capacity)
    readonly property real half: (Math.min(items.length, capacity) - 1) / 2    // the visible slots are -half .. +half, centred

    // The dock is a semi-donut: a band (like a bar island) bent along a circle. The circle's centre is below the
    // screen edge; the capsules sit on the band's centre line.
    readonly property real outerR: (Math.pow(Theme.dockWidth / 2, 2) + Math.pow(Theme.dockHeight, 2)) / (2 * Theme.dockHeight)
    readonly property real innerR: outerR - Theme.dockBand
    readonly property real midR: outerR - Theme.dockBand / 2
    readonly property real innerHalf: Math.sqrt(innerR * innerR - Math.pow(outerR - Theme.dockHeight, 2))   // where the inner edge meets the screen edge
    readonly property real step: Theme.dockSpacing / midR                          // rad between neighbours (the band never grows: extra apps scroll away)
    readonly property real spacing: step * midR

    function slotAngle(s: int): real { return s * win.step; }
    function slotX(s: int): real { return Theme.dockWidth / 2 + win.midR * Math.sin(win.slotAngle(s)); }
    function slotY(s: int): real { return win.outerR - win.midR * Math.cos(win.slotAngle(s)); }

    property int menuIndex: -1
    property var menuItem: null
    property real menuX: 0

    Connections {
        target: Dock
        function onWantedChanged() { if (!Dock.wanted) { win.menuItem = null;  } }
    }

    Item {
        id: frame
        width: Theme.dockWidth + 100
        height: Theme.dockWindowHeight
        rotation: win.pos === "left" ? 90 : (win.pos === "right" ? -90 : 0)
        x: win.horizontal ? (win.width - width) / 2 : (win.width - width) / 2
        y: win.horizontal ? win.height - height : (win.height - height) / 2

        // The hot zone: a thin strip on the screen edge that takes the pointer while the dock is hidden. It lives in this
        // window (a separate edge window handed the pointer over to the dock badly: the dock rose and sank at once).
        Item {
            id: strip
            x: arc.x
            y: frame.height - Theme.dockEdge
            width: Theme.dockWidth
            height: Theme.dockEdge
            HoverHandler { onHoveredChanged: Dock.hover(hovered) }
        }

        // the arc and everything on it, sinking into the edge when hidden
        Item {
            id: arc
            x: (frame.width - Theme.dockWidth) / 2
            width: Theme.dockWidth
            height: Theme.dockHeight
            y: frame.height - Theme.dockHeight + sink
            property real sink: Dock.wanted ? 0 : Theme.dockHeight + 6
            Behavior on sink { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping; epsilon: 0.2 } }

            // The dock never grows: when there are more apps than slots, the wheel turns the band (each side on its own)
            // and the capsules that run past the ends fade out under the screen edge.
            property int target: 0
            property real off: target
            Behavior on off { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping; epsilon: 0.005 } }
            Connections {
                target: win
                function onMaxOffChanged() { arc.target = Math.min(arc.target, win.maxOff); }
            }

            // Pointer: handlers sit on the arc itself (the parent of the capsules), so a capsule's own MouseArea cannot steal
            // the hover from them — with the handler on a sibling item, hovering a capsule read as "left the dock", the
            // dock sank, rose again, and so on. The margin covers the rim around the band.
            HoverHandler { id: hover; margin: 8; onHoveredChanged: Dock.hover(hovered) }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => arc.target = Math.max(0, Math.min(win.maxOff, arc.target + (e.angleDelta.y > 0 ? -1 : 1)))
            }
            // geometry that takes the pointer (the window mask): the band's box plus the margin
            Item {
                id: hit
                x: -8
                y: -8
                width: Theme.dockWidth + 16
                height: Theme.dockHeight + 8
            }

            // ---- the glass band (a semi-donut): fill, light from the top, a bright rim and an inset rim ----
            BandShape { anchors.fill: parent; outerR: win.outerR; innerR: win.innerR; fill: Theme.glassBg }
            // the same rim as the bar islands: 1 px Theme.glassBorder
            BandShape { anchors.fill: parent; outerR: win.outerR; innerR: win.innerR; stroke: Theme.glassRim; strokeWidth: 1 }

            // ---- an app on the arc ----
            component Slot: Item {
                id: slot
                property var item: null           // Dock item, or null for a button
                property int slotNo: 0            // slot number on the arc, 0 = centre
                property string icon: ""          // image URL, or a glyph below
                property string glyph: ""
                property string label: ""
                property bool dim: false
                signal clicked(var mouse)
                signal dragMoved(real dx)
                signal dragEnded(real dx)

                readonly property real cx: win.slotX(slotNo)
                readonly property real cy: win.slotY(slotNo)
                readonly property real angle: win.slotAngle(slotNo) * 180 / Math.PI * 0.4     // a gentle tilt along the curve
                // no magnification: the hovered capsule lights up with the brand gradient instead
                readonly property real grow: 1

                width: Theme.dockIcon
                height: Theme.dockIcon
                x: cx - width / 2 + dragOffset
                y: cy - height / 2
                scale: grow
                rotation: 0
                z: grow
                property real dragOffset: 0
                Behavior on x { enabled: slot.dragOffset === 0; NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
                // fades towards the centre button and, past the last slot, under the screen edge
                readonly property real a: Math.abs(slotNo)
                readonly property real fade: Math.max(0, Math.min(1, 1 - (a - win.half) / 0.8))
                opacity: (dim ? 0.45 : 1) * fade
                Behavior on opacity { NumberAnimation { duration: Theme.durFade } }

                // the frame is rotated for left / right: keep the icon upright
                transform: Rotation { origin.x: slot.width / 2; origin.y: slot.height / 2; angle: -frame.rotation + slot.angle }

                // the capsule inside the band (as the capsules inside the bar islands)
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: mouse.containsMouse ? Theme.pillBgHi : Theme.pillBg
                    border.width: 1
                    border.color: Theme.glassRim
                    Behavior on color { ColorAnimation { duration: Theme.durHover } }
                }
                Image {
                    anchors.centerIn: parent
                    width: Theme.dockIconInner
                    height: Theme.dockIconInner
                    visible: slot.icon.length > 0
                    source: slot.icon
                    sourceSize: Qt.size(Theme.dockIconInner * 2, Theme.dockIconInner * 2)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    mipmap: true
                }
                Glyph { anchors.centerIn: parent; visible: slot.glyph.length > 0; icon: slot.glyph; size: Theme.iconLg; color: Theme.text }

                // open windows: 1 to 3 dots
                Row {
                    visible: (slot.item?.count ?? 0) > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    spacing: 3
                    Repeater {
                        model: Math.min(3, slot.item?.count ?? 0)
                        delegate: Rectangle { width: 4; height: 4; radius: 2; color: slot.item?.minimizedOnly ? Theme.textDim : Theme.accent }
                    }
                }

                // unread notifications of the app
                Rectangle {
                    visible: (slot.item?.badge ?? 0) > 0
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: -4
                    anchors.topMargin: -4
                    width: Math.max(16, badgeText.implicitWidth + 8)
                    height: 16
                    radius: 8
                    color: Theme.accent
                    UiText { id: badgeText; anchors.centerIn: parent; text: `${Math.min(99, slot.item?.badge ?? 0)}`; size: Theme.sizeCaption; weight: Theme.weightBold; color: Theme.onBrand }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    enabled: slot.fade > 0.4
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    drag.target: null
                    property real pressX: 0
                    property bool dragging: false
                    onPressed: m => { pressX = m.x; dragging = false; }
                    onPositionChanged: m => {
                        if (!(pressedButtons & Qt.LeftButton) || !(slot.item?.pinned)) return;
                        const dx = m.x - pressX;
                        if (Math.abs(dx) > 8) dragging = true;
                        if (dragging) { slot.dragOffset = dx; slot.dragMoved(dx); }
                    }
                    onReleased: m => {
                        if (dragging) { slot.dragEnded(slot.dragOffset); slot.dragOffset = 0; dragging = false; }
                    }
                    onClicked: m => { if (!dragging) slot.clicked(m); }
                }

                // name on hover
                UiText {
                    visible: mouse.containsMouse && slot.label.length > 0
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: slot.label
                    size: Theme.sizeCaption + 1
                    shadow: true
                }
            }

            // every app on one band: pinned first, then the other open ones; the wheel scrolls the band
            Repeater {
                model: win.items
                delegate: Slot {
                    required property var modelData
                    required property int index
                    item: modelData
                    slotNo: index - arc.off - win.half
                    icon: modelData.icon
                    label: modelData.name
                    dim: modelData.minimizedOnly
                    onClicked: m => win.itemClicked(modelData, m, this)
                    onDragEnded: dx => { if (modelData.pinned) Dock.reorder(index, index - Math.round(dx / win.spacing)); }
                }
            }
        }

        // ---- context menu of an app (right click) ----
        Rectangle {
            id: menu
            visible: win.menuItem !== null
            x: Math.max(4, Math.min(frame.width - width - 4, win.menuX - width / 2))
            y: arc.y - height - 46
            width: 190
            height: menuCol.implicitHeight + Theme.spacingSm * 2
            radius: Theme.rowRadius + 4
            color: Theme.alpha(Theme.surface0, 0.92)
            border.width: 1
            border.color: Theme.glassBorder
            transform: Rotation { origin.x: menu.width / 2; origin.y: menu.height / 2; angle: -frame.rotation }

            Column {
                id: menuCol
                anchors.fill: parent
                anchors.margins: Theme.spacingSm
                spacing: 2

                component MenuRow: Rectangle {
                    id: mr
                    property string text: ""
                    signal triggered()
                    width: parent.width
                    height: 28
                    radius: 8
                    color: mrMouse.containsMouse ? Theme.surfaceHi : Theme.transparent
                    UiText { x: 10; anchors.verticalCenter: parent.verticalCenter; text: mr.text; size: Theme.sizeBody }
                    MouseArea { id: mrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { mr.triggered(); win.menuItem = null; } }
                }

                MenuRow { text: win.menuItem?.pinned ? "Quitar del dock" : "Fijar en el dock"; onTriggered: Dock.togglePin(win.menuItem) }
                MenuRow { visible: (win.menuItem?.entry ?? null) !== null; text: "Nueva ventana"; onTriggered: Dock.newInstance(win.menuItem) }
                MenuRow { visible: (win.menuItem?.count ?? 0) > 0; text: `Cerrar todas (${win.menuItem?.count ?? 0})`; onTriggered: Dock.closeAll(win.menuItem) }
                Row {
                    visible: (win.menuItem?.count ?? 0) > 0
                    height: 28
                    spacing: 4
                    UiText { anchors.verticalCenter: parent.verticalCenter; text: "Mover a"; size: Theme.sizeCaption + 1; color: Theme.textDim; leftPadding: 10 }
                    Repeater {
                        model: Hypr.workspaceCount
                        delegate: Rectangle {
                            required property int index
                            width: 24; height: 24; radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: wsMouse.containsMouse ? Theme.accent : Theme.surface2
                            UiText { anchors.centerIn: parent; text: `${index + 1}`; mono: true; size: Theme.sizeCaption; color: wsMouse.containsMouse ? Theme.onBrand : Theme.textSoft }
                            MouseArea { id: wsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Dock.moveAllTo(win.menuItem, index + 1); win.menuItem = null; } }
                        }
                    }
                }
            }
        }
    }

    function itemClicked(item, m, slot): void {
        if (m.button === Qt.RightButton) {
            
            win.menuItem = item;
            win.menuX = slot.x + slot.width / 2 + arc.x;
        } else if (m.button === Qt.MiddleButton) {
            Dock.newInstance(item);
        } else {
            win.menuItem = null;
            
            Dock.activate(item);
        }
    }

    // `arc` lives inside `frame`: expose it for itemClicked
    readonly property Item arcItem: arc
}
