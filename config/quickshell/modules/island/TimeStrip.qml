// The 6 h time strip of the isla de mando (31-isla-mando.png, proposal C), centred on now:
//   khal events          lavender blocks with their title (a click opens Fecha y hora)
//   focus blocks         cyan outline (dragon-activity kind "focus", and the session running now)
//   agents / commands    thin cyan lines (dragon-activity kinds "agent" and "command", Activity.qml)
//   now                  a cyan marker with a glow
// Hovering any piece shows its detail on the strip. The activity range is re-read every minute while it exists
// (it only exists with the island expanded).
import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root
    property string screenName: ""
    radius: Theme.hudCardRadius - 2
    color: Theme.cmdFill
    border.width: 1
    border.color: Theme.cmdEdge
    clip: true

    property real now: Date.now()
    readonly property real span: Theme.cmdStripHours * 3600000
    readonly property real from: now - span / 2
    readonly property real to: now + span / 2
    function xOf(ms: real): real { return (ms - root.from) / root.span * root.width; }
    property string detail: ""

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { root.now = Date.now(); Activity.refresh(Math.floor(root.from / 1000), Math.floor(root.to / 1000)); }
    }

    readonly property var events: { void Clock.minutes; return Clock.eventsBetween(new Date(root.from), new Date(root.to)); }
    readonly property var focusBlocks: {
        const list = Activity.items.filter(i => i.kind === "focus").map(i => ({ name: i.name, start: i.start * 1000, end: i.end > 0 ? i.end * 1000 : root.now }));
        if (Focus.active && !list.some(b => Math.abs(b.start - Focus.startedAt) < 60000))
            list.push({ name: `Enfoque ${Focus.minutes} min`, start: Focus.startedAt, end: Focus.startedAt + Focus.minutes * 60000 });
        return list;
    }
    readonly property var runs: Activity.items.filter(i => i.kind === "agent" || i.kind === "command")
        .map(i => ({ name: i.name, kind: i.kind, status: i.status, start: i.start * 1000, end: i.end > 0 ? i.end * 1000 : root.now }))

    // hour ticks + labels (bottom)
    Repeater {
        model: Theme.cmdStripHours + 1
        delegate: Item {
            required property int index
            readonly property real hourMs: { const d = new Date(root.from); d.setMinutes(0, 0, 0); return d.getTime() + (index + 1) * 3600000; }
            x: root.xOf(hourMs)
            visible: hourMs < root.to
            Rectangle { y: root.height - 14; width: 1; height: 4; color: Theme.alpha(Theme.text, 0.15) }
            HudCaption { x: -width / 2; y: root.height - 11; size: Theme.sizeCaption - 2.5; text: `${String(new Date(parent.hourMs).getHours()).padStart(2, "0")}:00` }
        }
    }

    // agents / commands: thin cyan lines in the upper half, stacked a little so they do not hide each other
    Repeater {
        model: root.runs
        delegate: Rectangle {
            required property var modelData
            required property int index
            x: Math.max(0, root.xOf(modelData.start))
            width: Math.max(2, root.xOf(modelData.end) - x)
            y: 6 + (index % 3) * 4
            height: 2
            radius: 1
            color: modelData.status === "fail" ? Theme.error : Theme.cyan
            opacity: 0.85
            MouseArea { anchors.fill: parent; anchors.margins: -3; hoverEnabled: true
                onEntered: root.detail = `${modelData.kind === "agent" ? "Agente" : "Comando"} · ${modelData.name}`; onExited: root.detail = "" }
        }
    }

    // focus blocks: cyan outline
    Repeater {
        model: root.focusBlocks
        delegate: Rectangle {
            required property var modelData
            x: Math.max(0, root.xOf(modelData.start))
            width: Math.max(4, Math.min(root.width, root.xOf(modelData.end)) - x)
            y: 9
            height: 14
            radius: 3
            color: Theme.alpha(Theme.cyan, 0.05)
            border.width: 1
            border.color: Theme.cyan
            HudCaption { anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 6); size: Theme.sizeCaption - 2.5; text: "Enfoque"; color: Theme.cyan }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.detail = modelData.name; onExited: root.detail = "" }
        }
    }

    // khal events: lavender blocks
    Repeater {
        model: root.events
        delegate: Rectangle {
            required property var modelData
            x: Math.max(0, root.xOf(modelData.startMs))
            width: Math.max(6, Math.min(root.width, root.xOf(modelData.endMs)) - x)
            y: 9
            height: 14
            radius: 3
            color: Theme.alpha(Theme.lavender, 0.35)
            border.width: 1
            border.color: Theme.alpha(Theme.lavender, 0.7)
            UiText { anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 6); size: Theme.sizeCaption - 1; text: modelData.title }
            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: root.detail = `${modelData.time} · ${modelData.title}`; onExited: root.detail = ""
                onClicked: ShellState.open("calendar", root.screenName) }
        }
    }

    // now
    Rectangle {
        x: root.width / 2 - 1
        width: 2
        height: root.height
        color: Theme.cyan
        RectangularShadow { anchors.fill: parent; blur: 6; color: Theme.haloCyan; z: -1 }
    }

    // detail on hover
    Rectangle {
        visible: root.detail.length > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 3
        width: Math.min(detailText.implicitWidth + 12, root.width / 2 - 8)
        height: 16
        radius: 4
        color: Theme.islandInk
        border.width: 1
        border.color: Theme.cmdEdge
        UiText { id: detailText; anchors.centerIn: parent; width: parent.width - 10; text: root.detail; size: Theme.sizeCaption - 1 }
    }
}
