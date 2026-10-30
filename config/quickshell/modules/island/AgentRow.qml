// One herdr agent in the IA tab (docs/design/17-agentes.png):
//   waiting   warn card (alpha warn .08, edge .35): name · kind · branch, "Espera tu respuesta", what it shows (the
//             detection lines of `herdr agent read`), Ver terminal · Rechazar · Aprobar (only for agent kinds with a
//             known approval prompt, Herdr.canAnswer; otherwise one Responder button that focuses the pane)
//   working   cyan spinner, the task (terminal title) in cyan, observed time
//   finished  ✓ ok · Terminado · task
//   other     a dim dot
// Pure visual; `detail` = Herdr.details[pane] ({ branch, prompt }), `elapsed` already formatted.
import QtQuick
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    property var agent: null
    property var detail: null
    property string elapsed: ""
    signal clicked()

    readonly property string st: agent?.state ?? "unknown"
    readonly property bool waiting: st === "blocked"
    readonly property string task: agent?.title ?? ""

    width: parent ? parent.width : 600
    height: col.implicitHeight + Theme.spacingMd * 2
    radius: Theme.cardRadius - 6
    color: waiting ? Theme.alpha(Theme.warn, 0.08) : (mouse.containsMouse ? Theme.hoverOverlay : Theme.alpha(Theme.text, 0.035))
    border.width: 1
    border.color: waiting ? Theme.alpha(Theme.warn, 0.35) : Theme.hairline

    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }

    // state mark
    Item {
        id: mark
        x: Theme.spacingMd
        y: Theme.spacingMd + 2
        width: 18
        height: 18
        Rectangle { visible: root.waiting; anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: Theme.warn }
        Spinner { visible: root.st === "working"; anchors.centerIn: parent; size: 16 }
        Glyph { visible: root.st === "done"; anchors.centerIn: parent; icon: Icons.check; size: Theme.iconMd; color: Theme.ok }
        Rectangle { visible: !root.waiting && root.st !== "working" && root.st !== "done"; anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.agentColor(root.st) }
    }

    Column {
        id: col
        x: mark.x + mark.width + Theme.spacingSm
        y: Theme.spacingMd
        width: root.width - x - Theme.spacingMd
        spacing: 3

        // name · kind · branch ……… time
        Item {
            width: parent.width
            height: nameText.implicitHeight
            Row {
                spacing: Theme.spacingXs
                UiText { id: nameText; text: root.agent?.workspace || root.agent?.name || ""; size: Theme.sizeBodyLg; weight: Theme.weightSemiBold }
                UiText { anchors.baseline: nameText.baseline; text: `· ${root.agent?.agent ?? ""}`; mono: true; size: Theme.sizeCaption + 1; color: Theme.textDim }
                UiText { anchors.baseline: nameText.baseline; visible: (root.detail?.branch ?? "").length > 0; text: `· ${root.detail?.branch ?? ""}`; mono: true; size: Theme.sizeCaption + 1; color: Theme.textDim }
            }
            UiText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.elapsed; mono: true; size: Theme.sizeCaption + 1; color: Theme.textDim }
        }

        UiText {
            width: parent.width
            text: root.waiting ? "Espera tu respuesta" : (root.st === "working" ? (root.task || "Trabajando") : (root.st === "done" ? `Terminado${root.task ? " · " + root.task : ""}` : Theme.agentLabel(root.st)))
            color: root.waiting ? Theme.warn : (root.st === "working" ? Theme.cyan : Theme.textDim)
        }

        // what it waits for
        Rectangle {
            visible: root.waiting && (root.detail?.prompt ?? "").length > 0
            width: parent.width
            height: promptText.implicitHeight + Theme.spacingSm * 2
            radius: 8
            color: Theme.alpha(Theme.islandInk, 0.6)
            UiText {
                id: promptText
                x: Theme.spacingMd
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.spacingMd * 2
                text: root.detail?.prompt ?? ""
                mono: true
                size: Theme.sizeCaption + 1
                maximumLineCount: 4
                wrapMode: Text.WrapAnywhere
                color: Theme.textSoft
            }
        }

        // actions
        Row {
            visible: root.waiting
            anchors.right: parent.right
            spacing: Theme.spacingSm
            topPadding: 2

            PillButton { label: Herdr.canAnswer(root.agent) ? "Ver terminal" : "Responder"; primary: !Herdr.canAnswer(root.agent); onPressed: Herdr.focusAgent(root.agent) }
            PillButton { visible: Herdr.canAnswer(root.agent); label: "Rechazar"; onPressed: Herdr.reject(root.agent) }
            PillButton { visible: Herdr.canAnswer(root.agent); label: "Aprobar"; primary: true; onPressed: Herdr.approve(root.agent) }
        }
    }
}
