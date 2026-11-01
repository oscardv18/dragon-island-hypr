// One tile of FileGrid. The thumbnail is asked for once per path+mtime; until it arrives (or when there is no
// thumbnailer) the type icon stays.
import QtQuick
import "../.."
import "../../components"
import "files.js" as F

Item {
    id: tile
    required property var modelData
    required property int index
    property var tab: null
    property var files: null
    readonly property var entry: modelData
    readonly property bool isSelected: !!tab?.selected[entry.name]
    readonly property bool isDir: entry.kind === "dir"
    readonly property bool wantsThumb: F.isImage(entry) || F.isVideo(entry) || F.extOf(entry.name) === ".pdf"
    property string thumbFile: ""
    property var dragPaths: []
    property int dragModifiers: 0
    property real pressX: 0
    property real pressY: 0
    signal activated(var entry)
    signal contextMenu(var entry, real x, real y)
    signal dropOn(string path, var paths, int modifiers)
    width: Theme.files.tileWidth
    height: Theme.files.tileHeight
    function requestThumb(): void {
        thumbFile = "";
        if (!wantsThumb || !files) return;
        const key = entry.name;
        files.thumb(tab.pathOf(entry), entry.mtime, f => { if (key === tile.entry.name && f) tile.thumbFile = f; });
    }
    onEntryChanged: requestThumb()
    Component.onCompleted: requestThumb()
    Rectangle {
        anchors.fill: parent
        radius: Theme.files.rowRadius + Theme.files.thinGap
        color: drop.containsDrag ? Theme.files.dropTarget : tile.isSelected ? Theme.files.selected : hit.containsMouse ? Theme.files.hover : Theme.files.rowAlt
        border.width: tile.isSelected ? Theme.files.border : 0
        border.color: Theme.files.selectedBorder
    }
    Rectangle {
        id: thumbBox
        x: Theme.files.smallGap
        y: Theme.files.smallGap
        width: parent.width - Theme.files.smallGap * 2
        height: Theme.files.thumbHeight
        radius: Theme.files.thumbRadius
        color: Theme.files.thumb
        clip: true
        Image {
            id: image
            anchors.fill: parent
            visible: status === Image.Ready
            source: tile.thumbFile ? "file://" + tile.thumbFile : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Theme.files.thumbPx
            cache: true
        }
        FileIcon { anchors.centerIn: parent; visible: !image.visible; entry: tile.entry; size: Theme.files.thumbIcon }
    }
    UiText {
        anchors.left: thumbBox.left
        anchors.right: git.visible ? git.left : thumbBox.right
        anchors.rightMargin: git.visible ? Theme.files.smallGap : 0
        anchors.top: thumbBox.bottom
        anchors.bottom: parent.bottom
        text: tile.entry.name
        size: Theme.files.small
        color: Theme.text
        elide: Text.ElideMiddle
    }
    GitBadge { id: git; mark: tile.entry.git ?? ""; anchors.right: thumbBox.right; y: thumbBox.y + thumbBox.height + (tile.height - thumbBox.y - thumbBox.height - height) / 2 }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: dragProxy
        drag.threshold: Theme.files.dragThreshold
        onPressed: e => {
            if (e.button === Qt.RightButton) { if (!tile.isSelected) tile.tab?.select(tile.index, 0); tile.contextMenu(tile.entry, e.x, e.y); return; }
            if (!tile.isSelected || (e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) tile.tab?.select(tile.index, e.modifiers);
            tile.dragPaths = tile.tab?.selectedPaths() ?? [];
            tile.pressX = e.x; tile.pressY = e.y;
        }
        onReleased: e => {
            if (!drag.active && e.button === Qt.LeftButton && !(e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && tile.isSelected
                && (tile.tab?.selection.length ?? 0) > 1) tile.tab.select(tile.index, 0);
            if (drag.active) { tile.dragModifiers = e.modifiers; dragProxy.Drag.drop(); }
            dragProxy.x = 0; dragProxy.y = 0;
        }
        onDoubleClicked: e => { if (e.button === Qt.LeftButton) tile.activated(tile.entry); }
    }
    Item {
        id: dragProxy
        width: Theme.files.inset
        height: Theme.files.inset
        Drag.active: hit.drag.active
        Drag.keys: ["dragon-files"]
        Drag.source: tile
        Drag.hotSpot.x: tile.pressX
        Drag.hotSpot.y: tile.pressY
    }
    DropArea {
        id: drop
        anchors.fill: parent
        enabled: tile.isDir
        keys: ["dragon-files"]
        onEntered: d => { if (d.source === tile) d.accepted = false; }
        onDropped: d => { tile.dropOn(tile.tab.pathOf(tile.entry), d.source?.dragPaths ?? [], d.source?.dragModifiers ?? 0); d.accept(); }
    }
}
