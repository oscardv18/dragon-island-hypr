// =============================================================================
// dragon-island — Herdr.qml
// Service: the agents running in herdr (agents multiplexer) — state for the "Agentes" capsule and the notch peek
// =============================================================================
/**
 * Zero cost while there is no herdr server: a timer with growing wait (2 s → 30 s) only checks whether the API socket file exists (no log
 * noise). When it does, the state is read with the CLI (`herdr agent list`, `herdr workspace list`, JSON) and kept
 * up to date by a socket subscription (`events.subscribe`: pane.agent_status_changed of every known pane, plus
 * pane / workspace lifecycle). Events are only invalidation signals: each one schedules a debounced re-read.
 *
 * Properties:
 *   - running: bool [readonly] (the server answers)
 *   - agents: list<var> [readonly] ({ pane, name, agent, workspace (label), workspaceId, tab, state, focused, cwd,
 *       title (terminal title of the pane = the task, "" if unknown), since (ms epoch when THIS service saw it enter
 *       `state`; herdr exposes no timestamps, so it is "observed since", not the real start) })
 *   - workspaces: list<var> [readonly] ({ id, label, number, state (agent_status), panes, tabs, focused })
 *   - counts: var [readonly] ({ working, blocked, done, idle, unknown })
 *   - longestWorking: var [readonly] (the agent working since the earliest `since`, or null)
 *   - active: bool [readonly] (there is at least one agent)
 *
 * Signals:
 *   - attention(var agent, string kind): an agent became "blocked" or "done" and nobody is looking at it
 *
 * Functions:
 *   - init(): void
 *   - focusAgent(agent): void (focuses the herdr window and runs `herdr agent focus <pane>`)
 *   - open(): void (SUPER + A)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    readonly property string windowClass: "org.dragonisland.Herdr"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string socketPath: Quickshell.env("HERDR_SOCKET_PATH") || `${root.home}/.config/herdr/herdr.sock`
    readonly property string bin: `${root.home}/.local/bin/herdr`

    property bool running: false
    property var agents: []
    property var workspaces: []
    property bool _loaded: false
    property bool _resub: false     // reconnecting only to subscribe to a new set of panes (state is kept)

    readonly property var counts: {
        const c = { working: 0, blocked: 0, done: 0, idle: 0, unknown: 0 };
        for (const a of root.agents) if (c[a.state] !== undefined) c[a.state]++;
        return c;
    }
    readonly property bool active: root.agents.length > 0
    readonly property var longestWorking: {
        let best = null;
        for (const a of root.agents) if (a.state === "working" && (best === null || a.since < best.since)) best = a;
        return best;
    }

    signal attention(var agent, string kind)

    function init(): void { probe.running = true; }

    function open(): void { launcher.command = [`${root.home}/.local/bin/dragon-herdr`]; launcher.running = true; }

    function focusAgent(agent): void {
        if (!agent) return;
        launcher.command = [`${root.home}/.local/bin/dragon-herdr`, "focus", agent.pane];
        launcher.running = true;
    }

    // a herdr window is in front and that agent's pane is the one it shows: no need to interrupt
    function _beingWatched(a): bool {
        return Hypr.activeClass === root.windowClass && a.focused;
    }

    // ---- 1) is there a server? (checks the socket file, no connection attempt, nothing logged) ----
    Process {
        id: probe
        command: ["test", "-S", root.socketPath]
        onExited: code => {
            if (code === 0) { if (!sock.connected) sock.connected = true; }
            else { root._down(); retry.interval = Math.min(30000, retry.interval * 2); }
        }
    }
    Timer {     // herdr not running: look again after 4, 8, 16 s … up to 30 s (a file test, no log noise)
        id: retry
        interval: 2000
        running: !root.running
        repeat: true
        onTriggered: probe.running = true
    }

    function _down(): void {
        root.running = false;
        root._loaded = false;
        if (root.agents.length > 0) root.agents = [];
        if (root.workspaces.length > 0) root.workspaces = [];
    }

    // ---- 2) state: agents + workspaces (two JSON lines) ----
    Process {
        id: reader
        command: ["sh", "-c", `"${root.bin}" agent list; "${root.bin}" workspace list`]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    function _parse(text: string): void {
        let agents = [], spaces = {}, wsList = [];
        for (const line of text.split("\n")) {
            if (line.length === 0) continue;
            let r;
            try { r = JSON.parse(line).result; } catch (e) { continue; }
            if (!r) continue;
            if (r.agents) agents = r.agents;
            if (r.workspaces) for (const w of r.workspaces) {
                spaces[w.workspace_id] = w.label;
                wsList.push({ id: w.workspace_id, label: w.label, number: w.number, state: w.agent_status, panes: w.pane_count, tabs: w.tab_count, focused: w.focused === true });
            }
        }
        const old = {}, oldSince = {};
        for (const a of root.agents) { old[a.pane] = a.state; oldSince[a.pane] = a.since; }
        const now = Date.now();
        const next = agents.map(a => ({
            pane: a.pane_id, agent: a.agent, workspaceId: a.workspace_id, tab: a.tab_id,
            workspace: spaces[a.workspace_id] ?? a.workspace_id,
            name: a.agent, state: a.agent_status, focused: a.focused === true, cwd: a.cwd ?? "",
            title: a.terminal_title_stripped ?? "",
            since: old[a.pane] === a.agent_status ? oldSince[a.pane] : now
        }));
        root.workspaces = wsList;
        const first = !root._loaded;
        root._loaded = true;
        const prevPanes = root.agents.map(a => a.pane).join(",");
        root.agents = next;
        if (!first) {
            for (const a of next) {
                const was = old[a.pane];
                if (was !== a.state && (a.state === "blocked" || a.state === "done") && !root._beingWatched(a))
                    root.attention(a, a.state);
            }
        }
        // the per-pane subscriptions follow the set of panes
        if (prevPanes !== next.map(a => a.pane).join(",") && sock.connected) { root._resub = true; sock.connected = false; }
    }

    Timer { id: debounce; interval: 150; onTriggered: if (!reader.running) reader.running = true; else debounce.restart() }

    // ---- 3) events ----
    function _subscribe(): void {
        const subs = [{ type: "pane.created" }, { type: "pane.closed" }, { type: "workspace.created" },
                      { type: "workspace.closed" }, { type: "workspace.renamed" }];
        for (const a of root.agents) subs.push({ type: "pane.agent_status_changed", pane_id: a.pane });
        sock.write(JSON.stringify({ id: "qs", method: "events.subscribe", params: { subscriptions: subs } }) + "\n");
        sock.flush();
    }

    Socket {
        id: sock
        path: root.socketPath
        parser: SplitParser {
            onRead: line => {
                if (line.indexOf('"event"') >= 0) debounce.restart();
                else if (line.indexOf("events_lost") >= 0 || line.indexOf('"error"') >= 0) { root._resub = true; sock.connected = false; }
            }
        }
        onConnectedChanged: {
            if (connected) {
                root.running = true;
                retry.interval = 2000;
                if (!root._loaded) reader.running = true;
                root._subscribe();
            } else if (root._resub) {
                root._resub = false;
                resubTimer.start();
            } else {
                root._down();
            }
        }
        onError: root._down()   // server gone: back to the 30 s check, silently
    }
    Timer { id: resubTimer; interval: 100; onTriggered: sock.connected = true }
    Timer { id: reconnect; interval: 1000; onTriggered: probe.running = true }

    Process { id: launcher }
}
