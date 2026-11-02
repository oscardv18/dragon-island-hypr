// Pure helpers of the file explorer: formatting, sorting, paths and archive trees. No QML types, no I/O.
// tests/qml/files_mock.qml checks them with fixed inputs (it fails the render if one changes behaviour).
.pragma library

const UNITS = ["B", "KB", "MB", "GB", "TB", "PB"];

// 1024-based, Spanish decimal comma: 512 B · 18 KB · 3,4 MB · 48,2 MB · 86 MB · 312 MB · 931 GB
// (one decimal below 100 unless it is ,0)
function formatSize(bytes) {
    if (bytes === null || bytes === undefined || isNaN(bytes) || bytes < 0) return "—";
    let v = Number(bytes), i = 0;
    while (v >= 1024 && i < UNITS.length - 1) { v /= 1024; i++; }
    if (i <= 1) return Math.round(v) + " " + UNITS[i];
    const s = v < 100 ? (Math.round(v * 10) / 10).toFixed(1).replace(/\.0$/, "") : String(Math.round(v));
    return s.replace(".", ",") + " " + UNITS[i];
}

function formatCount(n) {
    if (n === null || n === undefined || isNaN(n)) return "—";
    return n + (n === 1 ? " elem." : " elem.");
}

function formatPct(p) {
    return Math.max(0, Math.min(100, Math.round(Number(p) || 0))) + " %";
}

function formatRate(bps) {
    if (!bps) return "";
    return formatSize(bps).replace(" ", " ") + "/S";
}

function pad2(n) { return n < 10 ? "0" + n : String(n); }

const MONTHS = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

// mtime in seconds; now in milliseconds (injected so the mock is deterministic)
function relTime(mtime, now) {
    if (!mtime) return "—";
    const d = new Date(mtime * 1000), n = new Date(now);
    const startToday = new Date(n.getFullYear(), n.getMonth(), n.getDate()).getTime();
    const t = d.getTime();
    if (t >= startToday) return "hoy " + pad2(d.getHours()) + ":" + pad2(d.getMinutes());
    if (t >= startToday - 86400000) return "ayer";
    const days = Math.floor((startToday - t) / 86400000) + 1;
    if (days < 7) return "hace " + days + " d";
    if (days < 56) return "hace " + Math.floor(days / 7) + " sem";
    if (d.getFullYear() === n.getFullYear()) return d.getDate() + " " + MONTHS[d.getMonth()];
    return d.getDate() + " " + MONTHS[d.getMonth()] + " " + d.getFullYear();
}

function fullDate(mtime) {
    if (!mtime) return "—";
    const d = new Date(mtime * 1000);
    return d.getDate() + " " + MONTHS[d.getMonth()] + " " + d.getFullYear() + " " + pad2(d.getHours()) + ":" + pad2(d.getMinutes());
}

// ---- types ----
// Compound extensions first: the archive stem must drop the whole suffix (release-2.4.tar.gz → release-2.4)
const ARCHIVE_EXT = [".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2", ".tar.lz", ".tgz", ".txz", ".tbz2", ".tzst",
                     ".zip", ".7z", ".rar", ".tar", ".gz", ".xz", ".zst", ".bz2", ".iso", ".deb", ".rpm", ".cab",
                     ".appimage", ".lha", ".lzh", ".jar", ".apk"];
