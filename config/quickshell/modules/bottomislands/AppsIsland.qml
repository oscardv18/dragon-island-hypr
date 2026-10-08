// Right bottom island: apps that are closed-but-alive (tray, windows in other workspaces, watched processes).
// Pure visual: replica of the top bar's islands (glassBg, radius 14, 1 px border, height 40, padding 0 6, 28/30 px chips).
// Chips that do not fit become one "+N" chip. Everything goes out through signals; the window owns popups and menus.
import QtQuick
import "../.."
import "../../components"
import "../island"

Item {
    id: root

    property real fixedWidth: 0      // the island is at least this wide (the tab is as wide as the top islands)

    property var entries: []
    property real maxWidth: 10000
    property var iconProvider: (entry, failed) => ""      // function(entry, failed) → Image source
    property var openKey: ""                                // entry key whose menu is open ("" = none, "+more" = the overflow popover)
    readonly property real pitch: Theme.bottomChip + Theme.barIslandGap
    readonly property real innerMax: Math.max(0, maxWidth - Theme.notchEarRadius * 2 - Theme.barIslandPadH * 2)
    readonly property int capacity: Math.max(1, Math.floor((innerMax + Theme.barIslandGap) / pitch))
    readonly property bool overflow: entries.length > capacity
    readonly property var shownEntries: overflow ? entries.slice(0, Math.max(0, capacity - 1)) : entries
    readonly property var hiddenEntries: overflow ? entries.slice(Math.max(0, capacity - 1)) : []

    // Qt gives hover to the chip's MouseArea and not to the HoverHandler of the zone behind it: the window ORs this in
    property string hoveredKey: ""
    readonly property bool pointerOver: hoveredKey !== "" || moreMouse.containsMouse

    signal chipActivated(var entry, Item chip)
    signal chipSecondary(var entry)
    signal chipContext(var entry, Item chip)
    signal chipScrolled(var entry, int dx, int dy)
    signal chipHovered(var entry, Item chip, bool on)
    signal moreClicked(Item chip)

    implicitHeight: Theme.dockThickness
    height: Theme.dockThickness
    width: Math.max(fixedWidth, Theme.notchEarRadius * 2 + Theme.barIslandPadH * 2 + row.implicitWidth)

    // the dock's silhouette (concave ears at the screen edge, rounded far corners), opaque black like the notch
    NotchShape {
        anchors.fill: parent
        rotation: 180
    }

    Row {
        id: row
        x: Theme.notchEarRadius + Theme.barIslandPadH
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barIslandGap

        Repeater {
            model: root.shownEntries
            delegate: AppChip {
                id: chip
                required property var modelData
                entry: modelData
                iconSource: root.iconProvider(modelData, false)
                fallbackSource: root.iconProvider(modelData, true)
                open: root.openKey === modelData.key
                onActivated: root.chipActivated(modelData, chip)
                onSecondary: root.chipSecondary(modelData)
                onContext: root.chipContext(modelData, chip)
                onScrolled: (dx, dy) => root.chipScrolled(modelData, dx, dy)
                onHoveredChanged: { root.chipHovered(modelData, chip, hovered); if (hovered) root.hoveredKey = modelData.key; else if (root.hoveredKey === modelData.key) root.hoveredKey = ""; }
                Component.onDestruction: if (root.hoveredKey === modelData.key) root.hoveredKey = ""
            }
        }

        // "+N": the apps that did not fit
        Item {
            id: more
            visible: root.overflow
            width: Theme.bottomChip
            height: Theme.bottomChip
            Rectangle {
                anchors.fill: parent
                radius: Theme.capsuleRadius
                color: root.openKey === "+more" || moreMouse.containsMouse ? Theme.surfaceHi : Theme.surface2
                Behavior on color { ColorAnimation { duration: Theme.durHover } }
            }
            UiText { anchors.centerIn: parent; text: `+${root.hiddenEntries.length}`; mono: true; size: Theme.sizeCaption + 1; weight: Theme.weightSemiBold; color: Theme.textSoft }
            MouseArea { id: moreMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.moreClicked(more) }
        }

        UiText {
            id: empty
            visible: root.entries.length === 0
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 4
            rightPadding: 4
            text: "Sin apps en segundo plano"
            size: Theme.sizeBar
            color: Theme.textDim
        }
    }
}
