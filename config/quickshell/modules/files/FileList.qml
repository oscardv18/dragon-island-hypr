// List view (33-archivos-lista.png): NOMBRE · TAMAÑO · MODIFICADO · TIPO, git mark after the name, alternate rows,
// selected rows with the cyan edge. Click / Ctrl / Shift select, double click opens, right click asks for the menu,
// dragging the selection starts an internal drag (keys "dragon-files") that sidebar rows, tabs and folders accept.
import QtQuick
import "../.."
import "../../components"
import "files.js" as F

Item {
    id: root
    property var tab: null
    property var view: null
    property real now: Date.now()
    signal activated(var entry)
    signal contextMenu(var entry, real x, real y)
    signal dropOn(string path, var paths, int modifiers)
    readonly property alias listView: list

    Row {
        id: header
        width: parent.width
        height: Theme.files.headerRow
        leftPadding: Theme.files.inset
        rightPadding: Theme.files.inset
        readonly property real nameWidth: width - leftPadding - rightPadding - Theme.files.sizeColumn - Theme.files.dateColumn - Theme.files.typeColumn - Theme.files.gap * 2
        HeaderCell { width: header.nameWidth; key: "name"; text: "Nombre" }
        HeaderCell { width: Theme.files.sizeColumn; key: "size"; text: "Tamaño"; horizontalAlignment: Text.AlignRight }
        Item { width: Theme.files.gap; height: 1 }
        HeaderCell { width: Theme.files.dateColumn; key: "mtime"; text: "Modificado" }
        Item { width: Theme.files.gap; height: 1 }
        HeaderCell { width: Theme.files.typeColumn; key: "type"; text: "Tipo" }
    }
    ListView {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: Theme.files.smallGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: root.tab?.shown ?? []
        currentIndex: root.tab?.currentIndex ?? -1
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        cacheBuffer: Theme.files.row * 10
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: FileRow {
            width: list.width
            tab: root.tab
            now: root.now
            onActivated: e => root.activated(e)
            onContextMenu: (e, x, y) => { const p = mapToItem(root, x, y); root.contextMenu(e, p.x, p.y); }
            onDropOn: (path, paths, mods) => root.dropOn(path, paths, mods)
        }
        MouseArea {
            // empty space: clear the selection / menu of the folder itself
            z: -1
            width: list.width
            height: Math.max(list.height, list.contentHeight)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => { root.tab?.clearSelection(); if (e.button === Qt.RightButton) root.contextMenu(null, e.x, e.y + header.height); }
        }
    }
    component HeaderCell: UiText {
        property string key
        height: Theme.files.headerRow
        mono: true
        size: Theme.files.caption
        font.letterSpacing: Theme.files.captionTracking
        font.capitalization: Font.AllUppercase
        color: root.view?.sortKey === key ? Theme.text : Theme.textDim
        text: ""
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.view?.setSort(parent.key) }
    }
}