const TYPES = {
    ".tar.gz": "tar + gzip", ".tgz": "tar + gzip", ".tar.xz": "tar + xz", ".txz": "tar + xz",
    ".tar.zst": "tar + zstd", ".tzst": "tar + zstd", ".tar.bz2": "tar + bzip2", ".tbz2": "tar + bzip2",
    ".zip": "Archivo ZIP", ".7z": "Archivo 7z", ".rar": "Archivo RAR", ".tar": "Archivo tar", ".iso": "Imagen ISO",
    ".deb": "Paquete deb", ".rpm": "Paquete rpm", ".cab": "Archivo CAB", ".appimage": "AppImage",
    ".md": "Markdown", ".txt": "Texto", ".pdf": "PDF", ".sql": "SQL", ".json": "JSON", ".yaml": "YAML", ".yml": "YAML",
    ".toml": "TOML", ".csv": "CSV", ".html": "HTML", ".css": "CSS", ".js": "JavaScript", ".ts": "TypeScript",
    ".tsx": "TypeScript", ".py": "Python", ".sh": "Shell", ".lua": "Lua", ".qml": "QML", ".rs": "Rust", ".go": "Go",
    ".c": "C", ".h": "C", ".cpp": "C++", ".java": "Java", ".svg": "Imagen SVG", ".png": "Imagen PNG",
    ".jpg": "Imagen JPEG", ".jpeg": "Imagen JPEG", ".webp": "Imagen WebP", ".gif": "Imagen GIF", ".avif": "Imagen AVIF",
    ".mp4": "Vídeo MP4", ".mkv": "Vídeo MKV", ".webm": "Vídeo WebM", ".mov": "Vídeo MOV",
    ".mp3": "Audio MP3", ".flac": "Audio FLAC", ".ogg": "Audio OGG", ".wav": "Audio WAV",
    ".odt": "Documento", ".docx": "Documento", ".ods": "Hoja de cálculo", ".xlsx": "Hoja de cálculo"
};
const CODE = [".sql", ".json", ".yaml", ".yml", ".toml", ".html", ".css", ".js", ".ts", ".tsx", ".py", ".sh", ".lua",
              ".qml", ".rs", ".go", ".c", ".h", ".cpp", ".java"];

function extOf(name) {
    const n = String(name || "").toLowerCase();
    for (const e of ARCHIVE_EXT) if (e.indexOf(".tar") === 0 && n.endsWith(e)) return e;
    const i = n.lastIndexOf(".");
    return i > 0 ? n.slice(i) : "";
}

function isArchive(entry) {
    if (!entry || entry.kind === "dir") return false;
    const n = String(entry.name || "").toLowerCase();
    if (ARCHIVE_EXT.some(e => n.endsWith(e))) return true;
    const m = entry.mime || "";
    return /zip|x-7z|x-rar|x-tar|compressed|x-xz|zstd|x-bzip|x-iso9660|x-cd-image|debian-package|x-rpm/.test(m);
}

