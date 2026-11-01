// Explorer sidebar (33-archivos-*): LUGARES (XDG folders, projects with a repo mark, bookmarks), DISPOSITIVOS (space
// bar, ⏏, «abrir» for encrypted ones), RED (local network, mounts, saved servers) and Papelera.
// Pure view: services are injected; it only emits what the user asked for.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "files.js" as F

Rectangle {
    id: root
    property var files: null
    property var devices: null
    property string currentPath: ""
    signal navigate(string path)
    signal dropOn(string path, var paths, int modifiers)
    signal deviceAction(var device, string action)      // mount | unmount | eject | unlock
    signal netAction(var item, string action)           // open | connect
    color: Theme.files.sidebar
    readonly property var placeIcons: ({ home: Icons.home, desktop: Icons.monitor, documents: Icons.fileDoc, downloads: Icons.download,
                                         pictures: Icons.fileImage, music: Icons.music, videos: Icons.fileVideo, project: Icons.fileCode,
                                         bookmark: Icons.folderOutline })
    readonly property var placeList: (files?.places ?? []).filter(p => p.kind !== "trash")
    readonly property var deviceList: root.devices?.devices ?? []
    readonly property var trashPlace: (files?.places ?? []).find(p => p.kind === "trash") ?? { path: F.TRASH, badge: null }

    Rectangle { anchors.right: parent.right; width: Theme.files.border; height: parent.height; color: Theme.files.divider }
    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.files.padding
        anchors.rightMargin: Theme.files.padding - Theme.files.smallGap
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: column
            width: parent.width
            spacing: 0
            SectionTitle { text: "Lugares" }
            Repeater {
                model: root.placeList
                delegate: SidebarRow {
                    required property var modelData
                    Layout.fillWidth: true
                    icon: modelData.repo ? Icons.fileCode : (root.placeIcons[modelData.kind] ?? Icons.folderOutline)
                    label: modelData.label
                    badge: modelData.badge ? String(modelData.badge) : ""
                    active: root.currentPath === modelData.path
                    dropEnabled: true
                    onClicked: root.navigate(modelData.path)
                    onDropped: (paths, mods) => root.dropOn(modelData.path, paths, mods)
                }
            }
            SectionTitle { text: "Dispositivos"; visible: root.deviceList.length > 0 }
            Repeater {
                model: root.deviceList
                delegate: SidebarRow {
                    id: devRow
                    required property var modelData
                    readonly property string act: root.devices?.busy?.[modelData.id] ?? ""
                    readonly property string err: root.devices?.errors?.[modelData.id] ?? ""
                    Layout.fillWidth: true
                    icon: ({ usb: Icons.usb, mtp: Icons.phone, optical: Icons.disc, luks: Icons.lock })[modelData.kind] ?? Icons.disk
                    label: F.deviceLabel(modelData)
                    usage: modelData.mounted && modelData.size && modelData.kind !== "mtp" ? F.usage(modelData) : -1
                    usageColor: usage >= Theme.files.usageHigh ? Theme.danger : usage >= Theme.files.usageWarn ? Theme.warn : Theme.cyan
                    active: modelData.mounted && !!modelData.mountpoint && (root.currentPath === modelData.mountpoint || (modelData.mountpoint !== "/" && root.currentPath.indexOf(modelData.mountpoint + "/") === 0))
                    dropEnabled: modelData.mounted
                    badge: act ? ({ mount: "montando…", unmount: "desmontando…", eject: "expulsando…", unlock: "abriendo…" })[act] : err && !modelData.locked ? "error" : ""
                    badgeColor: err && !act ? Theme.danger : Theme.textDim
                    onClicked: root.deviceAction(modelData, modelData.locked ? "unlock" : "open")
                    onDropped: (paths, mods) => root.dropOn(modelData.mountpoint, paths, mods)
                    trailing: [
                        UiText {
                            visible: !devRow.act && devRow.modelData.locked
                            text: "abrir"; mono: true; size: Theme.files.mono; color: Theme.warn
                        },
                        Glyph {
                            visible: !devRow.act && !devRow.modelData.locked && devRow.modelData.mounted && (devRow.modelData.removable || devRow.modelData.kind === "mtp")
                            icon: Icons.eject; size: Theme.files.icon
                            color: ejectHit.containsMouse ? Theme.text : Theme.textSoft
                            MouseArea { id: ejectHit; anchors.fill: parent; anchors.margins: -Theme.files.thinGap; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.deviceAction(devRow.modelData, "eject") }
                        }
                    ]
                }
            }
            SidebarRow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.files.smallGap
                icon: Icons.trash
                label: "Papelera"
                badge: root.trashPlace.badge ? String(root.trashPlace.badge) : ""
                active: root.currentPath.indexOf("trash:") === 0
                dropEnabled: true
                onClicked: root.navigate(F.TRASH)
                onDropped: (paths, mods) => root.dropOn(F.TRASH, paths, mods)
            }
        }
    }
    component SectionTitle: UiText {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.files.sidebarSection
        verticalAlignment: Text.AlignBottom
        bottomPadding: Theme.files.smallGap
        leftPadding: Theme.files.smallGap
        mono: true
        size: Theme.files.caption
        font.letterSpacing: Theme.files.captionTracking
        font.capitalization: Font.AllUppercase
        color: Theme.textDim
    }
}
