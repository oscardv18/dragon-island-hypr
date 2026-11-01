// Right panel of the explorer (33-archivos-*): what is selected. Images: preview and picture data; archives: their
// content without extracting (ArchiveSection); anything else: properties. Several selected: count and total size.
// Nothing selected: the folder itself. Buttons only emit requests; the panel decides what service to call.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "files.js" as F

Rectangle {
    id: root
    property var tab: null
    property var files: null
    property var archives: null
    property real now: Date.now()
    signal action(string name, var entry)   // open | openWith | terminal | agent | extractHere | extractTo | test
    readonly property var entries: tab?.selection ?? []
    readonly property var entry: entries.length === 1 ? entries[0] : null
    readonly property bool many: entries.length > 1
    readonly property bool inTrash: (tab?.path ?? "").indexOf("trash:") === 0
    readonly property string path: entry && tab ? tab.pathOf(entry) : (tab?.path ?? "")
    readonly property string category: entry ? F.category(entry) : "dir"
    property var props: null
    property string thumbFile: ""
    property int _gen: 0
    radius: Theme.files.radius - Theme.files.inset
    color: Theme.files.card
    border.width: Theme.files.border
    border.color: Theme.files.buttonBorder

    function refresh(): void {
        const gen = ++_gen;
        props = null; thumbFile = "";
        if (!files || many || !path || F.isSpecial(path)) return;
        files.properties(path, r => { if (gen === _gen && r.ok) root.props = r; });
        if (entry && (F.isImage(entry) || F.isVideo(entry))) files.thumb(path, entry.mtime, f => { if (gen === _gen && f) root.thumbFile = f; });
    }
    onPathChanged: refresh()
    onManyChanged: refresh()
    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.files.padding - Theme.files.thinGap
        spacing: Theme.files.gap

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.files.inset
            Rectangle {
                Layout.preferredWidth: Theme.files.navButton + Theme.files.smallGap
                Layout.preferredHeight: Theme.files.navButton + Theme.files.smallGap
                radius: Theme.files.buttonRadius
                color: Theme.files.button
                border.width: Theme.files.border
                border.color: Theme.files.buttonBorder
                FileIcon { anchors.centerIn: parent; entry: root.entry ?? { kind: "dir", name: "" }; size: Theme.files.title + Theme.files.thinGap }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                UiText { Layout.fillWidth: true; size: Theme.files.title; weight: Theme.weightSemiBold
                    text: root.many ? root.entries.length + " elementos" : root.entry ? root.entry.name : F.basename(root.tab?.path ?? "") }
                UiText {
                    Layout.fillWidth: true
                    mono: true
                    size: Theme.files.caption
                    color: Theme.textDim
                    font.capitalization: Font.AllUppercase
                    text: root.many ? F.formatSize(root.entries.reduce((s, e) => s + (e.kind === "dir" ? 0 : e.size || 0), 0)) + " · " + root.entries.filter(e => e.kind === "dir").length + " carpetas"
                        : root.subtitle
                }
            }
        }

        // ---- scrollable body: picture, archive content, properties ----
        Flickable {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: bodyColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: bodyColumn
                width: body.width
                spacing: Theme.files.gap
                // ---- picture ----
                Rectangle {
                    width: parent.width
                    height: Math.min(width * Theme.files.previewImageRatio, Theme.files.previewImageMax)
                    visible: root.thumbFile.length > 0 && !root.many
                    radius: Theme.files.thumbRadius
                    color: Theme.files.thumb
                    clip: true
                    Image { anchors.fill: parent; source: root.thumbFile ? "file://" + root.thumbFile : ""; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize.width: Theme.files.thumbPx * 2 }
                }

                // ---- archive content (d4) ----
                Loader {
                    id: archiveLoader
                    width: parent.width
                    active: !root.many && root.category === "archive" && !!root.archives
                    visible: active
                    source: active ? "ArchiveSection.qml" : ""
                    onLoaded: { item.archives = Qt.binding(() => root.archives); item.path = Qt.binding(() => root.path); }
                }

                // ---- properties ----
                GridLayout {
                    width: parent.width
                    visible: !root.many && !archiveLoader.active
                    columns: 2
                    columnSpacing: Theme.files.gap
                    rowSpacing: Theme.files.smallGap
                    Repeater {
                        model: root.fields
                        delegate: ColumnLayout {
                            required property var modelData
                            width: parent.width
                            Layout.preferredWidth: 1
                            Layout.columnSpan: modelData.wide ? 2 : 1
                            spacing: 0
                            UiText { width: parent.width; text: modelData.label; mono: true; size: Theme.files.caption; color: Theme.textDim; font.letterSpacing: Theme.files.captionTracking / 2; font.capitalization: Font.AllUppercase }
                            UiText { width: parent.width; text: modelData.value; mono: true; size: Theme.files.mono; color: modelData.tone ?? Theme.text; elide: Text.ElideMiddle }
                        }
                    }
                }
            }
        }

        // ---- actions ----
        Flow {
            Layout.fillWidth: true
            spacing: Theme.files.inset
            visible: (!archiveLoader.active || root.many) && !root.inTrash
            FilesButton { label: "Abrir"; primary: true; visible: !!root.entry || root.many; onClicked: root.action("open", root.entry) }
            FilesButton { label: "Abrir con…"; visible: !!root.entry && root.entry.kind !== "dir"; onClicked: root.action("openWith", root.entry) }
            FilesButton { label: "Terminal aquí"; visible: !root.many; onClicked: root.action("terminal", root.entry) }
            FilesButton { label: "Enviar al agente"; enabled: root.files?.composerAvailable ?? false; onClicked: root.action("agent", root.entry) }
        }
        Flow {
            Layout.fillWidth: true
            visible: root.inTrash && root.entries.length > 0
            FilesButton { label: "Restaurar"; primary: true; onClicked: root.action("restore", root.entry) }
        }
        Loader {
            Layout.fillWidth: true
            active: archiveLoader.active && !root.inTrash
            visible: active
            sourceComponent: Flow {
                spacing: Theme.files.inset
                FilesButton { label: "Extraer aquí"; primary: true; onClicked: root.action("extractHere", root.entry) }
                FilesButton { label: "Extraer en…"; onClicked: root.action("extractTo", root.entry) }
                FilesButton { label: "Probar"; onClicked: root.action("test", root.entry) }
            }
        }
    }

    readonly property string subtitle: {
        if (!entry) return "Carpeta" + (props?.dir_count !== undefined ? " · " + props.dir_count + " elementos" : "");
        if (entry.kind === "dir") return "Carpeta · " + F.formatCount(entry.count);
        const arch = category === "archive" ? archives?.cache?.[path] : null;
        if (arch && !arch.error) return (arch.format ?? "").toUpperCase() + " · " + F.formatSize(entry.size) + " · " + arch.count + " elementos";
        const img = props?.image;
        return F.typeLabel(entry) + " · " + F.formatSize(entry.size) + (img?.width ? " · " + img.width + "×" + img.height : "");
    }
    readonly property var fields: {
        const p = props ?? {}, e = entry;
        const out = [];
        const img = p.image;
        if (img) {
            if (img.camera) out.push({ label: "Cámara", value: img.camera, wide: true });
            if (img.width) out.push({ label: "Dimensiones", value: img.width + " × " + img.height });
            if (img.taken) out.push({ label: "Tomada", value: F.fullDate(img.taken) });
            if (img.exposure) out.push({ label: "Exposición", value: img.exposure, wide: true });
            if (img.lens) out.push({ label: "Objetivo", value: img.lens });
        }
        if (e && e.kind !== "dir") out.push({ label: "Tamaño", value: F.formatSize(p.size ?? e.size) });
        else if (p.dir_size !== undefined) out.push({ label: "Tamaño", value: F.formatSize(p.dir_size) + (p.truncated ? " o más" : "") });
        if (p.dir_count !== undefined) out.push({ label: "Contiene", value: p.dir_count + (p.truncated ? "+" : "") + " elementos" });
        out.push({ label: "Modificado", value: F.fullDate(p.mtime ?? e?.mtime) });
        out.push({ label: "Permisos", value: p.perms ?? p.mode ?? e?.mode ?? "—" });
        out.push({ label: "Propietario", value: p.owner ?? e?.owner ?? "—" });
        if (e?.git) out.push({ label: "Git", value: ({ M: "modificado", A: "añadido", D: "borrado", "?": "sin seguimiento" })[e.git] ?? e.git,
                               tone: ({ M: Theme.files.gitModified, A: Theme.files.gitAdded, D: Theme.files.gitDeleted })[e.git] });
        if (e?.link_target) out.push({ label: "Enlace a", value: e.link_target, wide: true, tone: e.broken ? Theme.danger : undefined });
        if (p.mime ?? e?.mime) out.push({ label: "MIME", value: p.mime ?? e.mime, wide: true });
        return out;
    }
}
