// =============================================================================
// dragon-island — DockWindow.qml (namespace "dragon-dock")
// The dock is a glass tab that sticks out of the screen edge (bottom, left or right: Dock.position), like the notch
// but from the other side. The layer window has exactly the tab's size, so hyprglass draws the same liquid glass
// (rim, refraction) as on Ghostty; the corners away from the edge are rounded by a Rectangle that runs past the
// edge, and the translucent fill is what hyprglass masks by (mask_mode = "alpha").
// Hiding: the tab sinks into the edge (the content slides out of the window); the 3 px hot zone is a strip of this
// same window, so the pointer never changes surface. Wheel: scrolls the capsules when there are more than
// Theme.dockCapacity. Right click on a capsule: its menu; on the glass: the dock settings (position, always visible).
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
    readonly property string pos: Dock.position
    readonly property bool horiz: pos === "bottom"

    // ------------------------------------------------------------ model
    readonly property var items: Dock.pinnedItems.concat(Dock.openItems)       // pinned first, then the other open apps
    readonly property int shown: Math.max(1, Math.min(items.length, Theme.dockCapacity))
    readonly property int maxOff: Math.max(0, items.length - Theme.dockCapacity)
    readonly property real length: Theme.dockPad * 2 + shown * Theme.dockPitch - (Theme.dockPitch - Theme.dockPill)

    anchors {
        bottom: pos === "bottom"
        left: pos === "left"
        right: pos === "right"
    }
    implicitWidth: horiz ? length : Theme.dockThickness
    implicitHeight: horiz ? Theme.dockThickness : length
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dragon-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // visible tab, or only the hot-zone strip while hidden
    mask: Region {
        Region { item: strip }                  // always: while the tab is still rising the pointer is on the strip
        Region { item: Dock.wanted ? hitbox : null }
    }

    // the window's own rectangle (the tab moves while it rises, a Region does not follow the movement of an ancestor)
    Item { id: hitbox; anchors.fill: parent }

    // the hot zone: a thin strip on the screen edge
    Item {
        id: strip
        x: win.pos === "right" ? win.width - Theme.dockEdge : 0
        y: win.pos === "bottom" ? win.height - Theme.dockEdge : 0
        width: win.horiz ? win.width : Theme.dockEdge
        height: win.horiz ? Theme.dockEdge : win.height
        Rectangle { anchors.fill: parent; color: "#01000000" }
        HoverHandler { id: stripHover }
    }
    readonly property bool pointerOn: stripHover.hovered || tabHover.hovered
    onPointerOnChanged: Dock.hover(pointerOn)

    // ------------------------------------------------------------ the tab
    Item {
        id: content
        width: win.width
        height: win.height
        property real sink: Dock.wanted ? 0 : Theme.dockThickness + Theme.dockRadius + 6
        Behavior on sink { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping; epsilon: 0.2 } }
        x: win.pos === "left" ? -sink : (win.pos === "right" ? sink : 0)
        y: win.pos === "bottom" ? sink : 0

        property int target: 0
        property real off: target
        Behavior on off { enabled: Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping; epsilon: 0.005 } }
        Connections {
            target: win
            function onMaxOffChanged() { content.target = Math.min(content.target, win.maxOff); }
        }

        // The tab: a rounded rectangle that runs past the screen edge, so only the outer corners are rounded.
        Rectangle {
            id: tab
            x: win.pos === "right" ? 0 : (win.pos === "left" ? -Theme.dockRadius : 0)
            y: 0
            width: win.horiz ? win.width : win.width + Theme.dockRadius
            height: win.horiz ? win.height + Theme.dockRadius : win.height
            radius: Theme.dockRadius
            color: Theme.glassBg
        }

        HoverHandler { id: tabHover }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => content.target = Math.max(0, Math.min(win.maxOff, content.target + (e.angleDelta.y > 0 ? -1 : 1)))
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: win.openMenu(null, tab)
        }

        component Slot: Item {
            id: slot
            property var item: null
            property int slotIdx: 0
            property string icon: ""
            property string label: ""
            property bool dim: false
            property real dragOffset: 0
            readonly property bool hovered: mouse.containsMouse
            signal clicked(var mouse)
            signal dragEnded(real dx)

            readonly property real rel: slotIdx - content.off                    // 0 .. capacity-1 when fully visible
            readonly property real out: Math.max(-rel, rel - (Theme.dockCapacity - 1))
            readonly property real fade: Math.max(0, Math.min(1, 1 - out / 0.8))
            readonly property real along: Theme.dockPad + Theme.dockPill / 2 + rel * Theme.dockPitch + dragOffset
            readonly property real cross: Theme.dockThickness / 2

            width: Theme.dockPill
            height: Theme.dockPill
            x: (win.horiz ? along : cross) - width / 2
            y: (win.horiz ? cross : along) - height / 2
            opacity: (dim ? 0.45 : 1) * fade
            Behavior on opacity { NumberAnimation { duration: Theme.durFade } }

            Rectangle {
                anchors.fill: parent
                radius: Theme.capsuleRadius + 5
                color: slot.hovered ? Theme.pillBgHi : Theme.pillBg
                Behavior on color { ColorAnimation { duration: Theme.durHover } }
            }
            Image {
                anchors.centerIn: parent
                width: Theme.dockIconInner
                height: Theme.dockIconInner
                source: slot.icon
                sourceSize: Qt.size(Theme.dockIconInner * 2, Theme.dockIconInner * 2)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                mipmap: true
            }

            // open windows: 1 to 3 dots
            Row {
                visible: (slot.item?.count ?? 0) > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
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
                hoverEnabled: true
                enabled: slot.fade > 0.4
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                property real pressPos: 0
                property bool dragging: false
                onPressed: m => { pressPos = win.horiz ? m.x : m.y; dragging = false; }
                onPositionChanged: m => {
                    if (!(pressedButtons & Qt.LeftButton) || !(slot.item?.pinned)) return;
                    const d = (win.horiz ? m.x : m.y) - pressPos;
                    if (Math.abs(d) > 8) dragging = true;
                    if (dragging) slot.dragOffset = d;
                }
                onReleased: m => {
                    if (dragging) { slot.dragEnded(slot.dragOffset); slot.dragOffset = 0; dragging = false; }
                }
                onClicked: m => { if (!dragging) slot.clicked(m); }
            }
        }

        Repeater {
            model: win.items
            delegate: Slot {
                id: sl
                required property var modelData
                required property int index
                item: modelData
                slotIdx: index
                icon: modelData.icon
                label: modelData.name
                dim: modelData.minimizedOnly
                onHoveredChanged: win.hoverSlot = hovered ? sl : (win.hoverSlot === sl ? null : win.hoverSlot)
                onClicked: m => win.itemClicked(modelData, m, sl)
                onDragEnded: dx => Dock.reorder(index, index + Math.round(dx / Theme.dockPitch))
            }
        }
    }

    // ------------------------------------------------------------ name tooltip, app menu and dock settings
    property var hoverSlot: null
    property var menuItem: null         // app of the open menu; null + menuOpen = the dock settings
    property bool menuOpen: false
    property Item menuAnchor: tab

    function openMenu(item, anchorItem): void {
        win.menuItem = item;
        win.menuAnchor = anchorItem;
        win.menuOpen = true;
    }
    function itemClicked(item, m, slot): void {
        if (m.button === Qt.RightButton) win.openMenu(item, slot);
        else if (m.button === Qt.MiddleButton) Dock.newInstance(item);
        else { win.menuOpen = false; Dock.activate(item); }
    }

    Connections {
        target: Dock
        function onWantedChanged() { if (!Dock.wanted) win.menuOpen = false; }
    }

    // the popups open away from the edge
    readonly property var popEdge: pos === "bottom" ? Edges.Top : (pos === "left" ? Edges.Right : Edges.Left)

    PopupWindow {
        id: tip
        visible: win.hoverSlot !== null && !win.menuOpen && Dock.wanted && (win.hoverSlot?.label ?? "").length > 0
        anchor.item: win.hoverSlot
        anchor.edges: win.popEdge
        anchor.gravity: win.popEdge
        anchor.margins.top: 8
        anchor.margins.left: 8
        anchor.margins.right: 8
        implicitWidth: tipLabel.implicitWidth + 24
        implicitHeight: 28
        color: Theme.transparent
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.alpha(Theme.surface0, 0.92)
            UiText { id: tipLabel; anchors.centerIn: parent; text: win.hoverSlot?.label ?? ""; size: Theme.sizeBody }
        }
    }

    PopupWindow {
        id: menu
        visible: win.menuOpen
        anchor.item: win.menuAnchor
        anchor.edges: win.popEdge
        anchor.gravity: win.popEdge
        anchor.margins.top: 10
        anchor.margins.left: 10
        anchor.margins.right: 10
        implicitWidth: 200
        implicitHeight: menuCol.implicitHeight + Theme.spacingSm * 2
        color: Theme.transparent

        Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius + 4
            color: Theme.alpha(Theme.surface0, 0.94)
            border.width: 1
            border.color: Theme.glassBorder
            HoverHandler { onHoveredChanged: Dock.hover(hovered) }

            Column {
                id: menuCol
                anchors.fill: parent
                anchors.margins: Theme.spacingSm
                spacing: 2

                component MenuRow: Rectangle {
                    id: mr
                    property string text: ""
                    property bool checked: false
                    signal triggered()
                    width: parent.width
                    height: 28
                    radius: 8
                    color: mrMouse.containsMouse ? Theme.surfaceHi : Theme.transparent
                    UiText { x: 10; anchors.verticalCenter: parent.verticalCenter; text: mr.text; size: Theme.sizeBody }
                    Rectangle { visible: mr.checked; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Theme.accent }
                    MouseArea { id: mrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { mr.triggered(); win.menuOpen = false; } }
                }

                // ---- an app ----
                MenuRow { visible: win.menuItem !== null; text: win.menuItem?.pinned ? "Quitar del dock" : "Fijar en el dock"; onTriggered: Dock.togglePin(win.menuItem) }
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
                            MouseArea { id: wsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Dock.moveAllTo(win.menuItem, index + 1); win.menuOpen = false; } }
                        }
                    }
                }

                // ---- the dock ----
                UiText { visible: win.menuItem === null; text: "Dock"; caption: true; leftPadding: 10; topPadding: 4 }
                MenuRow { visible: win.menuItem === null; text: "Abajo"; checked: Dock.position === "bottom"; onTriggered: Dock.setPosition("bottom") }
                MenuRow { visible: win.menuItem === null; text: "Izquierda"; checked: Dock.position === "left"; onTriggered: Dock.setPosition("left") }
                MenuRow { visible: win.menuItem === null; text: "Derecha"; checked: Dock.position === "right"; onTriggered: Dock.setPosition("right") }
                MenuRow { visible: win.menuItem === null; text: "Siempre visible"; checked: Dock.alwaysVisible; onTriggered: Dock.togglePinned() }
            }
        }
    }
}
