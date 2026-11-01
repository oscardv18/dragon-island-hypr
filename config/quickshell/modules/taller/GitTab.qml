// Pure Git workspace. Only user-edited messages are passed to the injected service.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
Item {
    id: root
    property var service: null
    readonly property var snapshot: service?.snapshot ?? ({})
    readonly property var rows: {
        const staged = snapshot.staged ?? [], changes = (snapshot.changes ?? []).concat(snapshot.untracked ?? []);
        const result = [{group:true,label:"PREPARADOS",count:staged.length}];
        for (const f of staged) result.push({group:false,file:f,prepared:true});
        result.push({group:true,label:"CAMBIOS",count:changes.length});
        for (const f of changes) result.push({group:false,file:f,prepared:false});
        return result;
    }
    Connections { target: root.service; ignoreUnknownSignals: true; function onCommitted() { message.text = ""; } }
    RowLayout {
        anchors.fill: parent
        spacing: Theme.taller.gap
        ColumnLayout {
            Layout.preferredWidth: root.width * Theme.taller.gitLeftFraction
            Layout.maximumWidth: root.width * Theme.taller.gitLeftFraction
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.taller.smallGap
                UiText { Layout.fillWidth: true; text: "● " + (root.snapshot.branch || "Sin rama"); mono: true; size: Theme.taller.body; color: Theme.lavender }
                UiText { text: `↑${root.snapshot.ahead ?? 0} ↓${root.snapshot.behind ?? 0}`; mono: true; size: Theme.taller.caption; color: Theme.ok }
                TallerButton { label: "Pull"; enabled: !!root.service?.repo && !root.service?.busy; onClicked: root.service?.pull() }
                TallerButton { label: "Push"; enabled: !!root.service?.repo && !root.service?.busy; onClicked: root.service?.push() }
            }
            ListView {
                id: files
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.taller.smallGap
                model: root.rows
                delegate: Loader {
                    required property var modelData
                    width: files.width
                    height: modelData.group ? Theme.taller.groupHeight : Theme.taller.inputHeight
                    sourceComponent: modelData.group ? group : fileRow
                    Component { id: group; UiText { text: `${modelData.label} · ${modelData.count}`; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking } }
                    Component {
                        id: fileRow
                        GitFileRow {
                            file: modelData.file
                            prepared: modelData.prepared
                            selected: root.service?.selectedPath === file.path && root.service?.staged === prepared
                            busy: root.service?.busy ?? false
                            onChosen: root.service?.select(file.path,prepared)
                            onStageRequested: value => root.service?.stage(file.path,value)
                        }
                    }
                }
            }
            UiText { visible: (root.snapshot.conflicts?.length ?? 0) > 0; Layout.fillWidth: true; text: "Conflictos: " + (root.snapshot.conflicts ?? []).join(", "); color: Theme.danger; size: Theme.taller.body; maximumLineCount: 3; wrapMode: Text.WrapAnywhere }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.taller.commitHeight
                color: Theme.taller.card
                radius: Theme.taller.buttonRadius
                border.width: Theme.taller.buttonBorder
                border.color: Theme.taller.border
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.taller.inset
                    spacing: Theme.taller.rowGap
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.taller.thinGap
                        Repeater {
                            model: ["feat","fix","chore","docs","refactor","test"]
                            Rectangle {
                                required property string modelData
                                Layout.fillWidth: true
                                implicitHeight: Theme.taller.logLineHeight
                                radius: Theme.taller.badgeRadius
                                color: message.text.startsWith(modelData+"(") ? Theme.cyan : Theme.taller.button
                                UiText { anchors.centerIn: parent; text: modelData; mono: true; size: Theme.taller.caption; color: message.text.startsWith(modelData+"(") ? Theme.islandInk : Theme.textSoft }
                                activeFocusOnTab: true
                                function choose(): void { message.text = modelData + "(ámbito): " + message.text.replace(/^[a-z]+\([^)]*\):\s*/,""); message.forceActiveFocus(); }
                                Keys.onReturnPressed: choose()
                                MouseArea { anchors.fill: parent; onClicked: parent.choose() }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.taller.badgeRadius
                        color: Theme.taller.output
                        TextEdit {
                            id: message
                            anchors.fill: parent
                            anchors.margins: Theme.taller.rowGap
                            color: Theme.text
                            selectionColor: Theme.cyan
                            selectedTextColor: Theme.islandInk
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.taller.mono
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            clip: true
                            selectByMouse: true
                            activeFocusOnTab: true
                        }
                        UiText { anchors.fill: message; visible: !message.text; text: "Escribe el mensaje del commit…"; size: Theme.taller.mono; color: Theme.textDim }
                    }
                    UiText { Layout.fillWidth: true; text: !root.service?.secretsChecked ? "COMPROBANDO LO PREPARADO…" : root.service.secrets.length ? `⚠ ${root.service.secrets.length} SECRETOS · RETÍRALOS DEL ÍNDICE` : "✓ SIN SECRETOS EN LO PREPARADO"; color: root.service?.secrets?.length ? Theme.danger : Theme.ok; mono: true; size: Theme.taller.caption }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        TallerButton { label: "Commit"; primary: true; enabled: !!message.text.trim() && (root.snapshot.staged?.length ?? 0) > 0 && !root.service?.busy; onClicked: root.service?.commit(message.text,false) }
                        TallerButton { label: "Commit y push"; enabled: !!message.text.trim() && (root.snapshot.staged?.length ?? 0) > 0 && !root.service?.busy; onClicked: root.service?.commit(message.text,true) }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            RowLayout {
                Layout.fillWidth: true
                UiText { Layout.fillWidth: true; text: root.service?.selectedPath || "DIFF UNIFICADO"; mono: true; size: Theme.taller.body }
                TallerButton { label: "Abrir en lazygit"; enabled: !!root.service?.repo; onClicked: root.service?.lazygit() }
            }
            DiffView { Layout.fillWidth: true; Layout.fillHeight: true; diff: root.service?.diffData ?? ({hunks:[]}) }
            UiText { Layout.fillWidth: true; visible: !!root.service?.actionError || root.service?.status === "error" || root.service?.status === "unavailable"; text: root.service?.actionError || root.service?.message || ""; color: Theme.danger; size: Theme.taller.body; wrapMode: Text.WrapAnywhere; maximumLineCount: 4 }
        }
        ColumnLayout {
            Layout.preferredWidth: root.width * Theme.taller.gitHistoryFraction
            Layout.maximumWidth: root.width * Theme.taller.gitHistoryFraction
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            UiText { text: "HISTORIAL"; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking }
            ListView {
                id: history
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.taller.rowGap
                model: root.service?.history ?? []
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    width: history.width
                    height: Theme.taller.inputHeight
                    spacing: Theme.taller.rowGap
                    Rectangle { implicitWidth: Theme.taller.dot; implicitHeight: width; radius: width/2; color: index === 0 ? Theme.cyan : Theme.lavender }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.taller.thinGap
                        UiText { Layout.fillWidth: true; text: modelData.subject; size: Theme.taller.body }
                        UiText { Layout.fillWidth: true; text: modelData.hash.slice(0,7) + " · " + modelData.author; mono: true; size: Theme.taller.caption; color: Theme.textDim }
                    }
                }
            }
            UiText { text: "RAMAS"; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking }
            ListView {
                id: branchList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight,Theme.taller.outputHeight)
                clip: true
                spacing: Theme.taller.smallGap
                model: root.service?.branches ?? []
                delegate: TallerButton {
                    required property var modelData
                    width: branchList.width
                    label: (modelData.current ? "● " : "") + modelData.name
                    primary: modelData.current
                    enabled: !root.service?.busy
                    onClicked: root.service?.checkout(modelData.name)
                }
            }
        }
    }
}
