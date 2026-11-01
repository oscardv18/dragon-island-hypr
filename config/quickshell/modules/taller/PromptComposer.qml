// Prompt composer drawer (32-taller-compositor). Pure view over the injected Prompts service: it shows the blocks, the
// preview exactly as it will be sent and the token count; text leaves only through «Enviar» / «Copiar».
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Rectangle {
    id: root
    property var service: null
    property bool adding: false
    property bool saving: false
    property bool choosing: false
    property string addType: "text"
    readonly property var result: service?.result ?? ({ tokens: 0, blocks: [] })
    readonly property int tokens: result.tokens ?? 0
    readonly property var targetItem: (service?.targets ?? []).find(t => t.id === service?.target) ?? null
    signal closeRequested()
    function toneFor(t): color { const l = service?.colorLevel(t) ?? "ok"; return l === "ok" ? Theme.tokenOk : l === "warn" ? Theme.tokenWarn : Theme.tokenHigh; }
    radius: Theme.taller.radius
    color: Theme.taller.panel
    border.width: Theme.taller.buttonBorder
    border.color: Theme.taller.selectedBorder
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.taller.padding - Theme.taller.smallGap
        spacing: Theme.taller.rowGap
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.taller.inset
            UiText { text: "COMPOSITOR DE PROMPTS"; mono: true; size: Theme.taller.caption; font.letterSpacing: Theme.taller.captionTracking; color: Theme.textSoft }
            Rectangle { Layout.fillWidth: true; implicitHeight: Theme.taller.buttonBorder; color: Theme.taller.border }
            TallerButton { label: "Cerrar  Esc"; onClicked: root.closeRequested() }
        }
        Flow {
            Layout.fillWidth: true
            spacing: Theme.taller.smallGap
            UiText { height: Theme.taller.chipHeight; text: "PLANTILLA"; mono: true; size: Theme.taller.caption; font.letterSpacing: Theme.taller.captionTracking; color: Theme.textDim }
            Repeater {
                model: root.service?.templates ?? []
                delegate: TallerChip {
                    required property var modelData
                    label: modelData.name || modelData.id
                    on: false
                    selected: (modelData.id || modelData.name) === root.service?.template
                    onClicked: root.service?.setTemplate(modelData.id || modelData.name)
                }
            }
        }
        UiText { text: "BLOQUES · CLIC PARA QUITAR O PONER"; mono: true; size: Theme.taller.caption; font.letterSpacing: Theme.taller.captionTracking; color: Theme.textDim }
        Flow {
            Layout.fillWidth: true
            spacing: Theme.taller.smallGap
            Repeater {
                model: root.result.blocks ?? []
                delegate: TallerChip {
                    required property var modelData
                    label: modelData.label + (modelData.truncated ? " ✂" : "")
                    count: String(modelData.tokens ?? 0)
                    on: modelData.enabled !== false
                    struck: modelData.enabled === false
                    onClicked: root.service?.toggleBlock(modelData.id)
                }
            }
            TallerChip { label: "+ Bloque"; on: false; onClicked: { root.adding = !root.adding; if (root.adding) Qt.callLater(() => blockInput.focusInput()); } }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.adding
            spacing: Theme.taller.smallGap
            TallerChip { label: "Texto"; on: false; selected: root.addType === "text"; onClicked: root.addType = "text" }
            TallerChip { label: "Rutas"; on: false; selected: root.addType === "paths"; onClicked: root.addType = "paths" }
            TallerInput {
                id: blockInput
                Layout.fillWidth: true
                placeholder: root.addType === "paths" ? "ruta/relativa.ts" : "Texto que se añadirá tal cual"
                onAccepted: addButton.clicked()
            }
            TallerButton {
                id: addButton
                label: "Añadir"
                enabled: blockInput.text.trim().length > 0
                onClicked: { root.service?.addBlock(root.addType + ":" + blockInput.text.trim()); blockInput.text = ""; root.adding = false; }
            }
        }
        UiText { text: "VISTA PREVIA · LO QUE SE ENVÍA"; mono: true; size: Theme.taller.caption; font.letterSpacing: Theme.taller.captionTracking; color: Theme.textDim }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.taller.buttonRadius
            color: Theme.taller.output
            border.width: Theme.taller.buttonBorder
            border.color: Theme.taller.border
            Flickable {
                id: preview
                anchors.fill: parent
                anchors.margins: Theme.taller.inset
                clip: true
                contentWidth: width
                contentHeight: segments.implicitHeight
                Column {
                    id: segments
                    width: preview.width
                    spacing: Theme.taller.rowGap
                    Repeater {
                        model: root.service?.segments ?? []
                        delegate: Item {
                            required property var modelData
                            width: segments.width
                            height: body.implicitHeight + head.implicitHeight + Theme.taller.thinGap
                            Rectangle { width: Theme.taller.segmentBar; height: parent.height; color: Theme.lavender; opacity: Theme.taller.disabledOpacity }
                            UiText { id: head; x: Theme.taller.inset; text: `${modelData.label} · ${modelData.tokens} TOK`; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.capitalization: Font.AllUppercase }
                            UiText {
                                id: body
                                x: Theme.taller.inset
                                y: head.implicitHeight + Theme.taller.thinGap
                                width: parent.width - Theme.taller.inset
                                text: modelData.text
                                mono: true
                                size: Theme.taller.mono
                                color: Theme.text
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 400
                                lineHeight: Theme.taller.lineHeight
                            }
                        }
                    }
                }
                UiText {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: (root.service?.segments ?? []).length === 0
                    text: root.service?.building ? "Componiendo…" : (root.service?.status === "ok" ? "Sin bloques activos: añade uno o elige otra plantilla" : (root.service?.message ?? ""))
                    color: root.service?.status === "ok" || root.service?.building ? Theme.textDim : Theme.danger
                    size: Theme.taller.body
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.taller.rowGap
            UiText { text: "≈"; size: Theme.taller.counterSize; color: root.toneFor(root.tokens) }
            UiText { text: root.tokens.toLocaleString(Qt.locale("es_ES"), "f", 0); mono: true; size: Theme.taller.counterSize; weight: Theme.weightSemiBold; color: root.toneFor(root.tokens) }
            UiText { text: "tokens · " + (root.service?.level ?? "ligero"); size: Theme.taller.body; color: Theme.textDim }
            Item { Layout.fillWidth: true }
            UiText { text: "✓ SECRETOS TACHADOS: " + (root.service?.redactions ?? 0); mono: true; size: Theme.taller.caption; color: (root.service?.redactions ?? 0) > 0 ? Theme.warn : Theme.ok }
        }
        Row {
            id: bar
            Layout.fillWidth: true
            spacing: Theme.taller.tokenSegmentGap
            readonly property real step: Theme.taller.tokenScaleMax / Theme.taller.tokenSegments
            Repeater {
                model: Theme.taller.tokenSegments
                delegate: Rectangle {
                    required property int index
                    width: (bar.width - bar.spacing * (Theme.taller.tokenSegments - 1)) / Theme.taller.tokenSegments
                    height: Theme.taller.tokenSegmentHeight
                    radius: height / 2
                    color: root.tokens > index * bar.step ? root.toneFor((index + 1) * bar.step - 1) : Theme.taller.segmentEmpty
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["0", "1 000", "2 000", "3 000+"]
                delegate: UiText {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: index === 0 ? Text.AlignLeft : index === 3 ? Text.AlignRight : Text.AlignHCenter
                    text: modelData; mono: true; size: Theme.taller.caption; color: Theme.textDim
                }
            }
        }
        UiText {
            Layout.fillWidth: true
            visible: (root.result.warnings ?? []).length > 0
            text: (root.result.warnings ?? []).join(" · ")
            color: Theme.warn; size: Theme.taller.caption; wrapMode: Text.Wrap; maximumLineCount: 2
        }
        ListView {
            id: targetList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Theme.taller.targetListHeight)
            visible: root.choosing
            clip: true
            spacing: Theme.taller.thinGap
            model: root.service?.targets ?? []
            delegate: TallerButton {
                required property var modelData
                width: targetList.width
                label: modelData.label
                primary: modelData.id === root.service?.target
                enabled: modelData.enabled
                onClicked: { root.service.target = modelData.id; root.choosing = false; }
            }
        }
        TallerButton {
            Layout.fillWidth: true
            label: "Enviar a:  " + (root.targetItem?.label ?? "elige un destino") + "  ▾"
            onClicked: root.choosing = !root.choosing
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.saving
            spacing: Theme.taller.smallGap
            TallerInput { id: nameInput; Layout.fillWidth: true; placeholder: "Nombre de la plantilla"; onAccepted: saveButton.clicked() }
            TallerButton { id: saveButton; label: "Guardar"; enabled: nameInput.text.trim().length > 0; onClicked: root.service?.saveTemplate(nameInput.text, r => { if (r.ok) { root.saving = false; nameInput.text = ""; } }) }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.taller.smallGap
            TallerButton {
                Layout.fillWidth: true
                primary: true
                label: root.service?.sending ? "Enviando…" : root.service?.mode === "start" ? "Enviar e iniciar" : "Enviar"
                enabled: root.tokens > 0 && !!root.targetItem?.enabled && !root.service?.sending && !root.service?.building
                onClicked: root.service?.send()
            }
            TallerButton { label: "Copiar"; enabled: root.tokens > 0 && !root.service?.sending; onClicked: root.service?.copy() }
            TallerButton { label: "Guardar plantilla"; enabled: (root.result.blocks ?? []).length > 0; onClicked: { root.saving = !root.saving; if (root.saving) Qt.callLater(() => nameInput.focusInput()); } }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: (root.service?.startWarning ?? "").length > 0
            spacing: Theme.taller.smallGap
            UiText { Layout.fillWidth: true; text: root.service?.startWarning ?? ""; color: Theme.warn; size: Theme.taller.body; wrapMode: Text.Wrap; maximumLineCount: 2 }
            TallerButton { label: "Iniciar igualmente"; primary: true; tone: Theme.warn; onClicked: root.service?.startCard(root.service.startKind, true) }
        }
        UiText {
            Layout.fillWidth: true
            visible: (root.service?.startStep ?? "").length > 0
            text: root.service?.startStep ?? ""
            color: Theme.cyan; size: Theme.taller.body
        }
        UiText {
            Layout.fillWidth: true
            visible: (root.service?.actionError ?? "").length > 0
            text: root.service?.actionError ?? ""
            color: Theme.danger; size: Theme.taller.body; wrapMode: Text.Wrap; maximumLineCount: 3
        }
    }
}
