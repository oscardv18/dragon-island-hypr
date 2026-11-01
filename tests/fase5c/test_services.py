"""Prompts and Gate with real Quickshell: nothing leaves before send(), redactions, --off, gates and fallbacks."""
import json
import shutil
import unittest
from helpers import run_shell, git_repo, BAD

SHELL = '''import Quickshell
import QtQuick
import "services"
ShellRoot {
    property int phase: 0
    property var card: null
    readonly property string repo: Quickshell.env("HOME") + "/repo"
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    Component.onCompleted: Mem.addProject(repo, "Proyecto", "AX", r => {
        if (!r.ok) return fail("project " + JSON.stringify(r));
        Mem.call(["project", "set", r.project.slug, "--test-cmd", "true"], () =>
            Mem.call(["card", "add", "--project", r.project.slug, "--title", "Filtros"], c => {
                card = { key: c.card.key, events: [] }; Mem.refresh(); phase = 1;
            }));
    })
    Timer { interval: 60; running: true; repeat: true
        onTriggered: {
            if (phase === 1 && Mem.project?.test_cmd === "true") {
                Prompts.open({ card: card.key }); phase = 2;
            } else if (phase === 2 && !Prompts.building && Prompts.result.tokens > 0) {
                if (Prompts.template !== "implementar-tarjeta") return fail("default template");
                if (Prompts.segments.length !== 3 || Prompts.segments[0].label !== "Tarjeta") return fail("segments " + JSON.stringify(Prompts.segments));
                if (Prompts.target !== "clipboard") return fail("default target must be safe");
                if (Prompts.level !== "ligero") return fail("level");
                Prompts.toggleBlock("commands-2"); phase = 3;
            } else if (phase === 3 && !Prompts.building && Prompts.result.blocks.some(b => b.id === "commands-2" && !b.enabled)) {
                if (Prompts.segments.length !== 2) return fail("off block still previewed");
                Prompts.addBlock("text:clave ghp_secretvalue"); phase = 4;
            } else if (phase === 4 && !Prompts.building && Prompts.result.blocks.length === 4) {
                if (Prompts.redactions !== 1) return fail("redactions");
                if (Prompts.result.text.includes("ghp_secretvalue")) return fail("secret in preview");
                console.log("NOTHING_SENT_YET"); Prompts.copy(); phase = 5;
            } else if (phase === 5 && !Prompts.sending) {
                if (!Prompts.composerOpen) return fail("copy must not close");
                Prompts.target = "herdr:agente-1"; Prompts.send(); phase = 6;
            } else if (phase === 6 && !Prompts.sending && !Prompts.composerOpen) {
                Gate.evaluate(card, Mem.project); phase = 7;
            } else if (phase === 7 && Gate.gates[card.key]?.seen && Gate.gates[card.key]?.conflicts?.state === "unknown") {
                const g = Gate.gates[card.key];
                if (g.tests.state !== "none") return fail("tests " + JSON.stringify(g.tests));
                if (g.seen.total !== 1 || g.seen.seen !== 0 || g.ready) return fail("seen " + JSON.stringify(g.seen));
                if (Gate.mergeCheckSupported !== false || Gate.baseSupported !== false) return fail("fallbacks");
                Gate.run(card, Mem.project); phase = 8;
            } else if (phase === 8 && Gate.runs[card.key]?.state === "ok") {
                if (Gate.gates[card.key].tests.state !== "ok") return fail("tests gate after run");
                Gate.call(Gate.gitTool, ["blob-hash", "--repo", repo, "--path", "nuevo.txt"], h =>
                    Mem.call(["seen", "set", card.key, "--path", "nuevo.txt", "--hash", h.hash], () => { Gate.evaluate(card, Mem.project); phase = 9; }));
                phase = 99;
            } else if (phase === 9 && Gate.gates[card.key]?.seen?.seen === 1 && Gate.gates[card.key]?.conflicts?.state === "unknown") {
                const g = Gate.gates[card.key];
                if (g.ready || !g.needsConfirm) return fail("unknown conflicts must ask " + JSON.stringify(g));
                console.log("FASE5C_SERVICES_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 30000; running: true; onTriggered: fail("timeout " + Prompts.status + " " + Prompts.message + " " + JSON.stringify(Gate.gates)) }
}
'''


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class PromptAndGate(unittest.TestCase):
    def test_compose_send_and_gates(self):
        out, data = run_shell(SHELL, setup=lambda home, env: git_repo(home, env))
        self.assertIn('FASE5C_SERVICES_OK', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)
        sent = [json.loads(l) for l in data['sent'].splitlines()]
        self.assertEqual([s['target'] for s in sent], ['clipboard', 'herdr:agente-1'])
        self.assertNotIn('ghp_secretvalue', data['sent'])
        self.assertNotIn('## Comandos', sent[0]['text'])



WIRING = '''import Quickshell
import QtQuick
import "services"
import "modules/taller"
ShellRoot {
    property int phase: 0
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    FloatingWindow {
        implicitWidth: 1226; implicitHeight: 612
        TallerPanel { id: panel; anchors.fill: parent; shown: true; agentService: Herdr; memService: Mem; dockerService: Docker; gitService: Git; promptService: Prompts; tab: Taller.tab }
    }
    Timer { interval: 80; running: true; repeat: true
        onTriggered: {
            if (phase === 0) { Taller.openComposer({ template: "libre" }); phase = 1; }
            else if (phase === 1) {
                if (!Prompts.composerOpen || !panel.composerOpen || ShellState.openPanel !== "taller") return fail("composer did not open");
                ShellState.close(); phase = 2;
            } else if (phase === 2) {
                if (Prompts.composerOpen) return fail("closing the Taller must close the composer");
                console.log("FASE5C_WIRING_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 15000; running: true; onTriggered: fail("timeout") }
}
'''
WIRING_QMLDIR = 'singleton Taller 1.0 Taller.qml\nsingleton Docker 1.0 Docker.qml\nsingleton Git 1.0 Git.qml\n'


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class Wiring(unittest.TestCase):
    def test_panel_with_real_services(self):
        out, data = run_shell(WIRING, extra_qmldir=WIRING_QMLDIR)
        self.assertIn('FASE5C_WIRING_OK', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)
        self.assertEqual(data['sent'], '')


if __name__ == '__main__':
    unittest.main()
