// Fake Gate service: fixed gates from the fixture, no processes.
import QtQuick
import "fixtures/taller5c.js" as Fx
QtObject {
    property var gates: Fx.gates()
    property var runs: ({})
    signal finished(string key, var result)
    function evaluate(card, project) {}
    function run(card, project) {}
    function cancel(key) {}
    function changedFiles(repo, cb) { cb({ ok: true, files: Fx.reviewFiles(), base: true }); }
}
