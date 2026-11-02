// One dragon-files call (helper of Files, FileOps, Devices and Archives; not a singleton, never used by the UI).
//   args      arguments after the command name; `--json` is added unless stream is set
//   stream    true: stdout is JSON lines (`--json-progress`, `watch`, `devices --watch`); each one → event(obj)
//   input     text written to stdin once and then closed (passwords: never on the command line)
//   keepStdin keep stdin open after `input` so answer(obj) can reply (conflict questions of a running operation)
//   callback  receives the final JSON result: the parsed stdout of a one-shot call, or the last line of a stream
//             that has `ok` or `t:"done"|"error"`. A missing tool → {ok:false,error:{code:"missing_tool"}}.
// Destroys itself when finished unless `persistent` is set (long watchers owned by a service).
import Quickshell
import Quickshell.Io
import QtQuick

Process {
    id: proc
    property var args: []
    property bool stream: false
    property string input: ""
    property bool keepStdin: false
    property bool persistent: false
    property var callback: null
    property var result: null
    property bool ended: false
    property bool collected: false
    property int exitCode: 0
    readonly property string tool: `${Quickshell.env("HOME")}/.local/bin/dragon-files`
    signal event(var obj)
    signal done(var result)

    function start(): void {
        stdinEnabled = input.length > 0 || keepStdin;
        exec(["sh", "-c", 'if [ -x "$0" ]; then exec "$0" "$@"; else exit 127; fi', tool].concat(args).concat(stream ? [] : ["--json"]));
    }
    function answer(obj): void { if (running) write(JSON.stringify(obj) + "\n"); }
    function cancel(): void { if (running) signal(15); }
    function finish(): void {
        if (!ended || !collected) return;
        let r = result;
        if (!r || (stream && r.ok === undefined && r.t !== "error" && r.t !== "done")) {
            if (exitCode === 127) r = { ok: false, error: { code: "missing_tool", message: "dragon-files no está instalado", hint: "Ejecuta ./update.sh" } };
            else if (stream && exitCode === 0) r = { ok: true };
            else if (exitCode === 143 || exitCode === -1 || exitCode === 15) r = { ok: false, error: { code: "cancelled", message: "Cancelado" } };
            else r = { ok: false, error: { code: "invalid_response", message: "dragon-files no respondió como se esperaba", hint: "" } };
        } else if (r.t === "error") r = { ok: false, error: r.error ?? { code: "error", message: "Error" } };
        else if (r.t === "done") r = Object.assign({ ok: true }, r);
        done(r);
        if (callback) callback(r);
        if (!persistent) Qt.callLater(() => proc.destroy());
    }
    onStarted: {
        if (input.length > 0) write(input + "\n");
        if (!keepStdin) stdinEnabled = false;
    }
    stdout: SplitParser {
        // QProcess hands over the remaining output before `exited`, so the last line is always parsed first
        onRead: data => {
            if (!proc.stream) { proc._buffer += data + "\n"; return; }
            const line = data.trim();
            if (!line) return;
            let obj = null;
            try { obj = JSON.parse(line); } catch (e) { return; }
            if (obj.ok !== undefined || obj.t === "done" || obj.t === "error") proc.result = obj;
            proc.event(obj);
        }
    }
    property string _buffer: ""
    onExited: (code, exitStatus) => {
        proc.exitCode = code;
        if (!proc.stream) { try { proc.result = JSON.parse(proc._buffer); } catch (e) { proc.result = null; } }
        proc.ended = true; proc.collected = true; proc.finish();
    }
}
