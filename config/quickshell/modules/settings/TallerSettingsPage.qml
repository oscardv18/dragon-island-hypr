// =============================================================================
// dragon-island — TallerSettingsPage.qml · Ajustes › Taller (PLAN-FASE-5 §7, 5c punto 10)
// Pure view with injected services (SettingsPanel passes Settings and Mem; the mock passes fakes):
//   Prompts  «Ámbar desde» / «Rojo desde» (Settings.setTokenThresholds) with the resulting scale, «Guardar historial
//            de prompts» (settings.json promptHistory, off by default: dragon-prompt keeps only tokens and a hash)
//   Proyecto the Taller's project (‹ › switches it, the same selection as the Taller), «Límite WIP» and «Comando de
//            pruebas» (dragon-mem project set) and «Contexto para agentes» (dragon-mem export → .dragon/CONTEXT.md)
// Nothing runs here: the test command is only stored; dragon-gate runs it when ▶ is pressed in a «Pruebas» gate.
// =============================================================================
import QtQuick
import "../.."
import "../../components"

Column {
    id: root
    property var settings: null
    property var mem: null
    readonly property var project: mem?.project ?? null
    readonly property var projects: mem?.projects ?? []
    property string notice: ""            // last result of a project write / export (shown under the group)
    property bool noticeError: false
    readonly property var exported: mem?.exports ?? ({})   // slug → {path, bytes, at}; Mem also exports on card changes
    spacing: Theme.spacingLg

    function kb(bytes): string { return bytes < 1024 ? `${bytes} B` : `${(bytes / 1024).toFixed(1).replace(".", ",")} KB`; }
    function tokens(n): string { return `${n.toLocaleString(Qt.locale("es_ES"), "f", 0)} tokens`; }
    function report(r, okText): void {
        noticeError = !r.ok;
        notice = r.ok ? okText : (r.error?.code === "missing_tool" ? "dragon-mem no está instalado: ejecuta ./update.sh" : (r.error?.message ?? "No se pudo guardar"));
    }
    function cycle(delta): void {
        if (projects.length < 2) return;
        const i = Math.max(0, projects.findIndex(p => p.slug === mem.selectedSlug));
        mem.selectProject(projects[(i + delta + projects.length) % projects.length].slug);
        notice = "";
    }
    function setWip(v): void {
        const slug = project.slug;
        mem.setProject(slug, { wip_limit: v }, r => report(r, `WIP de ${project?.name ?? slug}: ${v}`));
    }
    function setTestCmd(text): void {
        const slug = project.slug, clean = text.trim();
        if (clean === (project.test_cmd ?? "")) return;
        mem.setProject(slug, { test_cmd: clean }, r => report(r, clean ? "Comando de pruebas guardado" : "Sin comando: la puerta «Pruebas» queda sin comprobar"));
    }
    function exportNow(): void {
        const slug = project.slug;
        mem.exportContext(slug, r => {
            report(r, "");
        });
    }

    // ---- Prompts ----
    UiText { text: "PROMPTS"; mono: true; size: Theme.sizeCaption; color: Theme.textDim; font.letterSpacing: 2 }
    SettingsGroup {
        width: parent.width
        SettingsRow {
            title: "Ámbar desde"
            subtitle: "El contador del compositor y de Revisión avisa a partir de aquí"
            Stepper {
                value: root.settings?.tokenWarnAt ?? 1500
                step: root.settings?.tokenStep ?? 250
                from: step
                to: (root.settings?.tokenMax ?? 20000) - step
                format: v => `${v}`
                onChanged: v => root.settings.setTokenThresholds(v, Math.max(root.settings.tokenHighAt, v + step))
            }
        }
        SettingsRow {
            title: "Rojo desde"
            subtitle: "Prompt pesado: conviene quitar bloques antes de enviarlo"
            Stepper {
                value: root.settings?.tokenHighAt ?? 3000
                step: root.settings?.tokenStep ?? 250
                from: (root.settings?.tokenWarnAt ?? 1500) + step
                to: root.settings?.tokenMax ?? 20000
                format: v => `${v}`
                onChanged: v => root.settings.setTokenThresholds(root.settings.tokenWarnAt, v)
            }
        }
        // the resulting scale: green up to warnAt, amber up to highAt, red the last third
        Item {
            id: scale
            width: parent.width
            height: Theme.settingsScaleHeight + scaleLabels.implicitHeight + Theme.spacingLg * 2
            readonly property real high: root.settings?.tokenHighAt ?? 3000
            readonly property real warn: root.settings?.tokenWarnAt ?? 1500
            readonly property real span: Math.max(6000, high * 1.25)   // fixed up to 6 000, so moving a threshold moves its mark
            readonly property real inner: width - (Theme.spacingLg + 4) * 2
            Row {
                id: bar
                x: Theme.spacingLg + 4
                y: Theme.spacingLg
                spacing: 2
                Rectangle { width: scale.inner * scale.warn / scale.span - 2; height: Theme.settingsScaleHeight; radius: height / 2; color: Theme.tokenOk }
                Rectangle { width: scale.inner * (scale.high - scale.warn) / scale.span - 2; height: Theme.settingsScaleHeight; radius: height / 2; color: Theme.tokenWarn }
                Rectangle { width: scale.inner * (scale.span - scale.high) / scale.span; height: Theme.settingsScaleHeight; radius: height / 2; color: Theme.tokenHigh }
            }
            Item {
                id: scaleLabels
                x: bar.x
                y: bar.y + Theme.settingsScaleHeight + Theme.spacingXs
                width: scale.inner
                implicitHeight: zero.implicitHeight
                UiText { id: zero; text: "0"; mono: true; size: Theme.sizeCaption; color: Theme.textDim }
                UiText { x: scale.inner * scale.warn / scale.span - implicitWidth / 2; text: `${scale.warn}`; mono: true; size: Theme.sizeCaption; color: Theme.tokenWarn }
                UiText { x: scale.inner * scale.high / scale.span - implicitWidth / 2; text: `${scale.high}`; mono: true; size: Theme.sizeCaption; color: Theme.tokenHigh }
                UiText { anchors.right: parent.right; text: `${(scale.span / 1000).toLocaleString(Qt.locale("es_ES"), "f", 1).replace(",0", "")} k`; mono: true; size: Theme.sizeCaption; color: Theme.textDim }
            }
            Rectangle { anchors.bottom: parent.bottom; x: 1; width: parent.width - 2; height: 1; color: Theme.hairline }
        }
        SettingsRow {
            last: true
            title: "Guardar historial de prompts"
            subtitle: root.settings?.promptHistory ? "Se guarda el texto enviado, ya tachado, junto a sus tokens y destino"
                                                   : "Apagado: de cada envío solo quedan tokens, fecha, destino y una huella; nunca el texto"
            ToggleSwitch { checked: root.settings?.promptHistory ?? false; onToggled: root.settings.setFlag("promptHistory", !root.settings.promptHistory) }
        }
    }

    // ---- Proyecto ----
    Item {
        width: parent.width
        height: projectLabel.implicitHeight
        UiText { id: projectLabel; text: "PROYECTO"; mono: true; size: Theme.sizeCaption; color: Theme.textDim; font.letterSpacing: 2 }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSm
            visible: root.projects.length > 1
            PillButton { label: "‹"; implicitHeight: 24; implicitWidth: 28; onPressed: root.cycle(-1) }
            UiText { anchors.verticalCenter: parent.verticalCenter; width: Theme.settingsNameWidth; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: root.project?.name ?? ""; weight: Theme.weightMedium }
            PillButton { label: "›"; implicitHeight: 24; implicitWidth: 28; onPressed: root.cycle(1) }
        }
    }
    SettingsGroup {
        width: parent.width
        visible: !!root.project
        SettingsRow {
            title: "Límite WIP"
            subtitle: "Tarjetas a la vez en «En curso» (por defecto 3)"
            Stepper {
                value: root.project?.wip_limit ?? 3
                step: 1; from: 1; to: 20
                format: v => `${v}`
                onChanged: v => { if (v !== (root.project?.wip_limit ?? 3)) root.setWip(v); }
            }
        }
        SettingsRow {
            title: "Comando de pruebas"
            subtitle: "Solo corre al pulsar ▶ en «Pruebas». Enter guarda"
            InputField {
                id: testCmd
                implicitWidth: Math.min(Theme.settingsFieldWidth, root.width * 0.42)   // the title keeps room on a narrow card
                fontSize: Theme.sizeBody
                text: root.project?.test_cmd ?? ""
                placeholder: "npm test · pytest -q · cargo test"
                onAccepted: root.setTestCmd(text)
                Connections { target: root; function onProjectChanged() { testCmd.text = root.project?.test_cmd ?? ""; } }
            }
        }
        SettingsRow {
            last: true
            title: "Contexto para agentes"
            subtitle: {
                const e = root.exported[root.project?.slug ?? ""];
                return e ? `.dragon/CONTEXT.md · ${root.kb(e.bytes)} · ${Qt.formatTime(e.at, "HH:mm")}`
                         : "Resumen de menos de 4 KB en .dragon/, fuera de git";
            }
            PillButton { label: "Exportar ahora"; onPressed: root.exportNow() }
        }
    }
    UiText {
        width: parent.width
        visible: !!root.project
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        text: "dragon-gate ejecuta el comando con bash -lc en el worktree de la tarjeta y corta a los 10 minutos. CONTEXT.md lleva las convenciones, las últimas 10 decisiones y la tarjeta en curso con sus criterios."
        size: Theme.sizeCaption + 1
        color: Theme.textDim
    }
    UiText {
        width: parent.width
        visible: !root.project
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        text: (root.mem?.status ?? "") === "unavailable" || (root.mem?.status ?? "") === "error"
              ? (root.mem?.message || "dragon-mem no está disponible")
              : "Aún no hay proyectos: añádelos desde el selector de la cabecera del Taller (SUPER + T)."
        color: Theme.textDim
    }
    UiText {
        width: parent.width
        visible: root.notice.length > 0
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        text: root.notice
        size: Theme.sizeCaption + 1
        color: root.noticeError ? Theme.danger : Theme.textDim
    }
}
