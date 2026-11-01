// Kanban of the selected project (32-taller-kanban): flow metrics, five columns with WIP, drag and keyboard moves and
// the card panel with criteria and the gates for «Hecho». Pure view: memService/gateService/agentService are injected.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Item {
    id: root
    property var memService: null
    property var gateService: null
    property var agentService: null
    property bool shown: false
    property string selectedKey: ""
    property var pending: null          // {key, col, reason: "wip"|"conflicts", text}
    property string notice: ""
    property bool creating: false
    property string newKind: "feat"
    property var dragCard: null
    property point dragPoint: Qt.point(0, 0)
    property real now: Date.now()
    signal promptRequested(var opts)
    readonly property var columns: [
        { id: "backlog", label: "Backlog", tone: Theme.lavender },
        { id: "ready", label: "Listo", tone: Theme.cyan },
        { id: "doing", label: "En curso", tone: Theme.warn },
        { id: "review", label: "Revisión", tone: Theme.lavender },
        { id: "done", label: "Hecho", tone: Theme.ok }
    ]
    readonly property var project: memService?.project ?? null
    readonly property var cards: memService?.cards ?? []
    readonly property int wip: project?.wip_limit ?? 3
    readonly property var selected: cards.find(c => c.key === selectedKey) ?? null
    readonly property var details: memService?.details?.[selectedKey] ?? null
    readonly property var gates: gateService?.gates?.[selectedKey] ?? null
    readonly property var selectedAgent: agentFor(selected)
    function inColumn(col): var { return cards.filter(c => c.col === col); }
    function agentFor(card): var {
        if (!card) return null;
        return (agentService?.agents ?? []).find(a => (card.agent_ref && (a.id === card.agent_ref || a.pane === card.agent_ref)) || a.card === card.key) ?? null;
    }
    function criteriaOf(card): var {
        const d = memService?.details?.[card.key]?.criteria;
        if (d) return { done: d.filter(c => c.done).length, total: d.length };
        return { done: card.criteria_done ?? 0, total: card.criteria_total ?? 0 };
    }
    function age(card): string {
        const s = Math.max(0, now / 1000 - ((card.col === "doing" || card.col === "review") && card.started_at ? card.started_at : card.created_at ?? now / 1000));
        return s < 3600 ? `${Math.max(1, Math.round(s / 60))} m` : s < 86400 ? `${Math.round(s / 3600)} h` : `${Math.round(s / 86400)} d`;
    }
    function decimal(value): string { return value.toFixed(1).replace(".", ","); }
    function duration(hours): string { return hours === null || hours === undefined ? "—" : hours >= 24 ? decimal(hours / 24) + " d" : decimal(hours) + " h"; }
    function evaluate(): void {
        if (!selected || !shown) return;
        gateService?.evaluate(Object.assign({}, selected, { events: details?.events ?? [] }), project);
    }
    function select(key): void { selectedKey = key; notice = ""; pending = null; memService?.loadDetails(key); }
    onSelectedKeyChanged: Qt.callLater(evaluate)
    onDetailsChanged: Qt.callLater(evaluate)
    onShownChanged: { if (shown) { now = Date.now(); if (!selected) selectedKey = inColumn("doing")[0]?.key ?? cards[0]?.key ?? ""; Qt.callLater(evaluate); } }
    onCardsChanged: if (!selected && cards.length) selectedKey = inColumn("doing")[0]?.key ?? cards[0].key
    Connections { target: root.gateService; ignoreUnknownSignals: true; function onFinished(key) { if (key === root.selectedKey) root.memService?.loadDetails(key); } }
    Timer { interval: 60000; repeat: true; running: root.shown; onTriggered: root.now = Date.now() }

    function requestMove(card, col, force): void {
        if (!card || card.col === col) return;
        notice = ""; pending = null;
        if (col === "done" && !force) {
            const g = gateService?.gates?.[card.key];
            if (card.key !== selectedKey) select(card.key);
            if (!g || g.ready) { if (g?.ready) memService?.moveCard(card.key, col, false, moved); else notice = "Comprobando las puertas de «Hecho»…"; return; }
            if (g.needsConfirm) { pending = { key: card.key, col: col, reason: "conflicts", text: "No se pudieron comprobar los conflictos con main. ¿Marcar como hecha igualmente?" }; return; }
            const missing = [];
            if (g.tests?.state !== "ok") missing.push("pruebas en verde");
            if (g.seen?.state !== "ok") missing.push(`archivos vistos (${g.seen?.seen ?? 0}/${g.seen?.total ?? 0})`);
            if (g.conflicts?.state === "fail") missing.push("sin conflictos con main");
            notice = "Para pasar a «Hecho» faltan: " + missing.join(" · ");
            return;
        }
        memService?.moveCard(card.key, col, !!force, r => {
            if (r.ok) return;
            if (r.error?.code === "wip_limit_reached") pending = { key: card.key, col: col, reason: "wip", text: `«En curso» está lleno (${inColumn("doing").length} / ${wip}). ¿Mover ${card.key} igualmente?` };
            else notice = r.error?.message ?? "No se pudo mover la tarjeta";
        });
    }
    function moved(r): void { if (!r.ok) notice = r.error?.message ?? "No se pudo mover la tarjeta"; }
    function columnAt(p): string {
        const local = board.mapFromItem(root, p.x, p.y);
        if (local.y < 0 || local.y > board.height) return "";
        const i = Math.floor(local.x / ((board.width + board.spacing) / columns.length));
        return columns[i]?.id ?? "";
    }
    Keys.onPressed: e => {
        if (creating || pending) return;
        const order = columns.map(c => c.id);
        const col = selected?.col ?? "backlog", list = inColumn(col), i = list.findIndex(c => c.key === selectedKey);
        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) {
            const next = list[Math.max(0, Math.min(list.length - 1, i + (e.key === Qt.Key_Down ? 1 : -1)))];
            if (next) select(next.key);
            e.accepted = true;
        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) {
            const step = e.key === Qt.Key_Right ? 1 : -1;
            if (e.modifiers & Qt.ShiftModifier) { const to = order[order.indexOf(col) + step]; if (to) requestMove(selected, to, false); }
            else {
                for (let c = order.indexOf(col) + step; c >= 0 && c < order.length; c += step) {
                    const target = inColumn(order[c]);
                    if (target.length) { select(target[Math.min(Math.max(i, 0), target.length - 1)].key); break; }
                }
            }
            e.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.taller.rowGap
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.taller.metricsHeight
            spacing: Theme.taller.padding
            Repeater {
                model: [
                    { value: root.duration(root.memService?.stats?.lead_time_median_h), label: "lead time · mediana", tone: Theme.cyan },
                    { value: root.duration(root.memService?.stats?.cycle_time_median_h), label: "tiempo de ciclo", tone: Theme.cyan },
                    { value: root.memService?.stats ? Math.round(root.memService.stats.rework_pct ?? 0) + " %" : "—", label: "retrabajo", tone: Theme.warn },
                    { value: root.memService?.stats ? String(root.memService.stats.throughput_7d ?? 0) : "—", label: "terminadas en 7 d", tone: Theme.ok },
                    { value: root.duration(root.memService?.stats?.approval_wait_median_h), label: "espera de aprobación", tone: Theme.lavender }
                ]
                delegate: ColumnLayout {
                    required property var modelData
                    spacing: 0
                    UiText { text: modelData.value; mono: true; size: Theme.taller.metricValue; weight: Theme.weightSemiBold; color: modelData.tone }
                    UiText { text: modelData.label; size: Theme.taller.caption; color: Theme.textDim }
                }
            }
            Item { Layout.fillWidth: true }
            UiText { text: `LÍMITE WIP = AGENTES EN PARALELO · ${root.wip}`; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking / 2 }
            TallerButton { label: "+ Tarjeta"; primary: true; enabled: !!root.project; onClicked: { root.creating = true; Qt.callLater(() => titleInput.focusInput()); } }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.taller.inset
            RowLayout {
                id: board
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.taller.inset
                Repeater {
                    model: root.columns
                    delegate: Rectangle {
                        id: column
                        required property var modelData
                        readonly property var items: root.inColumn(modelData.id)
                        readonly property bool target: !!root.dragCard && root.columnAt(root.dragPoint) === modelData.id
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        radius: Theme.taller.columnRadius
                        color: target ? Theme.taller.selected : Theme.taller.card
                        border.width: Theme.taller.buttonBorder
                        border.color: target ? Theme.taller.selectedBorder : modelData.id === "doing" ? Theme.taller.doingBorder : Theme.taller.border
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.taller.rowGap
                            spacing: Theme.taller.rowGap
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.taller.columnHeader
                                Layout.leftMargin: Theme.taller.smallGap
                                Layout.rightMargin: Theme.taller.smallGap
                                spacing: Theme.taller.rowGap
                                Rectangle { implicitWidth: Theme.taller.dot - 1; implicitHeight: width; radius: width / 2; color: modelData.tone }
                                UiText { Layout.fillWidth: true; text: modelData.label; size: Theme.taller.body; weight: Theme.weightSemiBold }
                                UiText {
                                    text: modelData.id === "doing" ? `${column.items.length} / ${root.wip}` : String(column.items.length)
                                    mono: true; size: Theme.taller.caption
                                    color: modelData.id === "doing" ? (column.items.length >= root.wip ? Theme.warn : Theme.textSoft) : Theme.textDim
                                }
                            }
                            ListView {
                                id: list
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: Theme.taller.rowGap
                                model: column.items
                                delegate: KanbanCard {
                                    required property var modelData
                                    readonly property var counts: root.criteriaOf(modelData)
                                    width: list.width
                                    card: modelData
                                    agent: root.agentFor(modelData)
                                    selected: modelData.key === root.selectedKey
                                    criteriaDone: counts.done
                                    criteriaTotal: counts.total
                                    age: root.age(modelData)
                                    dragRoot: root
                                    opacity: root.dragCard?.key === modelData.key ? Theme.taller.disabledOpacity : 1
                                    onChosen: { root.select(modelData.key); root.forceActiveFocus(); }
                                    onDragMoved: p => { root.dragCard = modelData; root.dragPoint = p; }
                                    onDragEnded: p => { const to = root.columnAt(p), c = root.dragCard; root.dragCard = null; if (to) root.requestMove(c, to, false); }
                                }
                                UiText { anchors.centerIn: parent; visible: list.count === 0; text: "Sin tarjetas"; size: Theme.taller.caption; color: Theme.textDim }
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth: Theme.taller.kanbanDetailWidth
                Layout.fillHeight: true
                radius: Theme.taller.columnRadius
                color: Theme.taller.card
                border.width: Theme.taller.buttonBorder
                border.color: Theme.taller.border
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.taller.detailPadding - Theme.taller.thinGap
                    spacing: Theme.taller.rowGap
                    visible: !!root.selected
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.taller.rowGap
                        UiText { text: root.selected?.key ?? ""; mono: true; size: Theme.taller.caption; color: Theme.textDim }
                        UiText { text: root.selected?.kind ?? ""; mono: true; size: Theme.taller.caption; color: Theme.cyan }
                        Item { Layout.fillWidth: true }
                        UiText { text: root.selected ? root.age(root.selected) : ""; mono: true; size: Theme.taller.caption; color: Theme.textDim }
                    }
                    UiText { Layout.fillWidth: true; text: root.selected?.title ?? ""; size: Theme.taller.heading; weight: Theme.weightSemiBold; wrapMode: Text.Wrap; maximumLineCount: 3 }
                    UiText { Layout.fillWidth: true; text: root.selected?.branch || "sin rama todavía"; mono: true; size: Theme.taller.caption; color: Theme.textDim }
                    UiText {
                        readonly property var c: root.selected ? root.criteriaOf(root.selected) : { done: 0, total: 0 }
                        text: `CRITERIOS · ${c.done}/${c.total}`; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking / 2
                    }
                    ListView {
                        id: criteria
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Theme.taller.thinGap
                        model: root.details?.criteria ?? []
                        delegate: RowLayout {
                            required property var modelData
                            width: criteria.width
                            spacing: Theme.taller.rowGap
                            Rectangle {
                                implicitWidth: Theme.taller.checkSize; implicitHeight: Theme.taller.checkSize
                                radius: Theme.taller.badgeRadius / 2
                                color: modelData.done ? Theme.cyan : Theme.transparent
                                border.width: Theme.taller.buttonBorder
                                border.color: activeFocus ? Theme.lavender : modelData.done ? Theme.cyan : Theme.textDim
                                activeFocusOnTab: true
                                Keys.onSpacePressed: root.memService?.toggleCriterion(root.selectedKey, modelData.id)
                                UiText { anchors.centerIn: parent; visible: !!modelData.done; text: "✓"; size: Theme.taller.caption; color: Theme.islandInk }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.memService?.toggleCriterion(root.selectedKey, modelData.id) }
                            }
                            UiText { Layout.fillWidth: true; text: modelData.text; size: Theme.taller.body; color: modelData.done ? Theme.textDim : Theme.text; font.strikeout: !!modelData.done }
                        }
                    }
                    TallerInput { id: criterionInput; Layout.fillWidth: true; placeholder: "+ criterio de aceptación"; onAccepted: { root.memService?.addCriterion(root.selectedKey, text); text = ""; } }
                    UiText { text: "PARA PASAR A «HECHO»"; mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking / 2 }
                    Repeater {
                        model: [
                            { label: "Pruebas del proyecto", gate: root.gates?.tests, value: root.gates?.tests?.label ?? "…", run: true },
                            { label: "Archivos del diff vistos", gate: root.gates?.seen, value: root.gates?.seen ? `${root.gates.seen.seen} / ${root.gates.seen.total}` + (root.gates.seen.changed ? " · cambió" : "") : "…" },
                            { label: "Sin conflictos con main", gate: root.gates?.conflicts, value: root.gates?.conflicts?.label ?? "…" }
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            readonly property string gateState: modelData.gate?.state ?? "loading"
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.taller.gateRowHeight
                            spacing: Theme.taller.rowGap
                            Rectangle {
                                implicitWidth: Theme.taller.dot - 1; implicitHeight: width; radius: width / 2
                                color: gateState === "ok" ? Theme.ok : gateState === "fail" || gateState === "error" ? Theme.danger : gateState === "running" ? Theme.cyan : Theme.warn
                            }
                            UiText { Layout.fillWidth: true; text: modelData.label; size: Theme.taller.body }
                            UiText {
                                text: modelData.value; mono: true; size: Theme.taller.caption
                                color: gateState === "ok" ? Theme.ok : gateState === "fail" || gateState === "error" ? Theme.danger : Theme.warn
                            }
                            UiText {
                                visible: !!modelData.run
                                text: root.gateService?.runs?.[root.selectedKey]?.state === "running" ? "■" : "↻"
                                size: Theme.taller.body; color: Theme.cyan
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -Theme.taller.thinGap
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.gateService?.runs?.[root.selectedKey]?.state === "running" ? root.gateService.cancel(root.selectedKey) : root.gateService?.run(root.selected, root.project)
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.taller.smallGap
                        TallerButton {
                            visible: root.selected?.col !== "review" && root.selected?.col !== "done"
                            label: "Iniciar con prompt…"
                            primary: true
                            enabled: (root.selected?.col === "backlog" || root.selected?.col === "ready") && !root.selectedAgent
                            onClicked: root.promptRequested({ mode: "start", template: "implementar-tarjeta", card: root.selectedKey })
                        }
                        TallerButton { visible: root.selected?.col === "doing"; label: "A revisión"; onClicked: root.requestMove(root.selected, "review", false) }
                        TallerButton { visible: root.selected?.col === "review"; label: "Devolver"; onClicked: root.requestMove(root.selected, "doing", false) }
                        TallerButton {
                            visible: root.selected?.col === "review"
                            label: "Hecho ✓"
                            primary: true
                            tone: Theme.ok
                            enabled: !!root.gates?.ready || !!root.gates?.needsConfirm
                            onClicked: root.requestMove(root.selected, "done", false)
                        }
                    }
                }
                UiText {
                    anchors.centerIn: parent
                    visible: !root.selected
                    width: parent.width - Theme.taller.padding * 2
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    text: root.project ? "Elige una tarjeta o crea una con «+ Tarjeta»" : "Selecciona un proyecto"
                    size: Theme.taller.body
                    color: Theme.textDim
                }
            }
        }
        UiText {
            Layout.fillWidth: true
            visible: root.notice.length > 0
            text: root.notice
            color: Theme.warn
            size: Theme.taller.body
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }
    Rectangle {
        visible: !!root.dragCard
        x: root.dragPoint.x - width / 2
        y: root.dragPoint.y - height / 2
        width: Theme.taller.kanbanDetailWidth * 0.6
        height: dragTitle.implicitHeight + Theme.taller.cardPad * 2
        radius: Theme.taller.cardRadius
        color: Theme.taller.panel
        border.width: Theme.taller.buttonBorder
        border.color: Theme.cyan
        UiText { id: dragTitle; anchors.fill: parent; anchors.margins: Theme.taller.cardPad; text: (root.dragCard?.key ?? "") + " · " + (root.dragCard?.title ?? ""); size: Theme.taller.body; wrapMode: Text.Wrap; maximumLineCount: 2 }
    }
    Rectangle {
        visible: !!root.pending
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.min(parent.width, confirmRow.implicitWidth + Theme.taller.padding * 2)
        height: Theme.taller.confirmHeight
        radius: Theme.taller.buttonRadius
        color: Theme.taller.panel
        border.width: Theme.taller.buttonBorder
        border.color: Theme.warn
        RowLayout {
            id: confirmRow
            anchors.centerIn: parent
            spacing: Theme.taller.inset
            UiText { text: root.pending?.text ?? ""; size: Theme.taller.body; color: Theme.warn }
            TallerButton { label: root.pending?.reason === "wip" ? "Mover igualmente" : "Marcar como hecha"; primary: true; tone: Theme.warn; onClicked: { const p = root.pending; root.pending = null; root.memService?.moveCard(p.key, p.col, true, root.moved); } }
            TallerButton { label: "Cancelar"; onClicked: root.pending = null }
        }
    }
    Item {
        anchors.fill: parent
        visible: root.creating
        Rectangle { anchors.fill: parent; color: Theme.taller.scrim; radius: Theme.taller.columnRadius }
        MouseArea { anchors.fill: parent; onClicked: root.creating = false }
        Rectangle {
            anchors.centerIn: parent
            width: Theme.taller.projectDialogWidth
            height: form.implicitHeight + Theme.taller.padding * 2
            radius: Theme.taller.columnRadius
            color: Theme.taller.panel
            border.width: Theme.taller.buttonBorder
            border.color: Theme.taller.selectedBorder
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: form
                anchors.fill: parent
                anchors.margins: Theme.taller.padding
                spacing: Theme.taller.rowGap
                UiText { text: "NUEVA TARJETA · " + (root.project?.name ?? ""); mono: true; size: Theme.taller.caption; color: Theme.textDim; font.letterSpacing: Theme.taller.captionTracking / 2 }
                TallerInput { id: titleInput; Layout.fillWidth: true; placeholder: "Título de la tarjeta"; onAccepted: createButton.clicked() }
                Row {
                    spacing: Theme.taller.smallGap
                    Repeater {
                        model: ["feat", "fix", "chore", "docs"]
                        delegate: TallerChip { required property string modelData; label: modelData; on: false; selected: root.newKind === modelData; onClicked: root.newKind = modelData }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }
                    TallerButton { label: "Cancelar"; onClicked: root.creating = false }
                    TallerButton {
                        id: createButton
                        label: "Crear en Backlog"; primary: true
                        enabled: titleInput.text.trim().length > 0
                        onClicked: root.memService?.addCard(titleInput.text, root.newKind, r => {
                            if (r.ok) { root.creating = false; titleInput.text = ""; root.select(r.card.key); root.forceActiveFocus(); }
                            else root.notice = r.error?.message ?? "No se pudo crear la tarjeta";
                        })
                    }
                }
            }
        }
    }
}
