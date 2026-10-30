// A group of notifications of one app in the center (docs/design/13-capturas.png): the latest image or icon stacked on
// top of the others, "<App> ×N", the latest text, Abrir carpeta (captures) and Ver las N (expands the group below).
import QtQuick
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    required property var entry          // { app, items, latest }
    readonly property var latest: entry?.latest ?? null
    readonly property int count: entry?.items?.length ?? 0
    readonly property bool captures: entry?.app === "Capturas"
    readonly property bool expanded: Notifs.expandedGroups[entry?.app ?? ""] === true

    implicitHeight: row.implicitHeight + Theme.cardPad * 2
    radius: Theme.cardRadius
    color: Theme.alpha(Theme.text, 0.04)
    border.width: 1
    border.color: Theme.hairline

    Row {
        id: row
        x: Theme.cardPad
        y: Theme.cardPad
        width: parent.width - Theme.cardPad * 2
        spacing: Theme.spacingMd

        // stacked thumbnails: two sheets behind the latest
        Item {
            width: root.captures ? 104 : 40
            height: root.captures ? 64 : 40
            Rectangle { x: 6; y: -4; width: parent.width - 12; height: parent.height; radius: 8; color: Theme.alpha(Theme.text, 0.06); visible: root.count > 2 }
            Rectangle { x: 3; y: -2; width: parent.width - 6; height: parent.height; radius: 8; color: Theme.alpha(Theme.text, 0.09); visible: root.count > 1 }
            ArtImage {
                anchors.fill: parent
                radius: 8
                source: Notifs.iconFor(root.latest)
                iconSize: Theme.iconLg
            }
        }

        Column {
            width: parent.width - (root.captures ? 104 : 40) - parent.spacing - closeBtn.width - parent.spacing
            spacing: 3
            Row {
                spacing: Theme.spacingXs
                UiText { text: root.entry?.app ?? ""; weight: Theme.weightSemiBold }
                UiText { text: `×${root.count}`; mono: true; color: Theme.cyan }
            }
            UiText {
                width: parent.width
                text: root.captures ? (root.latest?.body ? `Última: ${root.latest.body.toLowerCase()}` : "") : (root.latest?.summary ?? "")
                color: Theme.textDim
                size: Theme.sizeCaption + 1
            }
            Row {
                spacing: Theme.spacingSm
                topPadding: 2
                PillButton { visible: root.captures; label: "Abrir carpeta"; implicitHeight: 26; onPressed: Capture.openFolder() }
                PillButton { label: root.expanded ? "Ocultar" : `Ver las ${root.count}`; implicitHeight: 26; onPressed: Notifs.toggleGroup(root.entry.app) }
            }
        }

        IconButton {
            id: closeBtn
            icon: Icons.close
            size: 24
            iconSize: Theme.iconSm
            radius: 12
            bgColor: Theme.transparent
            iconColor: Theme.textDim
            onClicked: Notifs.dismissApp(root.entry.app)
        }
    }
}
