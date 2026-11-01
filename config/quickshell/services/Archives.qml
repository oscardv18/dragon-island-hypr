// =============================================================================
// dragon-island — Archives.qml (compressed files: list, test, extract, create). Data only.
// `dragon-files archive …` (PLAN-FASE-5 §5.7). The tool extracts into a staging folder inside the destination and
// validates every path, link, special bit, free space and ratio before moving anything; this service only passes the
// user's choices. Extractions and creations run in the FileOps queue so the status bar shows them.
// =============================================================================
/**
 * Properties:
 *   - formats: var [readonly] — what the dialog lists as readable
 *   - cache: var ({path: {format, encrypted, count, total_size, method?, entries, warnings} | {error}}) — `archive list`
 *   - tests: var ({path: "running" | "ok" | {error}}) — `archive test`
 *
 * Functions:
 *   - info(path, callback) — cached `archive list`; loading(path) tells whether a listing is in flight
 *   - test(path, callback)
 *   - extract(path, dest, opts {ownFolder, conflict: ask|skip|overwrite|rename, password, confirmBomb, trashAfter},
 *       callback): int — FileOps id. Errors the dialog handles: password_required, bad_password, bomb_suspected,
 *       unsafe_paths, no_space (codes of the tool)
 *   - create(format: zip|7z|tar.zst|tar.gz|tar.xz, out, paths): int
 *   - forget(path) — drop the cached listing/test (the file changed)
 * =============================================================================
 */
pragma Singleton
import Quickshell
import QtQuick
import "../modules/files/files.js" as F

Singleton {
    id: root
    readonly property var formats: ["ZIP", "7Z", "RAR", "TAR.GZ", "TAR.XZ", "TAR.ZST", "TAR.BZ2", "ISO", "DEB", "RPM", "APPIMAGE", "CAB", "LHA"]
    readonly property var createFormats: ["zip", "7z", "tar.zst", "tar.gz", "tar.xz"]
    property var cache: ({})
    property var tests: ({})
    property var _loading: ({})

    Component { id: requestComponent; FilesRequest {} }

    function loading(path): bool { return !!_loading[path]; }
    function info(path, callback): void {
        if (cache[path]) { if (callback) callback(cache[path]); return; }
        if (_loading[path]) return;
        const l = Object.assign({}, _loading); l[path] = true; _loading = l;
        const p = requestComponent.createObject(root, { args: ["archive", "list", path], callback: r => {
            const nl = Object.assign({}, _loading); delete nl[path]; _loading = nl;
            const c = Object.assign({}, cache); c[path] = r.ok ? r : { error: r.error ?? { message: "No se pudo leer el archivo" } }; cache = c;
            if (callback) callback(c[path]);
        } });
        p.start();
    }
    function test(path, callback): void {
        const t = Object.assign({}, tests); t[path] = "running"; tests = t;
        const p = requestComponent.createObject(root, { args: ["archive", "test", path], callback: r => {
            const nt = Object.assign({}, tests); nt[path] = r.ok ? "ok" : { error: r.error ?? { message: "Falló la prueba" } }; tests = nt;
            if (callback) callback(r);
        } });
        p.start();
    }
    function forget(path): void {
        const c = Object.assign({}, cache); delete c[path]; cache = c;
        const t = Object.assign({}, tests); delete t[path]; tests = t;
    }

    function extract(path, dest, opts, callback): int {
        const o = opts ?? {};
        const args = ["archive", "extract", path, "--dest", dest, "--conflict", o.conflict ?? "ask"];
        if (o.ownFolder) args.push("--own-folder");
        if (o.password) args.push("--password-stdin");
        if (o.confirmBomb) args.push("--confirm-bomb");
        return FileOps.run("extract", args, {
            sources: [path], dest: dest, count: 1, input: o.password ?? "",
            callback: r => {
                if (r.ok && o.trashAfter) FileOps.trash([path]);
                if (callback) callback(r);
            }
        });
    }
    function create(format, out, paths): int {
        return FileOps.run("create", ["archive", "create", "--format", format, "--out", out, "--paths"].concat(paths),
                           { sources: paths, dest: F.parent(out), count: paths.length });
    }
}
