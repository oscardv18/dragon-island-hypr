// =============================================================================
// dragon-island — BottomConfig.qml
// Service: settings of the bottom islands (watched apps, editors, strip height, layer)
// =============================================================================
/**
 * Reads ~/.config/dragon-island/bottom-islands.json (defaults live in the repo: config/dragon-island/, copied by
 * migration 014 / the core module) and, on top of it, bottom-islands.local.json (never versioned: its top-level keys
 * replace the ones above). Both files hot-reload. A missing or broken file leaves the previous values in place.
 *
 * File format:
 *   layer: "top" | "overlay"      (overlay = also above fullscreen windows)
 *   stripHeight: number           (px of the invisible detection strip, clamped 1..24)
 *   watched: [{ id, label, match: { class?, tray?, desktop?, process? } }]
 *   hideTray: [regex]             (tray items whose id / title match are not shown)
 *   editors: { classes: [regex], processes: [regex] }
 *   adapters: { protonvpn: bool }  (per-app status adapters, all OFF unless set; there is no OBS adapter, see HANDOFF)
 * Every match value is a case-insensitive regular expression that must match the WHOLE value
 * (window class / initialClass, tray item id or title, process name; `desktop` is a desktop entry id, used for the icon).
 *
 * Properties:
 *   - layer: string [readonly], stripHeight: real [readonly]
 *   - watched: list<var> [readonly]  hideTray: list<string> [readonly]  editorClasses / editorProcesses: list<string> [readonly]
 *   - ready: bool [readonly] (a valid user file was read)  error: string [readonly] (last parse error, "" when fine)
 *
 * Functions:
 *   - adapter(name: string): bool
 *   - matches(pattern: string, value: string): bool   (whole-value, case-insensitive; an invalid regex never matches)
 *   - anyMatches(patterns: list<string>, value: string): bool
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string userPath: `${configHome}/dragon-island/bottom-islands.json`
    readonly property string localPath: `${configHome}/dragon-island/bottom-islands.local.json`

    property var _user: ({})
    property var _local: ({})
    property bool ready: false
    property string error: ""

    readonly property var _merged: Object.assign({}, root._user, root._local)

    readonly property string layer: root._merged.layer === "overlay" ? "overlay" : "top"
    readonly property real stripHeight: {
        const v = Number(root._merged.stripHeight);
        return isNaN(v) || v <= 0 ? 4 : Math.max(1, Math.min(24, Math.round(v)));
    }
    readonly property var watched: Array.isArray(root._merged.watched) ? root._merged.watched.filter(w => w && w.id && w.match) : []
    readonly property var hideTray: Array.isArray(root._merged.hideTray) ? root._merged.hideTray : []
    readonly property var editorClasses: Array.isArray(root._merged.editors?.classes) ? root._merged.editors.classes : []
    readonly property var editorProcesses: Array.isArray(root._merged.editors?.processes) ? root._merged.editors.processes : []

    function adapter(name: string): bool { return root._merged.adapters?.[name] === true; }

    function matches(pattern: string, value: string): bool {
        if (!pattern || !value) return false;
        try { return new RegExp(`^(?:${pattern})$`, "i").test(value); } catch (e) { return false; }
    }
    function anyMatches(patterns, value: string): bool {
        for (const p of patterns ?? []) if (root.matches(p, value)) return true;
        return false;
    }

    FileView {
        path: root.userPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root._user = JSON.parse(text()) || {}; root.ready = true; root.error = ""; }
            catch (e) { root.error = `${root.userPath}: ${e}`; }
        }
        onLoadFailed: { root.ready = false; root._user = {}; }
    }
    FileView {
        path: root.localPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root._local = JSON.parse(text()) || {}; }
            catch (e) { root.error = `${root.localPath}: ${e}`; }
        }
        onLoadFailed: root._local = ({})
    }
}
