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
 *   Gravity clipboard ring (docs/design/12-portapapeles.png), through Codex's ~/.local/bin/dragon-clip when it is there:
 *   - kinds: var [readonly] (id → { kind, label, preview, secret }; kind "text" | "command" | "link" | "path" | "color" |
 *       "image"; `dragon-clip classify --json`, or a local guess without it; secrets come back masked in `preview`)
 *   - info(entry): var ({ kind, label, preview, secret } of that entry, never undefined)
 *   - pins: list<string> [readonly] (pinned ids, `dragon-clip pins list`) · isPinned(entry): bool · togglePin(entry): void
 *   - meta: var [readonly] (id → { app, time } once fetched; {} = nothing was noted) · requestMeta(entry): void
 *   - paste(entry, address: string, appClass: string): void (puts it on the clipboard, then sends Ctrl+V — Ctrl+Shift+V
 *       to a terminal — to that window with Hyprland's send_shortcut, once the launcher has let the keyboard go)
 *   - paused: bool [readonly] · setPaused(on: bool): void (recording mode: the wl-paste watchers run bin/dragon-clip-store,
 *       which throws the copied data away while the flag $XDG_RUNTIME_DIR/dragon-island/clipboard-paused exists)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool available: false
    property bool paused: false
    function setPaused(on: bool): void {
        if (root.paused === on) return;
        root.paused = on;
        Quickshell.execDetached(["sh", "-c", on ? 'd="${XDG_RUNTIME_DIR:-/tmp}/dragon-island"; mkdir -p "$d" && : > "$d/clipboard-paused"'
                                                : 'rm -f "${XDG_RUNTIME_DIR:-/tmp}/dragon-island/clipboard-paused"']);
    }
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
                root._classify();
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

    // ---------------------------------------------------------------- kinds, pins, meta (dragon-clip)
    readonly property string clipBin: `${Quickshell.env("HOME")}/.local/bin/dragon-clip`
    property var kinds: ({})
    property var pins: []
    property var meta: ({})
    readonly property var _labels: ({ text: "Texto", command: "Comando", link: "Enlace", path: "Ruta", color: "Color", image: "Imagen" })

    function _isSecret(t: string): bool {
        const s = (t || "").trim();
        if (/^(sk-|ghp_|gho_|ghs_|github_pat_|glpat-|xox[abpr]-|AKIA|ASIA|AIza)/.test(s)) return true;
        // long, no spaces, mixed classes, and not a path / URL
        return s.length >= 32 && !/[\s\/:]/.test(s) && /[a-z]/.test(s) && /[A-Z]/.test(s) && /[0-9]/.test(s);
    }
    // without dragon-clip: a light local guess with the same kinds and the same masking
    function _guess(e): var {
        const t = (e.text || "").trim();
        let kind = "text";
        if (e.isImage) kind = "image";
        else if (/^(#[0-9a-f]{3}|#[0-9a-f]{6}|#[0-9a-f]{8}|rgba?\([^)]*\)|hsla?\([^)]*\))$/i.test(t)) kind = "color";
        else if (/^(https?|ftp|file):\/\/\S+$/i.test(t) || /^(www\.)?[a-z0-9-]+\.[a-z]{2,}(\/\S*)?$/i.test(t)) kind = "link";
        else if (/^(~|\/)[^\s]*$/.test(t)) kind = "path";
        else if (/^(sudo |git |docker |podman |npm |pnpm |yarn |make |cargo |go |python3? |pip |cd |ls |cat |rm |cp |mv |mkdir |systemctl |journalctl |pacman |paru |yay |ssh |curl |wget |kubectl |hyprctl |qs )/.test(t)) kind = "command";
        const secret = !e.isImage && root._isSecret(t);
        return { kind: kind, label: root._labels[kind], preview: secret ? `${t.slice(0, 4)}${"•".repeat(12)}` : t.slice(0, 120), secret: secret };
    }
    function info(entry): var {
        if (!entry) return { kind: "text", label: "Texto", preview: "", secret: false };
        return root.kinds[entry.id] ?? root._guess(entry);
    }

    Process {
        id: classifyProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length === 0) return;
                try {
                    const d = JSON.parse(this.text);
                    const list = Array.isArray(d) ? d : (d.entries || d.results || []);
                    const map = {};
                    for (const r of list) {
                        if (!r || r.id === undefined || !root._labels[r.kind]) continue;
                        map[`${r.id}`] = { kind: r.kind, label: r.label || root._labels[r.kind], preview: `${r.preview ?? ""}`, secret: r.secret === true };
                    }
                    root.kinds = map;
                } catch (e) {}
            }
        }
    }
    function _classify(): void {
        // the most recent 200 entries, as one argument (dragon-clip reads them on stdin)
        const items = root.entries.slice(0, 200).map(e => ({ id: e.id, text: e.text, isImage: e.isImage }));
        classifyProc.exec(["sh", "-c", '[ -x "$1" ] || exit 3; printf "%s" "$2" | "$1" classify --json 2>/dev/null', "sh", root.clipBin, JSON.stringify(items)]);
        pinsProc.exec(["sh", "-c", '[ -x "$1" ] || exit 3; exec "$1" pins list --json 2>/dev/null', "sh", root.clipBin]);
    }

    Process {
        id: pinsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "[]");
                    const list = Array.isArray(d) ? d : (d.pins || []);
                    root.pins = list.map(x => `${typeof x === "object" && x ? x.id : x}`);
                } catch (e) {}
            }
        }
    }
    function isPinned(entry): bool { return !!entry && root.pins.indexOf(`${entry.id}`) >= 0; }
    function togglePin(entry): void {
        if (!entry) return;
        const on = root.isPinned(entry);
        root.pins = on ? root.pins.filter(p => p !== `${entry.id}`) : root.pins.concat([`${entry.id}`]);
        Quickshell.execDetached(["sh", "-c", '[ -x "$1" ] && exec "$1" pins "$2" "$3" --json >/dev/null 2>&1; exit 0',
                                 "sh", root.clipBin, on ? "remove" : "add", `${entry.id}`]);
    }

    Process {
        id: metaProc
        property string forId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let v = {};
                try { v = JSON.parse(this.text || "{}") || {}; } catch (e) { v = {}; }
                const m = Object.assign({}, root.meta);
                m[metaProc.forId] = v;
                root.meta = m;
            }
        }
    }
    function requestMeta(entry): void {
        if (!entry || root.meta[entry.id] !== undefined || metaProc.running) return;
        metaProc.forId = `${entry.id}`;
        metaProc.exec(["sh", "-c", '[ -x "$1" ] || { echo "{}"; exit 0; }; exec "$1" meta "$2" --json 2>/dev/null || echo "{}"', "sh", root.clipBin, `${entry.id}`]);
    }

    // ---------------------------------------------------------------- paste
    property string _pasteTo: ""
    property bool _pasteTerminal: false
    function paste(entry, address: string, appClass: string): void {
        if (!entry) return;
        root.copy(entry);
        root._pasteTo = address || "";
        root._pasteTerminal = Hypr.isTerminal(appClass);
        if (root._pasteTo.length > 0) pasteTimer.restart();
    }
    // after wl-copy has the data and the launcher has unmapped (the window gets its keyboard focus back)
    Timer {
        id: pasteTimer
        interval: 220
        onTriggered: Hypr.sendShortcut(root._pasteTerminal ? "CTRL SHIFT" : "CTRL", "V", root._pasteTo)
    }

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
