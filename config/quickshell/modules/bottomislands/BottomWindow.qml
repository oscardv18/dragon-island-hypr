// =============================================================================
// dragon-island — BottomWindow.qml (namespace "dragon-bottom-islands")
// One per monitor. A full-width, transparent layer window as tall as an island plus its margin, that never reserves
// space (ExclusionMode.Ignore). While hidden, its input mask is ONLY the invisible detection strip of each island
// (Theme.bottomStrip..., BottomConfig.stripHeight px at the very bottom edge, same width as the island it will show),
// so clicks everywhere else reach the windows below. While an island is on its way in / out / shown, its mask is the
// whole zone: island ∪ the margin under it ∪ the strip — one rectangle, so there is no gap to flicker in.
// The pointer is read with HoverHandlers inside this window (Wayland has no global cursor position).
// The islands sit at the sides of the dock: inner edge = screen centre ∓ (Theme.dockMaxLength / 2 + Theme.bottomDockGap).
// =============================================================================
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../.."
import "../../services"
import "../../components"

PanelWindow {
    id: win

    property var modelData
    screen: modelData
    readonly property string screenName: modelData?.name ?? ""

    readonly property real riseRoom: 6                          // room above the island for the OutBack overshoot
    readonly property real islandY: riseRoom
    anchors { bottom: true; left: true; right: true }
    implicitHeight: riseRoom + Theme.barHeight + Theme.bottomMargin
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparent

    WlrLayershell.namespace: "dragon-bottom-islands"
    WlrLayershell.layer: BottomConfig.layer === "overlay" ? WlrLayer.Overlay : WlrLayer.Top
    // keyboard only on demand (a click on the island), so Esc can hide it without stealing typing from the apps
    WlrLayershell.keyboardFocus: rightRev.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property string rightPhase: rightRev.phase
    readonly property real strip: BottomConfig.stripHeight

    function command(action: string, side: string): void {
        if (side === "right" || side === "both") {
            if (action === "reveal") rightRev.reveal(); else if (action === "hide") { rightRev.hide(); win.closePopups(); } else rightRev.toggle();
        }
    }

    // ------------------------------------------------------------ geometry
    readonly property real rightX: win.width / 2 + Theme.dockMaxLength / 2 + Theme.bottomDockGap
    readonly property real rightMax: Math.max(0, win.width - Theme.barMarginSide - rightX)

    // detection strips + zones (invisible items: only their geometry matters)
    Item {
        id: rightZone      // island ∪ margin ∪ strip
        x: win.rightX
        y: win.islandY
        width: rightIsland.width
        height: win.height - win.islandY
        HoverHandler { id: rightHover }
    }
    Item {
        id: rightStrip
        x: rightZone.x
        y: win.height - win.strip
        width: rightZone.width
        height: win.strip
    }

    mask: Region {
        Region { item: rightRev.active ? rightZone : rightStrip }
    }

    // ------------------------------------------------------------ state machine
    HoverReveal {
        id: rightRev
        pointerInside: rightHover.hovered
        holdOpen: win.popupOpen
    }

    // the process table is only read while the island is on screen
    readonly property bool rightOn: rightRev.active
    onRightOnChanged: BackgroundApps.setWatching(rightOn)

    // ------------------------------------------------------------ the right island
    Item {
        id: rightHolder
        x: win.rightX
        y: win.islandY + (1 - Math.min(1.15, rightRev.progress)) * Theme.bottomRise
        width: rightIsland.width
        height: Theme.barHeight
        visible: rightRev.progress > 0.002
        opacity: Math.max(0, Math.min(1, rightRev.progress))

        AppsIsland {
            id: rightIsland
            entries: BackgroundApps.entries
            maxWidth: win.rightMax
            iconProvider: (e, failed) => BackgroundApps.icon(e, failed)
            openKey: win.moreOpen ? "+more" : (win.menuEntry && (win.ctxOpen || trayMenu.visible) ? win.menuEntry.key : "")
            onChipActivated: (e, chip) => { win.pick(e, chip); BackgroundApps.activate(e, trayMenu); }
            onChipSecondary: e => BackgroundApps.secondaryActivate(e)
            onChipContext: (e, chip) => win.openContext(e, chip)
            onChipScrolled: (e, dx, dy) => BackgroundApps.scroll(e, dx, dy)
            onChipHovered: (e, chip, on) => { if (on) { win.tipEntry = e; win.tipItem = chip; } else if (win.tipEntry === e) win.tipEntry = null; }
            onMoreClicked: chip => win.openMore(chip)
        }
    }

    // Esc hides the island
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: { rightRev.hide(); win.closePopups(); }
    }

    // ------------------------------------------------------------ popups (open upwards, anchored to their chip)
    property var tipEntry: null
    property Item tipItem: null
    property var menuEntry: null         // app of the menu / context popup
    property Item menuItem: null
    property bool ctxOpen: false
    property bool moreOpen: false
    readonly property bool popupOpen: ctxOpen || moreOpen || trayMenu.visible

    function pick(entry, chip): void { win.menuEntry = entry; win.menuItem = chip; }
    function closePopups(): void { win.ctxOpen = false; win.moreOpen = false; if (trayMenu.visible) trayMenu.close(); win.tipEntry = null; }

    function openContext(entry, chip): void {
        win.pick(entry, chip);
        win.moreOpen = false;
        if (entry.trayItem?.hasMenu) { win.ctxOpen = false; trayMenu.open(); }
        else win.ctxOpen = true;
    }
    function openMore(chip): void {
        win.ctxOpen = false;
        win.menuItem = chip;
        win.moreOpen = !win.moreOpen;
    }

    QsMenuAnchor {
        id: trayMenu
        menu: win.menuEntry?.trayItem?.menu ?? null
        anchor.item: win.menuItem
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: Theme.popoverGap
    }

    HyprlandFocusGrab {
        windows: [win, ctxPop, morePop]
        active: win.ctxOpen || win.moreOpen
        onCleared: win.closePopups()
    }

    // tooltip: name, state, workspace, pid — only what is known
    PopupWindow {
        id: tip
        visible: win.tipEntry !== null && !win.popupOpen && rightRev.phase === "shown"
        anchor.item: win.tipItem
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: Theme.popoverGap
        implicitWidth: Math.max(tipName.implicitWidth, tipState.implicitWidth, tipPid.implicitWidth) + 24
        implicitHeight: tipCol.implicitHeight + 16
        color: Theme.transparent
        Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius
            color: Theme.alpha(Theme.surface0, 0.94)
            border.width: 1
            border.color: Theme.glassBorder
            Column {
                id: tipCol
                anchors.centerIn: parent
                spacing: 2
                UiText { id: tipName; text: win.tipEntry?.label ?? ""; size: Theme.sizeBody; weight: Theme.weightSemiBold }
                UiText { id: tipState; text: BackgroundApps.stateText(win.tipEntry); size: Theme.sizeCaption + 1; color: Theme.textSoft }
                UiText { id: tipPid; visible: (win.tipEntry?.pid ?? 0) > 0; text: `PID ${win.tipEntry?.pid ?? 0}`; mono: true; size: Theme.sizeCaption; color: Theme.textDim }
            }
        }
    }

    // context menu for apps without a tray menu
    PopupWindow {
        id: ctxPop
        visible: win.ctxOpen
        anchor.item: win.menuItem
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: Theme.popoverGap
        implicitWidth: 180
        implicitHeight: ctxCol.implicitHeight + Theme.spacingSm * 2
        color: Theme.transparent
        Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius + 4
            color: Theme.alpha(Theme.surface0, 0.94)
            border.width: 1
            border.color: Theme.glassBorder
            Column {
                id: ctxCol
                anchors.fill: parent
                anchors.margins: Theme.spacingSm
                spacing: 2
                PopRow { text: "Abrir"; onTriggered: { BackgroundApps.activate(win.menuEntry, trayMenu); win.closePopups(); } }
                PopRow { visible: (win.menuEntry?.windows?.length ?? 0) > 0; text: "Cerrar ventana"; onTriggered: { BackgroundApps.closeWindows(win.menuEntry); win.closePopups(); } }
            }
        }
    }

    // overflow list: every app
    PopupWindow {
        id: morePop
        visible: win.moreOpen
        anchor.item: win.menuItem
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: Theme.popoverGap
        implicitWidth: Theme.bottomPopoverW
        implicitHeight: moreCol.implicitHeight + Theme.spacingSm * 2
        color: Theme.transparent
        Rectangle {
            anchors.fill: parent
            radius: Theme.rowRadius + 4
            color: Theme.alpha(Theme.surface0, 0.94)
            border.width: 1
            border.color: Theme.glassBorder
            Column {
                id: moreCol
                anchors.fill: parent
                anchors.margins: Theme.spacingSm
                spacing: 2
                Repeater {
                    model: ScriptModel { values: BackgroundApps.entries; objectProp: "key" }
                    delegate: PopRow {
                        id: mr
                        required property var modelData
                        text: modelData.label
                        detail: BackgroundApps.stateText(modelData)
                        icon: BackgroundApps.icon(modelData, false)
                        onTriggered: { win.pick(modelData, win.menuItem); BackgroundApps.activate(modelData, trayMenu); win.closePopups(); }
                    }
                }
            }
        }
    }

    component PopRow: Rectangle {
        id: pr
        property string text: ""
        property string detail: ""
        property string icon: ""
        signal triggered()
        width: parent ? parent.width : 0
        height: detail !== "" ? 40 : 28
        radius: 8
        color: prMouse.containsMouse ? Theme.surfaceHi : Theme.transparent
        Image {
            visible: pr.icon !== ""
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            source: pr.icon
            sourceSize: Qt.size(44, 44)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        Column {
            x: pr.icon !== "" ? 38 : 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 8
            UiText { width: parent.width; text: pr.text; size: Theme.sizeBody }
            UiText { visible: pr.detail !== ""; width: parent.width; text: pr.detail; size: Theme.sizeCaption + 1; color: Theme.textDim }
        }
        MouseArea { id: prMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pr.triggered() }
    }
}
