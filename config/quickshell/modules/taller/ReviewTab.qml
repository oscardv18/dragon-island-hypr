// Revisión (32-taller-revision): files of the agent's worktree marked as seen by content, the diff with a comment margin,
// the comments and the review prompt counter. Pure view over the injected Review service.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Item {
    id: root
    property var service: null
    property var agentService: null
    property bool picking: false
    signal promptRequested(var opts)
    readonly property var card: service?.card ?? null
    readonly property var files: service?.files ?? []
    readonly property var agent: card ? (agentService?.agents ?? []).find(a => (card.agent_ref && (a.id === card.agent_ref || a.pane === card.agent_ref)) || a.card === card.key) ?? null : null
    function baseName(path): string { return path.split("/").pop(); }
    function shortPath(path): string { const parts = (path ?? "").split("/"); return parts.length > 1 ? "../" + parts.pop() : path; }
    RowLayout {
        anchors.fill: parent
        spacing: Theme.taller.gap
        ColumnLayout {
            Layout.preferredWidth: root.width * Theme.taller.reviewLeftFraction
            Layout.maximumWidth: root.width * Theme.taller.reviewLeftFraction
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.taller.inset
                Rectangle {
                    implicitWidth: Theme.taller.badge; implicitHeight: Theme.taller.badge
                    radius: Theme.taller.badgeRadius
                    color: Theme.taller.button
                    border.width: Theme.taller.buttonBorder
                    border.color: root.agent ? Theme.agentColor(root.agent.state) : Theme.taller.border
                    UiText { anchors.centerIn: parent; text: (root.agent?.kind ?? root.agent?.agent) === "codex" ? "X" : root.agent ? "C" : "·"; mono: true; size: Theme.taller.body; color: root.agent ? Theme.agentColor(root.agent.state) : Theme.textDim }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    UiText { Layout.fillWidth: true; text: root.card?.branch || root.card?.title || "Sin tarjeta"; mono: true; size: Theme.taller.body; weight: Theme.weightSemiBold }
                    UiText { Layout.fillWidth: true; text: root.card ? `${root.card.key} · worktree ${root.shortPath(root.service?.repo)}` : "Elige una tarjeta con worktree"; mono: true; size: Theme.taller.caption; color: Theme.textDim }
                }
                TallerButton { label: "⌄"; enabled: (root.service?.candidates ?? []).length > 0; onClicked: root.picking = !root.picking }
            }
            ListView {
                id: picker
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, Theme.taller.projectListHeight)
                visible: root.picking
                clip: true
                spacing: Theme.taller.thinGap
                model: root.service?.candidates ?? []
                delegate: TallerButton {
                    required property var modelData
                    width: picker.width
                    label: `${modelData.key} · ${modelData.title}`
                    primary: modelData.key === root.service?.cardKey
                    onClicked: { root.service?.setCard(modelData.key); root.picking = false; }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.taller.rowGap
                Rectangle {
                    implicitWidth: Theme.taller.switchWidth; implicitHeight: Theme.taller.switchHeight
                    radius: height / 2
                    color: root.service?.live ? Theme.taller.chipOn : Theme.taller.button
                    border.width: Theme.taller.buttonBorder
                    border.color: activeFocus ? Theme.lavender : root.service?.live ? Theme.cyan : Theme.taller.border
                    activeFocusOnTab: true
                    Keys.onSpacePressed: root.service?.setLive(!root.service.live)
                    Rectangle {
                        width: parent.height - Theme.taller.thinGap * 2; height: width; radius: width / 2
                        y: Theme.taller.thinGap
                        x: root.service?.live ? parent.width - width - Theme.taller.thinGap : Theme.taller.thinGap
                        color: root.service?.live ? Theme.cyan : Theme.textDim
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.service?.setLive(!root.service.live) }
                }
                UiText { Layout.fillWidth: true; text: "Seguir en vivo"; size: Theme.taller.body; color: root.service?.live ? Theme.cyan : Theme.textDim }
                UiText { text: `${root.service?.seenCount ?? 0}/${root.files.length} VISTOS`; mono: true; size: Theme.taller.caption; color: Theme.textSoft }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Theme.taller.progressHeight
                radius: height / 2
                color: Theme.taller.segmentEmpty
                Rectangle { width: root.files.length ? parent.width * (root.service?.seenCount ?? 0) / root.files.length : 0; height: parent.height; radius: parent.radius; color: Theme.ok }
            }
            ListView {
                id: fileList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.taller.smallGap
                model: root.files
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: fileList.width
                    height: Theme.taller.fileRowHeight
                    radius: Theme.taller.buttonRadius
                    readonly property bool current: modelData.path === root.service?.selectedPath
                    color: current ? Theme.taller.selected : (hover.containsMouse ? Theme.taller.hover : Theme.taller.card)
                    border.width: Theme.taller.buttonBorder
                    border.color: current ? Theme.taller.selectedBorder : Theme.taller.border
                    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.service?.select(modelData.path) }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.taller.inset
                        anchors.rightMargin: Theme.taller.inset
                        spacing: Theme.taller.inset
                        Rectangle {
                            implicitWidth: Theme.taller.checkSize; implicitHeight: Theme.taller.checkSize
                            radius: Theme.taller.badgeRadius / 2
                            color: modelData.seen ? Theme.taller.seenCheck : Theme.transparent
                            border.width: Theme.taller.buttonBorder
                            border.color: activeFocus ? Theme.lavender : modelData.seen ? Theme.taller.seenCheck : Theme.textDim
                            activeFocusOnTab: true
                            Keys.onSpacePressed: if (!modelData.seen) root.service?.markSeen(modelData.path)
                            UiText { anchors.centerIn: parent; visible: modelData.seen; text: "✓"; size: Theme.taller.caption; color: Theme.islandInk }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!modelData.seen) root.service?.markSeen(modelData.path) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            UiText { Layout.fillWidth: true; text: modelData.path; mono: true; size: Theme.taller.mono; elide: Text.ElideMiddle }
                            Row {
                                spacing: Theme.taller.smallGap
                                UiText { text: `+${modelData.add ?? 0}`; mono: true; size: Theme.taller.caption; color: Theme.ok }
                                UiText { visible: (modelData.del ?? 0) > 0; text: `−${modelData.del}`; mono: true; size: Theme.taller.caption; color: Theme.danger }
                                UiText { visible: !!modelData.changed; text: "● CAMBIÓ DESPUÉS DE VERLO"; mono: true; size: Theme.taller.caption; color: Theme.warn }
                            }
                        }
                    }
                }
                UiText {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    visible: fileList.count === 0
                    text: root.service?.status === "ok" ? "Sin cambios en el worktree" : (root.service?.message ?? "")
                    color: root.service?.status === "error" ? Theme.danger : Theme.textDim
                    size: Theme.taller.body
                }
            }
            UiText { Layout.fillWidth: true; text: "Un archivo vuelve a «sin ver» si el agente lo cambia después."; size: Theme.taller.caption; color: Theme.textDim; wrapMode: Text.Wrap; maximumLineCount: 2 }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            RowLayout {
                Layout.fillWidth: true
                UiText { Layout.fillWidth: true; text: root.service?.selectedPath || "DIFF"; mono: true; size: Theme.taller.body; weight: Theme.weightSemiBold; elide: Text.ElideMiddle }
                UiText { text: root.service?.base ? "FRENTE A MAIN · CLIC EN EL MARGEN PARA COMENTAR" : "CLIC EN EL MARGEN PARA COMENTAR"; mono: true; size: Theme.taller.caption; color: Theme.textDim }
            }
            ReviewDiff {
                Layout.fillWidth: true
                Layout.fillHeight: true
                diff: root.service?.diffData ?? ({ hunks: [] })
                comments: (root.service?.comments ?? []).filter(c => c.path === root.service?.selectedPath)
                onCommentRequested: (line, text) => root.service?.addComment(root.service.selectedPath, line, text)
            }
            UiText { Layout.fillWidth: true; visible: (root.service?.actionError ?? "").length > 0; text: root.service?.actionError ?? ""; color: Theme.danger; size: Theme.taller.body; wrapMode: Text.Wrap; maximumLineCount: 2 }
            UiText { Layout.fillWidth: true; visible: !root.service?.base && root.files.length > 0; text: "Solo cambios sin commitear: dragon-git aún no compara con main"; color: Theme.textDim; size: Theme.taller.caption }
        }
        ColumnLayout {
            Layout.preferredWidth: root.width * Theme.taller.reviewRightFraction
            Layout.maximumWidth: root.width * Theme.taller.reviewRightFraction
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            UiText { text: `COMENTARIOS · ${(root.service?.comments ?? []).length}`; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking / 2 }
            ListView {
                id: commentList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.taller.rowGap
                model: root.service?.comments ?? []
                delegate: Rectangle {
                    required property var modelData
                    width: commentList.width
                    height: commentBody.implicitHeight + Theme.taller.inset * 2
                    radius: Theme.taller.buttonRadius
                    color: Theme.taller.card
                    border.width: Theme.taller.buttonBorder
                    border.color: Theme.taller.border
                    opacity: modelData.sent ? Theme.taller.disabledOpacity : 1
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.service?.select(modelData.path) }
                    ColumnLayout {
                        id: commentBody
                        anchors.fill: parent
                        anchors.margins: Theme.taller.inset
                        spacing: Theme.taller.thinGap
                        UiText { Layout.fillWidth: true; text: `${root.baseName(modelData.path)} · L${modelData.line}` + (modelData.sent ? " · ENVIADO" : ""); mono: true; size: Theme.taller.caption; color: Theme.textDim }
                        UiText { Layout.fillWidth: true; text: modelData.text; size: Theme.taller.body; wrapMode: Text.Wrap; maximumLineCount: 4 }
                    }
                }
                UiText { anchors.centerIn: parent; visible: commentList.count === 0; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "Pulsa en el margen de una línea para comentarla"; size: Theme.taller.caption; color: Theme.textDim; maximumLineCount: 3 }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.taller.reviewPromptHeight
                radius: Theme.taller.buttonRadius
                color: Theme.taller.card
                border.width: Theme.taller.buttonBorder
                border.color: Theme.taller.border
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.taller.inset
                    spacing: Theme.taller.smallGap
                    UiText { text: "PROMPT DE REVISIÓN"; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking / 2 }
                    RowLayout {
                        spacing: Theme.taller.rowGap
                        UiText { text: "≈"; size: Theme.taller.counterSize; color: Theme.text }
                        UiText { text: String(root.service?.reviewTokens ?? 0); mono: true; size: Theme.taller.counterSize; weight: Theme.weightSemiBold }
                        UiText { text: "tokens · " + (root.service?.reviewLevel ?? "ligero"); size: Theme.taller.caption; color: Theme.textDim }
                    }
                    TallerButton { label: "Componer y enviar"; primary: true; enabled: !!root.card; onClicked: root.promptRequested({ template: "revisar-cambios", card: root.card.key }) }
                }
            }
        }
    }
}
