// Fake Mem service for the 5c mocks. moveCard enforces WIP like dragon-mem (wip_limit_reached unless force).
import QtQuick
import "fixtures/taller5c.js" as Fx
QtObject {
    property var project: Fx.project()
    property var projects: [{}, {}, {}, {}]
    property string selectedSlug: "arxnet-erp"
    property string status: "ok"
    property string message: ""
    property var cards: Fx.cards(Date.now())
    property var details: Fx.details()
    property var stats: Fx.stats()
    property var calls: []
    function loadDetails(key) {}
    function refreshBoard() {}
    function toggleCriterion(key, id) {}
    function addCriterion(key, text) {}
    function addCard(title, kind, cb) {}
    function setCard(key, fields, cb) { calls = calls.concat([["set", key, fields]]); if (cb) cb({ ok: true }); }
    function moveCard(key, col, force, cb) {
        calls = calls.concat([["move", key, col, force]]);
        if (col === "doing" && !force && cards.filter(c => c.col === "doing").length >= project.wip_limit) { cb({ ok: false, error: { code: "wip_limit_reached", message: "WIP" } }); return; }
        cards = cards.map(c => c.key === key ? Object.assign({}, c, { col: col }) : c);
        if (cb) cb({ ok: true });
    }
    function call(args, cb) { calls = calls.concat([args]); if (cb) cb({ ok: true, comments: [], seen: [] }); }
}
