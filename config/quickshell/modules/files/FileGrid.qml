// Grid view (33-archivos-cuadricula.png): tiles with a thumbnail (images and videos, from the standard cache via
// Files.thumb, requested only for the tiles that exist) or the type icon, and the name below.
import QtQuick
import "../.."
import "../../components"

Item {
    id: root
    property var tab: null
    property var files: null
    signal activated(var entry)
    signal contextMenu(var entry, real x, real y)
    signal dropOn(string path, var paths, int modifiers)
    readonly property int columns: Math.max(1, Math.floor((width + Theme.files.tileGap) / (Theme.files.tileWidth + Theme.files.tileGap)))
    readonly property alias gridView: grid
    GridView {
        id: grid
        anchors.fill: parent
        clip: true
        cellWidth: Theme.files.tileWidth + Theme.files.tileGap
        cellHeight: Theme.files.tileHeight + Theme.files.tileGap
        model: root.tab?.shown ?? []
        currentIndex: root.tab?.currentIndex ?? -1
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: cellHeight * 2
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
        delegate: FileTile {
            tab: root.tab
            files: root.files
            onActivated: e => root.activated(e)
            onContextMenu: (e, x, y) => { const p = mapToItem(root, x, y); root.contextMenu(e, p.x, p.y); }
            onDropOn: (path, paths, mods) => root.dropOn(path, paths, mods)
        }
        MouseArea {
            z: -1
            width: grid.width
            height: Math.max(grid.height, grid.contentHeight)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => { root.tab?.clearSelection(); if (e.button === Qt.RightButton) root.contextMenu(null, e.x, e.y); }
        }
    }
}
