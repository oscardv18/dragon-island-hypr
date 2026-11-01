// Pure Compose view. All effects are explicit service methods, injectable in mocks.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
Item {
    id: root
    property var service: null
    signal promptRequested(var opts)
    property bool inspecting: false
    readonly property var selected: service?.selected ?? null
    readonly property var metrics: service?.metrics?.[selected?.id ?? ""] ?? ({})
    readonly property var issues: (service?.issues ?? []).filter(i => i.container === selected?.id)
    readonly property var rows: {
        const groups = {}, result = [];
        for (const c of service?.containers ?? []) {
            const key = c.project || "Sin proyecto";
            if (!groups[key]) groups[key] = [];
            groups[key].push(c);
        }
        const failing = c => (service?.issues ?? []).some(i => i.container === c.id);
        const names = Object.keys(groups).sort((a,b) => Number(groups[b].some(failing))-Number(groups[a].some(failing)) || a.localeCompare(b));
        for (const name of names) {
            result.push({group:true,name:name,count:groups[name].length});
            for (const c of groups[name].sort((a,b) => Number(failing(b))-Number(failing(a)) || a.name.localeCompare(b.name))) result.push({group:false,container:c,failed:failing(c)});
        }
        return result;
    }
    function memory(bytes): string { return bytes === undefined ? "—" : (bytes/1048576).toFixed(0) + " MB"; }
    function samples(id, key): var { return (service?.history?.[id] ?? []).map(s => s[key] ?? 0); }
    function tone(c): color { return (service?.issues ?? []).some(i => i.container === c?.id) ? Theme.danger : c?.state === "running" ? Theme.ok : Theme.textDim; }
    RowLayout {
        anchors.fill: parent
        spacing: Theme.taller.gap
        ColumnLayout {
            Layout.preferredWidth: root.width * Theme.taller.containersFraction
            Layout.maximumWidth: root.width * Theme.taller.containersFraction
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            RowLayout {
                Layout.fillWidth: true
                UiText { Layout.fillWidth: true; text: "DOCKER · COMPOSE"; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking }
                UiText { text: `${root.service?.errorCount ?? 0} CON ERRORES`; mono: true; size: Theme.taller.caption; color: Theme.danger }
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.taller.smallGap
                model: root.rows
                delegate: Rectangle {
                    required property var modelData
                    readonly property var c: modelData.container ?? ({})
                    readonly property var metric: root.service?.metrics?.[c.id ?? ""] ?? ({})
                    width: list.width
                    height: modelData.group ? Theme.taller.groupHeight : Theme.taller.containerRowHeight
                    radius: Theme.taller.buttonRadius
                    color: modelData.group ? Theme.transparent : c.id === root.selected?.id ? Theme.taller.selected : Theme.taller.card
                    border.width: !modelData.group && c.id === root.selected?.id ? Theme.taller.buttonBorder : 0
                    border.color: Theme.taller.selectedBorder
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: modelData.group ? 0 : Theme.taller.inset
                        spacing: Theme.taller.rowGap
                        Rectangle { implicitWidth: Theme.taller.dot; implicitHeight: width; radius: width/2; color: modelData.group ? Theme.lavender : root.tone(c) }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.taller.thinGap
                            UiText { Layout.fillWidth: true; text: modelData.group ? modelData.name + "  · COMPOSE · " + modelData.count : c.service || c.name || ""; size: Theme.taller.body; weight: Theme.weightSemiBold }
                            UiText { visible: !modelData.group; Layout.fillWidth: true; text: (c.image ?? "") + " · " + ((c.ports ?? []).join(" · ") || "sin puertos"); mono: true; size: Theme.taller.caption; color: Theme.textDim }
                        }
                        TallerSparkline { visible: !modelData.group; values: root.samples(c.id,"cpu_pct"); tone: modelData.failed ? Theme.danger : Theme.ok }
                        UiText { visible: !modelData.group; Layout.preferredWidth: Theme.taller.logLevelWidth; text: metric.cpu_pct === undefined ? "—" : metric.cpu_pct.toFixed(1) + "%"; mono: true; size: Theme.taller.caption }
                        UiText { visible: !modelData.group; Layout.preferredWidth: Theme.taller.logTimeWidth; text: root.memory(metric.mem_bytes); mono: true; size: Theme.taller.caption; color: Theme.textDim }
                    }
                    MouseArea { anchors.fill: parent; enabled: !modelData.group; onClicked: { root.inspecting = false; root.service?.select(c.id); } }
                }
                UiText { anchors.centerIn: parent; width: parent.width; visible: list.count === 0; text: root.service?.message || "Docker no disponible"; wrapMode: Text.Wrap; maximumLineCount: 5; color: Theme.textDim; size: Theme.taller.body }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.taller.rowGap
            RowLayout {
                Layout.fillWidth: true
                Rectangle { implicitWidth: Theme.taller.dot; implicitHeight: width; radius: width/2; color: root.tone(root.selected) }
                UiText { Layout.fillWidth: true; text: root.selected?.service || root.selected?.name || "Selecciona un contenedor"; size: Theme.taller.heading; weight: Theme.weightSemiBold }
                UiText { text: ({running:"EN MARCHA",restarting:"REINICIANDO",exited:"DETENIDO",paused:"PAUSADO",created:"CREADO",dead:"FALLIDO"})[root.selected?.state ?? ""] || ""; mono: true; size: Theme.taller.caption; color: root.tone(root.selected) }
                Repeater {
                    model: [{label:["created","exited","dead"].includes(root.selected?.state) ? "Iniciar" : "Reiniciar",verb:["created","exited","dead"].includes(root.selected?.state) ? "start" : "restart"},{label:"Parar",verb:"stop"}]
                    TallerButton { required property var modelData; label: modelData.label; enabled: !!root.selected && !root.service?.busy; onClicked: root.service?.action(modelData.verb) }
                }
                TallerButton { label: "Shell"; enabled: root.selected?.state === "running"; onClicked: root.service?.shell() }
                TallerButton { label: root.inspecting ? "Ver logs" : "Inspeccionar"; enabled: !!root.selected; onClicked: { root.inspecting = !root.inspecting; if (root.inspecting) root.service?.inspect(); } }
            }
            Rectangle {
                visible: root.issues.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.taller.bannerHeight
                radius: Theme.taller.buttonRadius
                color: Theme.diffDel
                border.width: Theme.taller.buttonBorder
                border.color: Theme.danger
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.taller.inset
                    spacing: Theme.taller.rowGap
                    UiText { text: "⚠"; color: Theme.danger; size: Theme.taller.heading }
                    UiText { Layout.fillWidth: true; text: root.issues.map(i => i.detail).join(" · "); wrapMode: Text.Wrap; maximumLineCount: 3; size: Theme.taller.body }
                    TallerButton { label: "Preparar prompt"; enabled: !!root.service?.selected; onClicked: root.promptRequested({ template: "error-de-contenedor", blocks: ["log:" + root.service.selected.id] }) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.taller.rowGap
                Repeater {
                    model: [{label:"CPU",key:"cpu_pct",tone:Theme.cyan,value:root.metrics.cpu_pct === undefined ? "—" : root.metrics.cpu_pct.toFixed(1)+"%"},{label:"MEMORIA",key:"mem_bytes",tone:Theme.lavender,value:root.memory(root.metrics.mem_bytes)},{label:"RED ↓ ↑",key:"net_rx_bps",tone:Theme.ok,value:root.metrics.net_rx_bps === undefined ? "—" : (root.metrics.net_rx_bps/1048576).toFixed(1)+" / "+(root.metrics.net_tx_bps/1048576).toFixed(1)+" MB/s"}]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.taller.metricHeight
                        radius: Theme.taller.buttonRadius
                        color: Theme.taller.card
                        border.width: Theme.taller.buttonBorder
                        border.color: Theme.taller.border
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.taller.inset
                            spacing: Theme.taller.thinGap
                            RowLayout {
                                Layout.fillWidth: true
                                UiText { Layout.fillWidth: true; text: modelData.label; mono: true; size: Theme.taller.caption; color: Theme.textDim }
                                UiText { text: modelData.value; mono: true; size: Theme.taller.caption }
                            }
                            TallerSparkline { Layout.fillWidth: true; Layout.fillHeight: true; values: root.samples(root.selected?.id,modelData.key); tone: modelData.tone }
                        }
                    }
                }
            }
            LogView { visible: !root.inspecting; Layout.fillWidth: true; Layout.fillHeight: true; lines: root.service?.logs ?? [] }
            Rectangle {
                visible: root.inspecting
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.taller.output
                radius: Theme.taller.buttonRadius
                Flickable {
                    anchors.fill: parent
                    anchors.margins: Theme.taller.inset
                    contentWidth: width
                    contentHeight: inspectOutput.implicitHeight
                    clip: true
                    UiText { id: inspectOutput; width: parent.width; text: root.service?.inspectText || "Leyendo inspección…"; mono: true; size: Theme.taller.mono; wrapMode: Text.WrapAnywhere; maximumLineCount: 10000 }
                }
            }
            UiText { Layout.fillWidth: true; visible: !!root.service?.actionError || root.service?.status === "error" || root.service?.status === "unavailable"; text: root.service?.actionError || root.service?.message || ""; color: Theme.danger; size: Theme.taller.body; maximumLineCount: 3; wrapMode: Text.Wrap }
        }
    }
}
