// Extraction dialog (33-archivos-extraer.png): destination, own folder, trash afterwards, conflict policy, the
// safety box, progress and the formats it reads. Shows what the tool reports; the checks themselves (paths, links,
// setuid, space, bombs) happen in `dragon-files archive extract`, never here.
// open(path, dest?, state?) — state: "" | password_required | bad_password | bomb_suspected (an error that came back)
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "files.js" as F

Item {
    id: root
    property var archives: null
    property var ops: null
    property string home: ""
    property real free: -1
    property string path: ""
    property bool ownFolder: true
    property bool trashAfter: false
    property string conflict: "ask"
    property string need: ""              // password_required | bad_password | bomb_suspected | ""
    property string error: ""
    property int opId: -1
    property string _defaultDest: ""
    readonly property var info: archives?.cache?.[path] ?? null
    readonly property var test: archives?.tests?.[path] ?? null
    readonly property var op: opId >= 0 ? (ops?.queue ?? []).find(o => o.id === opId) ?? null : null
    readonly property bool running: !!op && (op.state === "running" || op.state === "queued" || op.state === "conflict")
    readonly property bool tooBig: (info?.total_size ?? 0) > 0 && free >= 0 && info.total_size > free
    signal closed()
    visible: false
    anchors.fill: parent

    function open(p, dest, state): void {
        path = p; need = state ?? ""; error = ""; opId = -1; conflict = "ask"; trashAfter = false; ownFolder = true;
        password.text = "";
        _defaultDest = dest || F.extractDest(p, true);
        destInput.text = F.displayPath(_defaultDest, home) + (_defaultDest.endsWith("/") ? "/" : "");
        visible = true;
        archives?.info(p);
        Qt.callLater(() => { if (need === "password_required" || need === "bad_password") password.focusInput(); else box.forceActiveFocus(); });
    }
    function close(): void { if (running) ops?.cancel(opId); visible = false; closed(); }
    function start(): void {
        if (running) return;
        if ((need === "password_required" || need === "bad_password" || info?.encrypted) && !password.text) { need = need || "password_required"; password.focusInput(); return; }
        let dest = F.expandPath(destInput.text, home, F.parent(path)).replace(/\/$/, "");
        let own = false;
        // the untouched default with «carpeta propia»: let the tool create the folder (it avoids nesting a lone top folder)
        if (ownFolder && dest === _defaultDest.replace(/\/$/, "")) { dest = F.parent(dest); own = true; }
        error = "";
        opId = archives.extract(path, dest, { ownFolder: own, conflict: conflict, password: password.text, confirmBomb: need === "bomb_suspected", trashAfter: trashAfter }, r => {
            if (r.ok) { root.visible = false; root.closed(); return; }
            const code = r.error?.code ?? "";
            if (code === "cancelled") return;
            root.need = ["password_required", "bad_password", "bomb_suspected"].indexOf(code) >= 0 ? code : "";
            root.error = r.error?.message ?? "No se pudo extraer";
            if (root.need === "bad_password") { password.text = ""; password.focusInput(); }
        });
    }
    onOwnFolderChanged: {
        if (!visible) return;
        const base = F.parent(path);
        _defaultDest = ownFolder ? F.extractDest(path, true) : base + "/";
        destInput.text = F.displayPath(_defaultDest, home) + (_defaultDest.endsWith("/") ? "/" : "");
    }

    Rectangle { anchors.fill: parent; radius: Theme.files.radius; color: Theme.files.scrim; MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons } }
    Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(Theme.files.dialogWidth, parent.width - Theme.files.padding * 2)
        height: Math.min(layout.implicitHeight + Theme.files.padding * 2 + Theme.files.thinGap, parent.height - Theme.files.padding * 2)
        radius: Theme.files.radius - Theme.files.smallGap
        color: Theme.files.dialog
        border.width: Theme.files.border
        border.color: Theme.files.buttonBorder
        Keys.onEscapePressed: root.close()
        Keys.onReturnPressed: root.start()
        Keys.onEnterPressed: root.start()
        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Theme.files.padding + Theme.files.thinGap
            spacing: Theme.files.inset
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                Caption { text: "Extraer archivo" }
                Rectangle { Layout.fillWidth: true; height: Theme.files.border; color: Theme.files.divider }
                Caption {
                    text: root.info && !root.info.error ? (root.info.format ?? "").toUpperCase() + " · " + root.info.count + " elementos · " + F.formatSize(root.info.total_size) + " al extraer" : ""
                }
            }
            RowLayout {
                spacing: Theme.files.inset
                Rectangle {
                    Layout.preferredWidth: Theme.files.navButton
                    Layout.preferredHeight: Theme.files.navButton
                    radius: Theme.files.chipRadius
                    color: Theme.files.button
                    FileIcon { anchors.centerIn: parent; entry: ({ name: F.basename(root.path), kind: "file" }) }
                }
                UiText { text: F.basename(root.path); size: Theme.files.title + 1; weight: Theme.weightSemiBold }
            }
            Caption { text: "Destino" }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                FilesInput { id: destInput; Layout.fillWidth: true; mono: true; onAccepted: root.start(); onEscaped: root.close() }
                FilesButton { label: "Cambiar…"; onClicked: destInput.focusInput() }
            }
            FilesCheck { label: "Crear una carpeta con el nombre del archivo"; checked: root.ownFolder; onToggled: root.ownFolder = !root.ownFolder }
            FilesCheck { label: "Mover el archivo a la papelera al terminar"; checked: root.trashAfter; onToggled: root.trashAfter = !root.trashAfter }
            Caption { text: "Si ya existe un archivo" }
            FilesSegmented {
                Layout.fillWidth: true
                value: root.conflict
                options: [{ value: "ask", label: "Preguntar" }, { value: "skip", label: "Omitir" }, { value: "overwrite", label: "Reemplazar" }, { value: "rename", label: "Renombrar" }]
                onChosen: v => root.conflict = v
            }
            FilesInput {
                id: password
                Layout.fillWidth: true
                visible: root.need === "password_required" || root.need === "bad_password" || !!root.info?.encrypted
                password: true
                mono: true
                placeholder: "Contraseña del archivo (no se guarda)"
                onAccepted: root.start()
                onEscaped: root.close()
            }
            // safety box: green when everything is fine, amber when something needs a decision
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: checks.implicitHeight + Theme.files.inset * 2
                radius: Theme.files.rowRadius
                readonly property color tone: root.error || root.tooBig || root.need === "bomb_suspected" ? Theme.warn : Theme.ok
                color: Theme.alpha(tone, Theme.files.badgeTint / 2)
                border.width: Theme.files.border
                border.color: Theme.alpha(tone, Theme.files.selectedBorder.a)
                Column {
                    id: checks
                    x: Theme.files.inset; y: Theme.files.inset
                    width: parent.width - Theme.files.inset * 2
                    spacing: Theme.files.thinGap
                    Check { ok: true; text: "Rutas seguras: se bloquea todo lo que intente salir de la carpeta de destino" }
                    Check {
                        ok: !root.tooBig && root.test !== null && !root.test?.error
                        text: (root.info?.encrypted ? "Cifrado: pide contraseña" : "Sin cifrar")
                            + " · " + (root.test === "ok" ? "integridad CRC correcta" : root.test === "running" ? "probando la integridad…" : root.test?.error ? "la prueba de integridad falló" : "integridad sin probar")
                            + (root.free >= 0 ? " · " + F.formatSize(root.free) + " libres" : "")
                    }
                    Check { visible: root.tooBig; ok: false; text: "No cabe: hacen falta " + F.formatSize(root.info?.total_size) + " y quedan " + F.formatSize(root.free) }
                    Check { visible: root.need === "bomb_suspected"; ok: false; text: "Se descomprime muchísimo más de lo que ocupa. Pulsa Extraer otra vez para confirmar." }
                    Check { visible: root.error.length > 0 && root.need !== "bomb_suspected"; ok: false; text: root.error }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.running
                spacing: Theme.files.smallGap
                RowLayout {
                    Layout.fillWidth: true
                    Caption { text: root.op?.state === "conflict" ? "Esperando respuesta · ya existe " + F.basename(root.op.conflict?.file ?? "") : "Extrayendo · " + F.formatPct(root.op?.pct ?? 0); color: Theme.cyan }
                    Item { Layout.fillWidth: true }
                    UiText { Layout.maximumWidth: box.width / 2; text: (root.op?.file ?? "") + (root.op?.bps ? "   " + F.formatRate(root.op.bps) : ""); mono: true; size: Theme.files.mono; color: Theme.textSoft; elide: Text.ElideLeft }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Theme.files.progressHeight
                    radius: height / 2
                    color: Theme.files.divider
                    Rectangle {
                        width: parent.width * Math.min(1, (root.op?.pct ?? 0) / 100)
                        height: parent.height
                        radius: parent.radius
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.lavender } GradientStop { position: 1; color: Theme.cyan } }
                    }
                }
            }
            UiText {
                Layout.fillWidth: true
                text: (root.archives?.formats ?? []).join(" · ")
                mono: true
                size: Theme.files.caption
                color: Theme.textDim
                wrapMode: Text.Wrap
                maximumLineCount: 2
                font.letterSpacing: Theme.files.captionTracking / 2
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.files.inset
                Item { Layout.fillWidth: true }
                FilesButton { label: "Cancelar"; hint: "Esc"; onClicked: root.close() }
                FilesButton { label: root.need === "bomb_suspected" ? "Extraer igualmente" : "Extraer"; hint: "↵"; primary: true; enabled: !root.running; onClicked: root.start() }
            }
        }
    }
    component Caption: UiText {
        mono: true
        size: Theme.files.caption
        color: Theme.textDim
        font.letterSpacing: Theme.files.captionTracking
        font.capitalization: Font.AllUppercase
    }
    component Check: UiText {
        property bool ok: true
        width: parent?.width ?? 0
        text: ""
        size: Theme.files.small
        color: ok ? Theme.text : Theme.warn
        wrapMode: Text.Wrap
        maximumLineCount: 2
        leftPadding: Theme.files.inset + Theme.files.thinGap
        Text { text: parent.ok ? "✓" : "!"; color: parent.ok ? Theme.ok : Theme.warn; font.pixelSize: parent.font.pixelSize; font.family: Theme.fontUi; y: 0 }
    }
}
