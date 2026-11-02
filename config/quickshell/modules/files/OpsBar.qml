// The operation pill of the status bar (33-archivos-lista.png): «COPIANDO A KINGSTON · 2/5 ▬▬▬ 38 % ×».
// A conflict turns it amber and clicking it asks what to do; a failure turns it red until dismissed.
import QtQuick
import "../.."
import "../../components"
import "files.js" as F

Rectangle {
    id: root
    property var ops: null
    property var devices: null
    readonly property var op: ops?.active ?? null
    readonly property var failed: ops?.lastError ?? null
    readonly property bool conflict: op?.state === "conflict"
    readonly property color tone: failed && !op ? Theme.danger : conflict ? Theme.warn : Theme.cyan
    signal conflictRequested(var op)
    visible: !!op || !!failed
    implicitHeight: Theme.files.statusHeight
    implicitWidth: row.implicitWidth + Theme.files.inset * 2
    radius: height / 2
    color: Theme.alpha(tone, Theme.files.badgeTint / 2)
    border.width: Theme.files.border
    border.color: Theme.alpha(tone, Theme.files.selectedBorder.a)
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.files.inset
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            mono: true
            size: Theme.files.mono
            color: root.tone
            font.letterSpacing: Theme.files.captionTracking / 2
            text: root.op ? (root.conflict ? "YA EXISTE · " + F.basename(root.op.conflict?.file ?? "").toUpperCase() + " · ¿QUÉ HAGO?"
                                           : F.opLabel(root.op, root.devices?.devices ?? []) + ((root.ops?.pending ?? 0) > 1 ? " · +" + (root.ops.pending - 1) : ""))
                          : "ERROR · " + (root.failed?.error?.message ?? "")
        }
        Rectangle {
            visible: !!root.op && !root.conflict
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.files.sizeColumn + Theme.files.gap * 3
            height: Theme.files.thinGap
            radius: height / 2
            color: Theme.files.divider
            Rectangle { width: parent.width * Math.min(1, (root.op?.pct ?? 0) / 100); height: parent.height; radius: parent.radius; color: Theme.cyan }
        }
        UiText { visible: !!root.op && !root.conflict; anchors.verticalCenter: parent.verticalCenter; mono: true; size: Theme.files.mono; color: Theme.text; text: F.formatPct(root.op?.pct ?? 0) }
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: "×"
            size: Theme.files.body
            color: closeHit.containsMouse ? Theme.text : Theme.textDim
            MouseArea {
                id: closeHit
                anchors.fill: parent
                anchors.margins: -Theme.files.thinGap
                hoverEnabled: true
                onClicked: { if (root.op) root.ops.cancel(root.op.id); else root.ops.dismissError(); }
            }
        }
    }
    MouseArea { anchors.fill: parent; z: -1; enabled: root.conflict; cursorShape: Qt.PointingHandCursor; onClicked: root.conflictRequested(root.op) }
}
