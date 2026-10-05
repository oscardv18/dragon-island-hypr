// =============================================================================
// dragon-island — Clipboard.qml
// Service: clipboard history (cliphist, fed by the wl-paste watchers in autostart.lua)
// =============================================================================
/**
 * Properties:
 *   - available: bool [readonly] (cliphist installed)
 *   - entries: list<var> [readonly] (newest first: { id, text, isImage, meta })
 *       isImage entries: text = "Imagen", meta = "png · 1920x1080 · 52 KiB"
 *   - loading: bool [readonly]
 *
 * Functions:
 *   - refresh(): void
 *   - search(query: string): list<var> (case-insensitive substring, images match "imagen")
 *   - copy(entry): void          (puts it back on the clipboard with wl-copy)
 *   - remove(entry): void        (cliphist delete)
 *   - wipe(): void               (cliphist wipe)
 *   - thumbnail(entry): string   (file:// URL of a decoded image preview, "" until ready)
 *   - requestThumbnail(entry): void
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool available: false
    property bool loading: false
    property var entries: []
    property var _thumbs: ({})        // id → file:// url
    property var _thumbQueue: []

    readonly property string thumbDir: Quickshell.cachePath("clipboard")

    Process {
        id: listProc
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 3; cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0) continue;
                    const id = line.substring(0, tab);
                    const preview = line.substring(tab + 1);
                    // binary entries look like: [[ binary data 52 KiB png 1920x1080 ]]
                    const bin = /^\[\[ binary data (.+?) \]\]$/.exec(preview.trim());
                    if (bin) {
                        const f = bin[1].split(" ");      // ["52", "KiB", "png", "1920x1080"]
                        const meta = [f[2], f[3], `${f[0]} ${f[1]}`].filter(x => x).join(" · ");
                        out.push({ id: id, text: "Imagen", isImage: true, meta: meta });
                    } else {
                        out.push({ id: id, text: preview, isImage: false, meta: "" });
                    }
                }
                root.entries = out;
                root.loading = false;
            }
        }
        onExited: (code, status) => {
            root.available = code !== 3;
            root.loading = false;
        }
    }

    function refresh(): void {
        if (listProc.running) return;
        root.loading = true;
        listProc.running = true;
    }

    Component.onCompleted: refresh()

    function search(query: string): var {
        const q = (query || "").trim().toLowerCase();
        if (q.length === 0) return root.entries;
        return root.entries.filter(e => e.text.toLowerCase().includes(q) || e.meta.toLowerCase().includes(q));
    }

    // cliphist identifies an entry by the "<id>\t" prefix of its list line on stdin
    Process { id: actionProc; onExited: root.refresh() }

    function copy(entry): void {
        if (!entry) return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist decode | wl-copy', "sh", entry.id]);
    }

    function remove(entry): void {
        if (!entry) return;
        actionProc.exec(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", entry.id]);
    }

    function wipe(): void {
        actionProc.exec(["cliphist", "wipe"]);
    }

    // ---- image previews: decoded one at a time into the cache dir ----
    Process {
        id: thumbProc
        property string currentId: ""
        onExited: (code, status) => {
            if (code === 0) {
                const t = Object.assign({}, root._thumbs);
                t[thumbProc.currentId] = `file://${root.thumbDir}/${thumbProc.currentId}.img`;
                root._thumbs = t;
            }
            root._nextThumb();
        }
    }

    function thumbnail(entry): string {
        return entry ? (root._thumbs[entry.id] ?? "") : "";
    }

    function requestThumbnail(entry): void {
        if (!entry || !entry.isImage || root._thumbs[entry.id] || root._thumbQueue.indexOf(entry.id) >= 0) return;
        root._thumbQueue = root._thumbQueue.concat([entry.id]);
        if (!thumbProc.running) _nextThumb();
    }

    function _nextThumb(): void {
        if (root._thumbQueue.length === 0) return;
        const id = root._thumbQueue[0];
        root._thumbQueue = root._thumbQueue.slice(1);
        thumbProc.currentId = id;
        thumbProc.exec(["sh", "-c", 'mkdir -p "$2" && printf "%s\\t\\n" "$1" | cliphist decode > "$2/$1.img"',
                        "sh", id, root.thumbDir]);
    }
}
