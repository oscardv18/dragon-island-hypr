// =============================================================================
// dragon-island — FilePicker.qml (Dragon Portal, fase 6): the explorer as the file dialog of other apps.
// The portal service (`dragon-portal serve`, a D-Bus backend of xdg-desktop-portal) asks for a dialog with
// `qs ipc call picker open <id>`; this service fetches the request with `dragon-portal take <id>`, opens an explorer window in
// selector mode (Files.openWindow with the request) and sends the answer back with `dragon-portal reply <id>` (JSON on stdin).
// The views never talk to the portal: FilesWindow only calls answer() / windowClosed().
// =============================================================================
/**
 * Properties: openCount: int — dialogs open right now
 * Functions:
 *   - init() — instantiates the singleton so the IPC target exists
 *   - answer(uid, result) — result = {response: "accept"|"cancel", paths, filter, choices}; replies once and closes the window
 *   - windowClosed(uid) — the window went away (compositor close, destroyed): answers «cancel» if nobody answered yet
 * IPC (target "picker"): open(id) · has(id): bool — is the dialog of that request still open · cancel(id) — close it silently
 * =============================================================================
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root
    property int openCount: 0
    property var _idOf: ({})      // window uid → request id
    property var _uidOf: ({})     // request id → window uid

    Component { id: requestComponent; PortalRequest {} }

    function init(): void {}
    function call(args, input, callback): void {
        const p = requestComponent.createObject(root, { args: args, input: input ?? "", callback: callback ?? null });
        p.start();
    }

    function open(id): void {
        if (_uidOf[id] !== undefined) return;
        call(["take", id], "", r => {
            if (!r.ok || !r.request) { console.warn("picker take:", id, r.error?.message ?? "sin respuesta"); return; }
            if (_uidOf[id] !== undefined) return;
            const uid = Files.openWindow(r.request.current_folder, r.request);
            const a = Object.assign({}, _idOf), b = Object.assign({}, _uidOf);
            a[uid] = id; b[id] = uid;
            _idOf = a; _uidOf = b;
            openCount = Object.keys(a).length;
        });
    }
    function _forget(uid): string {
        const id = _idOf[uid];
        if (id === undefined) return "";
        const a = Object.assign({}, _idOf), b = Object.assign({}, _uidOf);
        delete a[uid]; delete b[id];
        _idOf = a; _uidOf = b;
        openCount = Object.keys(a).length;
        return id;
    }
    function answer(uid, result): void {
        const id = _forget(uid);
        if (!id) return;
        call(["reply", id], JSON.stringify(result), r => { if (!r.ok) console.warn("picker reply:", id, r.error?.message ?? ""); });
        Files.closeWindow(uid);
    }
    function windowClosed(uid): void { if (_idOf[uid] !== undefined) answer(uid, { response: "cancel" }); }

    IpcHandler {
        target: "picker"
        function open(id: string): void { root.open(id); }
        function has(id: string): bool { return root._uidOf[id] !== undefined; }
        function cancel(id: string): void {
            const uid = root._uidOf[id];
            if (uid === undefined) return;
            root._forget(uid);
            Files.closeWindow(uid);
        }
    }
}
