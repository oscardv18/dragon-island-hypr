// One row of FileList; also used for drag sources and folder drop targets.
import QtQuick
import "../.."
import "../../components"
import "files.js" as F

Rectangle {
    id: row
    required property var modelData
    required property int index
    property var tab: null
    property real now: Date.now()
    readonly property var entry: modelData
    readonly property bool isSelected: !!tab?.selected[entry.name]
    readonly property bool isDir: entry.kind === "dir"
    signal activated(var entry)
    signal contextMenu(var entry, real x, real y)
    signal dropOn(string path, var paths, int modifiers)
    // drag payload (read by the DropArea that receives it)
    property var dragPaths: []
    property int dragModifiers: 0
    property real pressX: 0
    property real pressY: 0
    height: Theme.files.row
    radius: Theme.files.rowRadius
    color: drop.containsDrag ? Theme.files.dropTarget : isSelected ? Theme.files.selected : hit.containsMouse ? Theme.files.hover
         : index % 2 === 1 ? Theme.files.rowAlt : Theme.transparent
    border.width: isSelected ? Theme.files.border : 0
    border.color: Theme.files.selectedBorder
    opacity: entry.hidden ? Theme.files.disabledOpacity + (1 - Theme.files.disabledOpacity) / 2 : 1
    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.files.inset
        anchors.rightMargin: Theme.files.inset
        spacing: 0
        readonly property real nameWidth: width - Theme.files.sizeColumn - Theme.files.dateColumn - Theme.files.typeColumn - Theme.files.gap * 2
        Item {
            width: parent.nameWidth
            height: parent.height
            FileIcon { id: icon; entry: row.entry; anchors.verticalCenter: parent.verticalCenter }
            UiText {
                id: name
                anchors.left: icon.right
                anchors.leftMargin: Theme.files.inset
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - icon.width - Theme.files.inset * 2 - (git.visible ? git.width + Theme.files.inset : 0))
                text: row.entry.name
                size: Theme.files.body
                color: row.entry.broken ? Theme.danger : Theme.text
            }
            GitBadge { id: git; mark: row.entry.git ?? ""; anchors.left: name.right; anchors.leftMargin: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter }
        }
        Cell { width: Theme.files.sizeColumn; horizontalAlignment: Text.AlignRight; text: row.isDir ? F.formatCount(row.entry.count) : F.formatSize(row.entry.size) }
        Item { width: Theme.files.gap; height: 1 }
        Cell { width: Theme.files.dateColumn; text: F.relTime(row.entry.mtime, row.now) }
        Item { width: Theme.files.gap; height: 1 }
        Cell { width: Theme.files.typeColumn; text: F.typeLabel(row.entry); color: Theme.textDim; mono: false; size: Theme.files.small }
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: dragProxy
        drag.threshold: Theme.files.dragThreshold
        onPressed: e => {
            if (e.button === Qt.RightButton) { if (!row.isSelected) row.tab?.select(row.index, 0); row.contextMenu(row.entry, e.x, e.y); return; }
            if (!row.isSelected || (e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) row.tab?.select(row.index, e.modifiers);
            row.dragPaths = row.tab?.selectedPaths() ?? [];
            row.pressX = e.x; row.pressY = e.y;
            row.dragModifiers = e.modifiers;
        }
        onReleased: e => {
            if (!drag.active && e.button === Qt.LeftButton && !(e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && row.isSelected
                && (row.tab?.selection.length ?? 0) > 1) row.tab.select(row.index, 0);
            if (drag.active) { row.dragModifiers = e.modifiers; dragProxy.Drag.drop(); }
            dragProxy.x = 0; dragProxy.y = 0;
        }
        onDoubleClicked: e => { if (e.button === Qt.LeftButton) row.activated(row.entry); }
    }
    // what actually moves under the pointer: Drag hit-tests at its position, the row itself stays in place
    Item {
        id: dragProxy
        width: Theme.files.inset
        height: Theme.files.inset
        Drag.active: hit.drag.active
        Drag.keys: ["dragon-files"]
        Drag.source: row
        Drag.hotSpot.x: row.pressX
        Drag.hotSpot.y: row.pressY
    }
    DropArea {
        id: drop
        anchors.fill: parent
        enabled: row.isDir
        keys: ["dragon-files"]
        onEntered: d => { if (d.source === row) d.accepted = false; }
        onDropped: d => { row.dropOn(row.tab.pathOf(row.entry), d.source?.dragPaths ?? [], d.source?.dragModifiers ?? 0); d.accept(); }
    }
    component Cell: UiText {
        height: parent.height
        mono: true
        size: Theme.files.mono
        color: Theme.textSoft
    }
}
