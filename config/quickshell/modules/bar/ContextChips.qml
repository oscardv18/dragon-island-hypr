// The contextual capsules of the right island, with "+N" when there is no room for all of them.
// The slots are fixed (one delegate per kind) so each one animates in and out; what fits is decided from the
// estimated widths in BarContext and the room the island has (`available`). Privacy and recording
// (prio <= 2) are never grouped. Hovering "+N" expands it into the icons of the hidden ones.
import QtQuick
import "../.."
import "../../services"
import "../../components"

Row {
    id: root

    property real available: 0
    signal chipClicked(string key, var chip)

    spacing: Theme.barIslandGap

    readonly property real overflowEst: 34
    readonly property var fitKeys: {
        const act = BarContext.items;
        const keys = [];
        let used = 0;
        for (let i = 0; i < act.length; i++) {
            const need = act[i].est + (keys.length > 0 ? root.spacing : 0);
            const reserve = i < act.length - 1 ? root.overflowEst + root.spacing : 0;
            if (act[i].prio <= 2 || used + need + reserve <= root.available) { keys.push(act[i].key); used += need; }
            else break;
        }
        return keys;
    }
    readonly property var hiddenItems: BarContext.items.filter(i => root.fitKeys.indexOf(i.key) < 0)

    Repeater {
        model: BarContext.slots
        delegate: ContextChip {
            id: chip
            required property string modelData
            anchors.verticalCenter: parent.verticalCenter
            entry: BarContext.byKey[modelData] ?? null
            wanted: root.fitKeys.indexOf(modelData) >= 0
            onClicked: root.chipClicked(modelData, chip)
        }
    }

    // "+N": the contextual capsules that did not fit
    Rectangle {
        id: more
        readonly property bool shown: root.hiddenItems.length > 0
        readonly property bool open: moreMouse.containsMouse
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.capsuleHeight
        radius: Theme.capsuleRadius
        color: open ? Theme.surfaceHi : Theme.surface2
        clip: true
        width: shown ? moreRow.implicitWidth + Theme.capsulePadH * 2 - 4 : 0
        opacity: shown ? 1 : 0
        visible: width > 0.5
        Behavior on width { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.durPill } }
        Behavior on color { ColorAnimation { duration: Theme.durHover } }

        Row {
            id: moreRow
            anchors.centerIn: parent
            spacing: Theme.spacingXs + 2

            UiText {
                shadow: true
                anchors.verticalCenter: parent.verticalCenter
                text: `+${root.hiddenItems.length}`
                mono: true
                size: Theme.sizeBar
                color: Theme.textSoft
            }
            // expands on hover: the hidden capsules as icons
            Row {
                id: hiddenRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXs + 2
                width: more.open ? implicitWidth : 0
                opacity: more.open ? 1 : 0
                clip: true
                visible: width > 0.5
                Behavior on width { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.durPill } }
                Repeater {
                    model: root.hiddenItems
                    delegate: Glyph {
                        required property var modelData
                        icon: modelData.icon
                        size: Theme.iconSm + 1
                        color: modelData.color
                    }
                }
            }
        }

        MouseArea {
            id: moreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { const it = root.hiddenItems[0]; if (it) root.chipClicked(it.key, more); }
        }
    }
}
