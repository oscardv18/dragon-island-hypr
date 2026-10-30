// Tooltip under a bar item (a popup, so the island never widens: HANDOFF §7t). Shown after a short delay while
// `shown` is true; `text` may change while it is open.
import QtQuick
import Quickshell
import ".."

PopupWindow {
    id: root

    required property Item target
    property bool shown: false
    property string text: ""
    property int delay: 350

    visible: false
    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.bottom: Theme.popoverGap
    implicitWidth: tipText.implicitWidth + 22
    implicitHeight: 26
    color: Theme.transparent

    onShownChanged: shown ? delayTimer.restart() : (delayTimer.stop(), root.visible = false)
    Timer { id: delayTimer; interval: root.delay; onTriggered: root.visible = root.shown && root.text.length > 0 }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(Theme.islandInk, 0.92)
        border.width: 1
        border.color: Theme.glassBorder
        UiText { id: tipText; anchors.centerIn: parent; text: root.text; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft }
    }
}
