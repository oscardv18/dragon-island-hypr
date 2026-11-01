// Fake Prompts service for the 5c mocks: same surface as services/Prompts.qml, synthetic data, never sends anything.
import QtQuick
import "fixtures/taller5c.js" as Fx
QtObject {
    property string status: "ok"
    property string message: ""
    property string actionError: ""
    property var templates: Fx.templates()
    property bool composerOpen: false
    property string mode: "send"
    property string template: "revisar-cambios"
    property string card: "AX-142"
    property var off: []
    property var result: Fx.reviewPrompt()
    property bool building: false
    property bool sending: false
    property string target: "herdr:p-claude"
    property var targets: [{ id: "herdr:p-claude", label: "claude · AX-142", enabled: true }, { id: "herdr:p-codex", label: "codex · AX-139", enabled: true }, { id: "clipboard", label: "Portapapeles", enabled: true }]
    readonly property var segments: (result.blocks ?? []).filter(b => b.enabled !== false).map(b => ({ id: b.id, label: b.label, tokens: b.tokens, text: b.text }))
    readonly property int redactions: 0
    readonly property string level: levelFor(result.tokens)
    property var lastOpen: null
    function levelFor(t) { return t < 1500 ? "ligero" : t < 3000 ? "medio" : "pesado"; }
    function colorLevel(t) { return t < 1500 ? "ok" : t < 3000 ? "warn" : "high"; }
    function open(opts) { lastOpen = opts; composerOpen = true; }
    function close() { composerOpen = false; }
    function setTemplate(id) { template = id; }
    function toggleBlock(id) {}
    function addBlock(spec) {}
    function send() {}
    function copy() {}
    function saveTemplate(name, cb) {}
    function estimate(opts, cb) { cb({ ok: true, tokens: 296, blocks: [] }); }
}
