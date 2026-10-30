// =============================================================================
// dragon-island — WindowContext.qml
// Service: what the focused window is about, for the "live context" of the left island.
// Data only: the UI binds to these properties.
// =============================================================================
/**
 * Terminals and editors: the working directory, its git branch (`git -C <cwd> rev-parse --abbrev-ref HEAD`) and the
 * repository name. The directory comes, in this order, from: herdr's focused agent pane when the window runs herdr
 * (every pane hangs from the same client process; services/Herdr.qml) · the window title when the shell puts the
 * directory there ("user@host:~/path", "~/path", "/path": zsh / Ghostty shell integration) · the deepest child
 * process of the window (/proc, newest child at each level; shells may keep helpers with another cwd, hence last).
 * Cached for ~5 s and refreshed every 5 s while such a window is focused (a `cd` changes it).
 * Apps with notifications (Telegram…): the unread notifications of that app (Notifs).
 *
 * Properties:
 *   - appName: string [readonly] (friendly name from DesktopEntries, never the class; "" without a window)
 *   - icon: string [readonly] (image source of the app icon)
 *   - title: string [readonly] (repository / folder name for terminals and editors, else appName)
 *   - chip: string [readonly] (branch name, "N sin leer", or "")
 *   - chipKind: string [readonly] ("branch" | "unread" | "")
 *   - cwd: string [readonly] (terminals / editors only, "" otherwise)
 *   - isDev: bool [readonly] (the focused window is a terminal or a code editor)
 *   - masked: bool [readonly] (recording mode with "hide titles": title becomes "título oculto", no chip, no icon)
 *
 * Functions:
 *   - refresh(): void (forget the cache and read again)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    readonly property string _class: Hypr.activeClass
    readonly property var _entry: _class.length > 0 ? DesktopEntries.heuristicLookup(_class) : null
    readonly property int _pid: Hypr.activeToplevel?.lastIpcObject?.pid ?? -1

    readonly property string appName: {
        if (_class.length === 0) return "";
        if (_entry?.name) return _entry.name;
        // no desktop entry: the last dotted part of the class, capitalised (org.telegram.desktop → Telegram)
        const parts = _class.split(".").filter(p => p.length > 0 && ["desktop", "org", "com", "io", "net", "app"].indexOf(p.toLowerCase()) < 0);
        const n = parts.length > 0 ? parts[parts.length - 1] : _class;
        return n.charAt(0).toUpperCase() + n.slice(1);
    }
    readonly property bool masked: RecordingMode.hideTitles
    readonly property string icon: masked ? "" : Hypr.activeIcon

    readonly property bool isDev: /^(com\.mitchellh\.ghostty.*|org\.dragonisland\.(herdr|pkg|setup)|kitty|alacritty|foot|footclient|org\.wezfurlong\.wezterm|wezterm|org\.kde\.konsole|konsole|code|code-oss|codium|vscodium|cursor|zed|dev\.zed\.zed.*|neovide|org\.kde\.kate|kate|jetbrains-.*)$/i.test(_class)

    property string cwd: ""
    property string _branch: ""
    property string _repo: ""

    // herdr inside Ghostty: the focused agent pane knows its cwd
    readonly property var _herdrFocused: Herdr.running ? (Herdr.agents.find(a => a.focused) ?? null) : null
    readonly property bool _inHerdr: isDev && _herdrFocused !== null && /herdr/i.test(Hypr.activeTitle)

    readonly property var _unread: {
        if (_class.length === 0) return [];
        const cls = _class.toLowerCase(), name = appName.toLowerCase();
        return Notifs.unreadList().filter(n => (n.desktopEntry ?? "").toLowerCase() === cls || (n.appName ?? "").toLowerCase() === name);
    }

    readonly property string title: {
        if (masked) return "título oculto";
        if (!isDev || cwd.length === 0) return appName;
        if (_repo.length > 0) return _repo;
        const home = Quickshell.env("HOME");
        if (cwd === home) return "~";
        return cwd.split("/").filter(p => p.length > 0).pop() ?? cwd;
    }
    readonly property string chipKind: masked ? "" : isDev && _branch.length > 0 ? "branch" : (_unread.length > 0 ? "unread" : "")
    readonly property string chip: chipKind === "branch" ? _branch : (chipKind === "unread" ? `${_unread.length} sin leer` : "")

    property var _cache: ({})     // key → { at, cwd, branch, repo }

    // "oddv@host:~/Devs/x", "~/Devs/x", "/tmp" → the directory ("" if the title is something else)
    readonly property string _titleDir: {
        if (!isDev) return "";
        const m = /(?:^|:)\s*((?:~|\/)[^\s:]*)\s*$/.exec(Hypr.activeTitle);
        if (!m) return "";
        return m[1].startsWith("~") ? Quickshell.env("HOME") + m[1].slice(1) : m[1];
    }
    readonly property string _knownDir: _inHerdr ? _herdrFocused.cwd : _titleDir

    function _key(): string { return _knownDir.length > 0 ? `dir:${_knownDir}` : `pid:${_pid}`; }

    function refresh(): void { root._cache = ({}); _update(); }

    function _update(): void {
        if (!isDev || (_pid <= 0 && _knownDir.length === 0)) { root.cwd = ""; root._branch = ""; root._repo = ""; return; }
        const k = _key();
        const c = root._cache[k];
        if (c && Date.now() - c.at < 5000) { root.cwd = c.cwd; root._branch = c.branch; root._repo = c.repo; return; }
        probe.key = k;
        probe.exec(["sh", "-c", root._script, "sh", `${_pid}`, _knownDir]);
    }

    // $1 = pid (deepest descendant's cwd) or "" with $2 = a known cwd. Prints cwd, branch, repository top level.
    readonly property string _script: '
        dir="$2"
        if [ -z "$dir" ]; then
            pid="$1"; depth=0
            while [ $depth -lt 12 ]; do
                kids=$(cat /proc/"$pid"/task/*/children 2>/dev/null | tr " " "\\n" | grep -v "^$" | tail -n 1)
                [ -n "$kids" ] || break
                pid=$kids; depth=$((depth + 1))
            done
            dir=$(readlink /proc/"$pid"/cwd 2>/dev/null) || exit 0
        fi
        printf "%s\\n" "$dir"
        git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo'

    Process {
        id: probe
        property string key: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const top = lines[2] ?? "";
                const entry = { at: Date.now(), cwd: lines[0] ?? "", branch: (lines[1] ?? "").trim(), repo: top.length > 0 ? top.split("/").pop() : "" };
                const c = Object.assign({}, root._cache);
                c[probe.key] = entry;
                root._cache = c;
                if (probe.key === root._key()) { root.cwd = entry.cwd; root._branch = entry.branch; root._repo = entry.repo; }
            }
        }
    }

    on_PidChanged: _update()
    onIsDevChanged: _update()
    on_KnownDirChanged: _update()

    // a `cd` in the terminal changes the cwd: look again every 5 s while a terminal / editor is focused
    Timer {
        interval: 5000
        repeat: true
        running: root.isDev
        onTriggered: root._update()
    }
}
