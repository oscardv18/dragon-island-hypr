// =============================================================================
// dragon-island — BackgroundApps.qml
// Service: apps that are "closed but alive" — tray items + windows elsewhere + watched processes (Apps tab of the notch dashboard)
// =============================================================================
/**
 * Joins three sources into one list without repeating an app (see AppsConfig for the `watched` list):
 *   1. the system tray: every StatusNotifierItem (Passive ones too), except `hideTray`;
 *   2. windows of watched apps that are NOT on a visible workspace (other workspace / special workspace);
 *   3. watched apps with a `process` match that have neither a tray item nor a window (process table, `ps`).
 * Order: the watched apps in the order of the list, then everything else alphabetically.
 *
 * Properties:
 *   - entries: list<var> [readonly]. Each entry:
 *       key: string (stable)   id: string   label: string
 *       kind: "tray" | "window" | "process"
 *       trayItem: SystemTrayItem | null   hasWindow: bool   windows: list<HyprlandToplevel> (the background ones)
 *       status: "active" | "passive" | "attention" | "none"   (tray status; "none" = no tray item)
 *       workspace: string (label of the first background window's workspace, "" if unknown)
 *       wsShort: string (what fits in a miniature: "3", "S" for a special workspace)
 *       vpn: "on" | "off" | "" (Proton VPN adapter: the chip gets a green ring while connected)
 *       extra: string (adapter status line, "" = none; only with AppsConfig.adapter("protonvpn") for the protonvpn entry)
 *       pid: int (0 = unknown)   desktopId: string (watched `desktop`)   attention: bool
 *   - count: int [readonly]
 *
 * Functions:
 *   - setWatching(on: bool): void   (the process table is only read while the Apps tab is open: 10 s, plus once on reveal)
 *   - activate(entry, menuAnchor): void   left click: focus the window → tray activate() → open the desktop entry
 *   - secondaryActivate(entry): void      middle click
 *   - scroll(entry, dx: int, dy: int): void
 *   - closeWindows(entry): void           closes the background windows of the app (never kills a process)
 *   - icon(entry, failed: bool): string   Image source for the chip
 *   - stateText(entry): string            tooltip line ("Activa", "En el workspace 3", "Proceso en ejecución" …)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import ".."

Singleton {
    id: root

    property bool _watching: false
    property var _procs: ({})        // process name → pid
    function setWatching(on: bool): void {
        if (root._watching === on) return;
        root._watching = on;
        if (on) ps.running = true;
    }

    // ---- 3) processes ----
    Process {
        id: ps
        command: ["ps", "-eo", "pid=,comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(.+)$/);
                    if (m && map[m[2]] === undefined) map[m[2]] = parseInt(m[1]);
                }
                root._procs = map;
            }
        }
    }
    Timer {
        interval: 10000
        running: root._watching
        repeat: true
        onTriggered: if (!ps.running) ps.running = true
    }

    function _procPid(pattern: string): int {
        if (!pattern) return 0;
        for (const name of Object.keys(root._procs)) if (AppsConfig.matches(pattern, name)) return root._procs[name];
        return 0;
    }

    // ---- joining ----
    function _wsInfo(t): var {
        const ws = t.workspace;
        if (!ws) return { text: "", short: "" };
        if (ws.id < 0 || (ws.name ?? "").startsWith("special:")) {
            const n = (ws.name ?? "").replace(/^special:/, "");
            return { text: `especial · ${n}`, short: "S" };
        }
        return { text: `${ws.id}`, short: `${ws.id}` };
    }

    function _statusOf(item): string {
        if (!item) return "none";
        if (item.status === Status.NeedsAttention) return "attention";
        if (item.status === Status.Passive) return "passive";
        return "active";
    }

    readonly property var entries: {
        const cfg = AppsConfig.watched;
        const byKey = {};
        const order = [];
        const mk = (key, id, label, idx) => {
            const e = { key, id, label, kind: "window", trayItem: null, hasWindow: false, windows: [], status: "none",
                        workspace: "", wsShort: "", extra: "", vpn: "", pid: 0, desktopId: "", attention: false, _idx: idx };
            byKey[key] = e; order.push(e);
            return e;
        };
        const watchedFor = (field, ...values) => {
            for (let i = 0; i < cfg.length; i++)
                for (const v of values) if (v && AppsConfig.matches(cfg[i].match[field] ?? "", v)) return i;
            return -1;
        };

        // 1) tray
        for (const item of SystemTray.items.values) {
            if (AppsConfig.anyMatches(AppsConfig.hideTray, item.id) || AppsConfig.anyMatches(AppsConfig.hideTray, item.title)) continue;
            const wi = watchedFor("tray", item.id, item.title);
            let e = null;
            if (wi >= 0 && !byKey[`w:${cfg[wi].id}`]) e = mk(`w:${cfg[wi].id}`, cfg[wi].id, cfg[wi].label ?? cfg[wi].id, wi);
            else if (wi < 0) e = mk(`t:${item.id}`, item.id, item.title || item.tooltipTitle || item.id, 1000);
            else continue;   // a second tray item of an app already represented
            e.kind = "tray";
            e.trayItem = item;
            e.status = root._statusOf(item);
            e.attention = item.status === Status.NeedsAttention;
            if (wi >= 0) e.desktopId = cfg[wi].match.desktop ?? "";
        }

        // 2) windows of watched apps (or of a tray app) that are not on a visible workspace
        for (const t of Hyprland.toplevels.values) {
            const cls = t.wayland?.appId || t.lastIpcObject?.class || "";
            const init = t.lastIpcObject?.initialClass ?? "";
            let wi = watchedFor("class", cls, init);
            let e = wi >= 0 ? byKey[`w:${cfg[wi].id}`] : null;
            if (!e && wi >= 0) { e = mk(`w:${cfg[wi].id}`, cfg[wi].id, cfg[wi].label ?? cfg[wi].id, wi); e.desktopId = cfg[wi].match.desktop ?? ""; }
            if (!e) {   // unwatched app whose window class is its tray id
                const lc = cls.toLowerCase();
                e = order.find(o => o.trayItem && lc.length > 0 && o.trayItem.id.toLowerCase() === lc) ?? null;
            }
            if (!e) continue;
            e.hasWindow = true;
            if (t.workspace?.active) continue;       // on screen: not "in the background"
            e.windows.push(t);
            const pid = t.lastIpcObject?.pid ?? 0;
            if (!e.pid && pid) e.pid = pid;
        }
        for (const e of order) {
            if (e.windows.length > 0) {
                const w = root._wsInfo(e.windows[0]);
                e.workspace = w.text; e.wsShort = w.short;
            }
        }
        // an app that only has windows on screen is not in the background
        for (let i = order.length - 1; i >= 0; i--) {
            const e = order[i];
            if (!e.trayItem && e.windows.length === 0 && e.hasWindow) { order.splice(i, 1); delete byKey[e.key]; }
        }

        // 3) watched processes with neither tray nor window
        if (root._watching) {
            for (let i = 0; i < cfg.length; i++) {
                const key = `w:${cfg[i].id}`;
                if (byKey[key]) continue;
                const pid = root._procPid(cfg[i].match.process ?? "");
                if (pid > 0) {
                    const e = mk(key, cfg[i].id, cfg[i].label ?? cfg[i].id, i);
                    e.kind = "process"; e.pid = pid; e.desktopId = cfg[i].match.desktop ?? "";
                }
            }
        }

        for (const e of order) if (e.windows.length > 0 && !e.trayItem) e.kind = "window";
        // adapter: Proton VPN state from its network interface (services/Vpn.qml, which already watches /sys/class/net)
        if (AppsConfig.adapter("protonvpn")) {
            const p = byKey["w:protonvpn"];
            if (p) { p.vpn = Vpn.active ? "on" : "off"; p.extra = Vpn.active ? `VPN conectada (${Vpn.iface})` : "VPN desconectada"; }
        }
        order.sort((a, b) => a._idx !== b._idx ? a._idx - b._idx : a.label.localeCompare(b.label));
        return order;
    }
    readonly property int count: entries.length

    // ---- presentation helpers ----
    function icon(entry, failed: bool): string {
        if (entry.trayItem) return Tray.iconSource(entry.trayItem, failed);
        const de = DesktopEntries.heuristicLookup(entry.desktopId || entry.id);
        return Quickshell.iconPath(de?.icon || entry.id, "application-x-executable");
    }

    function stateText(entry): string {
        if (!entry) return "";
        if (entry.extra) return entry.extra;
        if (entry.attention) return "Requiere atención";
        if (entry.windows.length > 0) return `Ventana en el workspace ${entry.workspace}`;
        if (entry.kind === "tray") return entry.status === "passive" ? "Solo en la bandeja (pasiva)" : "Solo en la bandeja";
        if (entry.kind === "process") return "Proceso en ejecución, sin ventana ni bandeja";
        return "";
    }

    // ---- actions ----
    function activate(entry, menuAnchor): void {
        if (!entry) return;
        if (entry.windows.length > 0) { Hypr.focusWindow(entry.windows[0].address); return; }
        if (entry.trayItem) { Tray.click(entry.trayItem, menuAnchor); return; }
        const de = DesktopEntries.heuristicLookup(entry.desktopId || entry.id);
        if (de) de.execute();
    }
    function secondaryActivate(entry): void { Tray.secondaryActivate(entry?.trayItem); }
    function scroll(entry, dx: int, dy: int): void { Tray.scroll(entry?.trayItem, dx, dy); }
    function closeWindows(entry): void {
        for (const t of (entry?.windows ?? [])) Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${Hypr.addr(t.address)}" })`);
    }
}
