// Context menu of the explorer, drawn inside the window (no extra popup surface): a list of
// {label, hint, icon, action, enabled, danger} or {separator: true}. Clicking outside or Esc closes it.
import QtQuick
import "../.."
import "../../components"

Item {
    id: root
    property var items: []
    property real menuX: 0
    property real menuY: 0
    signal picked(string action)
    visible: false
    anchors.fill: parent
    function popup(x, y, list): void { items = list; menuX = x; menuY = y; visible = true; Qt.callLater(() => box.forceActiveFocus()); }
    function close(): void { visible = false; }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.close() }
    Rectangle {
        id: box
        x: Math.min(root.menuX, root.width - width - Theme.files.thinGap)
        y: Math.min(root.menuY, root.height - height - Theme.files.thinGap)
        width: Theme.files.menuWidth
        height: column.implicitHeight + Theme.files.smallGap * 2
        radius: Theme.files.buttonRadius
        color: Theme.files.dialog
        border.width: Theme.files.border
        border.color: Theme.files.buttonBorder
        focus: root.visible
        property int hover: -1
        Keys.onEscapePressed: root.close()
        Keys.onDownPressed: hover = next(1)
        Keys.onUpPressed: hover = next(-1)
        Keys.onReturnPressed: if (hover >= 0) pick(root.items[hover])
        function next(d): int {
            let i = hover;
            for (let n = 0; n < root.items.length; n++) {
                i = (i + d + root.items.length) % root.items.length;
                const it = root.items[i];
                if (!it.separator && it.enabled !== false) return i;
            }
            return hover;
        }
        function pick(it): void { if (!it || it.separator || it.enabled === false) return; root.close(); root.picked(it.action); }
        Column {
            id: column
            x: Theme.files.smallGap
            y: Theme.files.smallGap
            width: parent.width - Theme.files.smallGap * 2
            Repeater {
                model: root.items
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: column.width
                    height: modelData.separator ? Theme.files.smallGap * 2 : Theme.files.menuRow
                    Rectangle { visible: !!modelData.separator; anchors.centerIn: parent; width: parent.width - Theme.files.inset; height: Theme.files.border; color: Theme.files.divider }
                    Rectangle {
                        visible: !modelData.separator
                        anchors.fill: parent
                        radius: Theme.files.chipRadius
                        color: (box.hover === index || itemHit.containsMouse) && modelData.enabled !== false ? Theme.files.hover : Theme.transparent
                        opacity: modelData.enabled === false ? Theme.files.disabledOpacity : 1
                        Glyph { id: glyph; icon: modelData.icon ?? ""; size: Theme.files.icon; color: modelData.danger ? Theme.danger : Theme.textSoft
                            anchors.left: parent.left; anchors.leftMargin: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter; width: Theme.files.icon }
                        UiText { text: modelData.label ?? ""; size: Theme.files.small; color: modelData.danger ? Theme.danger : Theme.text
                            anchors.left: glyph.right; anchors.leftMargin: Theme.files.inset; anchors.right: hintText.left; anchors.verticalCenter: parent.verticalCenter }
                        UiText { id: hintText; text: modelData.hint ?? ""; mono: true; size: Theme.files.caption; color: Theme.textDim
                            anchors.right: parent.right; anchors.rightMargin: Theme.files.inset; anchors.verticalCenter: parent.verticalCenter }
                        MouseArea { id: itemHit; anchors.fill: parent; hoverEnabled: true; onClicked: box.pick(modelData) }
                    }
                }
            }
        }
    }
}