function isImage(entry) {
    if (!entry || entry.kind === "dir") return false;
    return (entry.mime || "").indexOf("image/") === 0 || [".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".avif"].indexOf(extOf(entry.name)) >= 0;
}

function isVideo(entry) {
    return !!entry && entry.kind !== "dir" && ((entry.mime || "").indexOf("video/") === 0 || [".mp4", ".mkv", ".webm", ".mov"].indexOf(extOf(entry.name)) >= 0);
}

// dir · archive · image · video · code · doc · link · other
function category(entry) {
    if (!entry) return "other";
    if (entry.kind === "dir") return "dir";
    if (isArchive(entry)) return "archive";
    if (isImage(entry)) return "image";
    if (isVideo(entry)) return "video";
    if (CODE.indexOf(extOf(entry.name)) >= 0) return "code";
    if (entry.kind === "link" && !entry.mime) return "link";
    return "doc";
}

function typeLabel(entry) {
    if (!entry) return "";
    if (entry.kind === "dir") return "Carpeta";
    if (entry.kind === "link" && entry.broken) return "Enlace roto";
    const t = TYPES[extOf(entry.name)];
    if (t) return t;
    const m = entry.mime || "";
    if (m.indexOf("text/") === 0) return "Texto";
    if (m.indexOf("image/") === 0) return "Imagen";
    if (m.indexOf("video/") === 0) return "Vídeo";
    if (m.indexOf("audio/") === 0) return "Audio";
    const e = extOf(entry.name);
    return e ? e.slice(1).toUpperCase() : "Archivo";
}

// ---- sort / filter ----
// Natural, case- and accent-insensitive order (a9 < a10, «Árbol» next to «arbol»). The QML JS engine ignores the
// options of localeCompare, so the numeric chunks are compared by hand.
function _fold(s) { return String(s).normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase(); }
function naturalCompare(a, b) {
    const x = _fold(a).match(/\d+|\D+/g) ?? [], y = _fold(b).match(/\d+|\D+/g) ?? [];
    for (let i = 0; i < Math.min(x.length, y.length); i++) {
        const dx = /^\d/.test(x[i]), dy = /^\d/.test(y[i]);
        let c = 0;
        if (dx && dy) c = Number(x[i]) - Number(y[i]) || x[i].length - y[i].length;
        else c = x[i] < y[i] ? -1 : x[i] > y[i] ? 1 : 0;
        if (c) return c < 0 ? -1 : 1;
    }
    return x.length - y.length || (String(a) < String(b) ? -1 : String(a) > String(b) ? 1 : 0);
}
const collator = { compare: naturalCompare };

function sortEntries(entries, key, desc, dirsFirst) {
    const out = (entries || []).slice();
    const dir = desc ? -1 : 1;
    out.sort((a, b) => {
        if (dirsFirst) {
            const da = a.kind === "dir" ? 0 : 1, db = b.kind === "dir" ? 0 : 1;
            if (da !== db) return da - db;
        }
        let c = 0;
        if (key === "size") c = (a.kind === "dir" ? (a.count ?? 0) : (a.size ?? 0)) - (b.kind === "dir" ? (b.count ?? 0) : (b.size ?? 0));
        else if (key === "mtime") c = (a.mtime ?? 0) - (b.mtime ?? 0);
        else if (key === "type") c = collator.compare(typeLabel(a), typeLabel(b));
        if (c === 0) c = collator.compare(a.name, b.name);
        return c * dir;
    });
    return out;
}

function filterEntries(entries, text, showHidden) {
    const q = String(text || "").trim().toLowerCase();
    return (entries || []).filter(e => (showHidden || !e.hidden) && (!q || String(e.name).toLowerCase().indexOf(q) >= 0));
}

const SORT_LABELS = { name: "NOMBRE", size: "TAMAÑO", mtime: "MODIFICADO", type: "TIPO" };
function sortCaption(key, desc, hidden, dirsFirst) {
    return "ORDEN: " + SORT_LABELS[key] + (desc ? " ↓" : "") + " · · · OCULTOS: " + (hidden ? "SÍ" : "NO") + (dirsFirst ? " · CARPETAS PRIMERO" : "");
}

// ---- paths ----
const NET = "net:///";
const TRASH = "trash:///";

function isSpecial(path) { return path === NET || String(path).indexOf("trash:") === 0; }

function trimSlash(p) { return p.length > 1 && p.endsWith("/") ? p.slice(0, -1) : p; }

function basename(path) {
    if (path === NET) return "Red local";
    if (String(path).indexOf("trash:") === 0) return "Papelera";
    const p = trimSlash(String(path));
    return p === "/" ? "/" : p.slice(p.lastIndexOf("/") + 1);
}

function parent(path) {
    if (isSpecial(path)) return "";
    const p = trimSlash(String(path));
    if (p === "/") return "";
    const i = p.lastIndexOf("/");
    return i <= 0 ? "/" : p.slice(0, i);
}

function join(dir, name) { return (dir === "/" ? "" : trimSlash(dir)) + "/" + name; }

function displayPath(path, home) {
    if (path === NET) return "Red › Red local";
    if (String(path).indexOf("trash:") === 0) return "Papelera";
    const p = trimSlash(String(path));
    if (home && (p === home || p.indexOf(home + "/") === 0)) return "~" + p.slice(home.length);
    return p;
}

// User text from the editable breadcrumbs → absolute path (~ expands; relative paths resolve against `cwd`)
function expandPath(text, home, cwd) {
    let t = String(text || "").trim();
    if (!t) return "";
    if (t === "~") return home;
    if (t.indexOf("~/") === 0) t = home + t.slice(1);
    if (/^[a-z]+:\/\//.test(t)) return t;
    if (t[0] !== "/") t = join(cwd || home, t);
    const parts = [];
    for (const s of t.split("/")) {
        if (!s || s === ".") continue;
        if (s === "..") parts.pop(); else parts.push(s);
    }
    return "/" + parts.join("/");
}

// → [{label, path}]; "~" is the first crumb inside home
function crumbs(path, home) {
    if (path === NET) return [{ label: "Red", path: NET }, { label: "Red local", path: NET }];
    if (String(path).indexOf("trash:") === 0) return [{ label: "Papelera", path: TRASH }];
    const p = trimSlash(String(path));
    const out = [];
    let base = "", rest = p;
    if (home && (p === home || p.indexOf(home + "/") === 0)) { out.push({ label: "~", path: home }); base = home; rest = p.slice(home.length); }
    else out.push({ label: "/", path: "/" });
    for (const s of rest.split("/")) {
        if (!s) continue;
        base = base === "/" ? "/" + s : base + "/" + s;
        out.push({ label: s, path: base });
    }
    return out;
}

// ---- archives ----
function archiveStem(name) {
    const n = String(name || "");
    const l = n.toLowerCase();
    for (const e of ARCHIVE_EXT) if (l.endsWith(e) && l.length > e.length) return n.slice(0, n.length - e.length);
    return n;
}

function extractDest(archivePath, ownFolder) {
    const dir = parent(archivePath);
    return ownFolder ? join(dir, archiveStem(basename(archivePath))) + "/" : dir + "/";
}

// The partial tree of the preview: top-level folders with how many entries they hold, then top-level files with their
// size; folders first, at most `max` lines plus «+ N más…»
function archiveTree(entries, max) {
    const dirs = {}, files = [];
    for (const e of entries || []) {
        const p = String(e.path || "").replace(/^\.\//, "").replace(/\/$/, "");
        if (!p) continue;
        const i = p.indexOf("/");
        if (i < 0) { if (e.is_dir) dirs[p] = dirs[p] ?? 0; else files.push({ label: p, value: formatSize(e.size), dir: false }); }
        else { const top = p.slice(0, i); dirs[top] = (dirs[top] ?? 0) + 1; }
    }
    const lines = Object.keys(dirs).sort((a, b) => collator.compare(a, b)).map(d => ({ label: d + "/", value: String(dirs[d]), dir: true }))
        .concat(files.sort((a, b) => collator.compare(a.label, b.label)));
    const limit = max || 5;
    return { lines: lines.slice(0, limit), more: Math.max(0, lines.length - limit) };
}

// ---- devices / operations ----
function deviceForPath(devices, path) {
    let best = null;
    for (const d of devices || []) {
        const m = d.mountpoint;
        if (!d.mounted || !m) continue;
        if ((path === m || String(path).indexOf(m === "/" ? "/" : m + "/") === 0) && (!best || m.length > best.mountpoint.length)) best = d;
    }
    return best;
}

function sameDevice(devices, a, b) {
    const da = deviceForPath(devices, a), db = deviceForPath(devices, b);
    return (da?.id ?? "") === (db?.id ?? "");
}

const VERBS = { copy: "COPIANDO A", move: "MOVIENDO A", trash: "A LA PAPELERA", delete: "ELIMINANDO", extract: "EXTRAYENDO EN",
                create: "COMPRIMIENDO", rename: "RENOMBRANDO", mkdir: "CREANDO CARPETA", link: "ENLAZANDO EN", undo: "DESHACIENDO" };

function opLabel(op, devices) {
    if (!op) return "";
    const verb = VERBS[op.kind] ?? "OPERACIÓN";
    let where = "";
    if (op.dest && ["copy", "move", "extract", "link"].indexOf(op.kind) >= 0) {
        const d = deviceForPath(devices, op.dest);
        where = " " + String(d && d.mountpoint !== "/" ? d.label : basename(op.dest)).toUpperCase();
    }
    const count = op.count > 1 ? " · " + Math.min(op.index || 1, op.count) + "/" + op.count : "";
    return verb + where + count;
}

function usage(device) {
    if (!device || !device.size) return 0;
    const used = device.used ?? (device.free !== undefined ? device.size - device.free : 0);
    return Math.max(0, Math.min(1, used / device.size));
}

// Capacity as printed on the device (SI, 1000-based): 1 000 204 886 016 B → «1 TB», 32 015 679 488 B → «32 GB»
function formatCapacity(bytes) {
    if (!bytes) return "";
    let v = Number(bytes), i = 0;
    while (v >= 1000 && i < UNITS.length - 1) { v /= 1000; i++; }
    const s = v < 10 && i >= 3 ? (Math.round(v * 10) / 10).toFixed(1).replace(".0", "") : String(Math.round(v));
    return s.replace(".", ",") + " " + UNITS[i];
}

function deviceLabel(d) {
    if (!d) return "";
    if (d.kind === "mtp") return d.label + " · MTP";
    if (d.locked || !d.size) return d.label;
    return d.label + " · " + formatCapacity(d.size);
}

function selectionSummary(selected, total) {
    const n = selected.length;
    if (!n) return total + (total === 1 ? " elemento" : " elementos");
    const bytes = selected.reduce((s, e) => s + (e.kind === "dir" ? 0 : (e.size || 0)), 0);
    return n + " de " + total + (total === 1 ? " elemento" : " elementos") + (n === 1 ? " seleccionado" : " seleccionados") + (bytes ? " · " + formatSize(bytes) : "");
}
