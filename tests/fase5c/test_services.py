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


KANBAN = """import Quickshell
import QtQuick
import "services"
ShellRoot {
    property int phase: 0
    property var keys: []
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    Component.onCompleted: Mem.addProject(Quickshell.env("HOME") + "/repo", "Proyecto", "AX", r => {
        if (!r.ok) return fail("project");
        Mem.call(["project", "set", r.project.slug, "--wip-limit", "1"], () => { Mem.refresh(); phase = 1; });
    })
    Timer { interval: 60; running: true; repeat: true
        onTriggered: {
            if (phase === 1 && Mem.project?.wip_limit === 1) {
                Mem.addCard("Primera", "feat", a => Mem.addCard("Segunda", "fix", b => { keys = [a.card.key, b.card.key]; phase = 2; }));
                phase = 99;
            } else if (phase === 2 && Mem.cards.length === 2 && Mem.stats) {
                Mem.addCriterion(keys[0], "Criterio uno"); phase = 3;
            } else if (phase === 3 && (Mem.details[keys[0]]?.criteria ?? []).length === 1) {
                Mem.toggleCriterion(keys[0], Mem.details[keys[0]].criteria[0].id); phase = 4;
            } else if (phase === 4 && Mem.details[keys[0]].criteria[0].done === 1) {
                Mem.moveCard(keys[0], "doing", false, r => { if (!r.ok) fail("first move"); else Mem.moveCard(keys[1], "doing", false, r2 => {
                    if (r2.error?.code !== "wip_limit_reached") return fail("WIP not enforced " + JSON.stringify(r2));
                    Mem.moveCard(keys[1], "doing", true, r3 => { if (!r3.ok) fail("force"); phase = 5; });
                }); });
                phase = 98;
            } else if (phase === 5 && Mem.cards.filter(c => c.col === "doing").length === 2) {
                if (!(Mem.details[keys[1]]?.events ?? []).some(e => e.kind === "started")) return;
                console.log("FASE5C_KANBAN_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 20000; running: true; onTriggered: fail("timeout " + Mem.status + " " + Mem.message) }
}
"""


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class KanbanMemory(unittest.TestCase):
    def test_wip_criteria_and_stats(self):
        out, _ = run_shell(KANBAN, setup=lambda home, env: git_repo(home, env))
        self.assertIn('FASE5C_KANBAN_OK', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)


START = """import Quickshell
import QtQuick
import "services"
ShellRoot {
    property int phase: 0
    property var keys: []
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    Component.onCompleted: Mem.addProject(Quickshell.env("HOME") + "/repo", "Proyecto", "AX", r => {
        if (!r.ok) return fail("project");
        Mem.call(["project", "set", r.project.slug, "--wip-limit", "1"], () => { Mem.refresh(); phase = 1; });
    })
    Timer { interval: 60; running: true; repeat: true
        onTriggered: {
            if (phase === 1 && Mem.project?.wip_limit === 1) {
                Mem.addCard("Filtros de facturas", "feat", a => Mem.addCard("Otra", "fix", b => {
                    keys = [a.card.key, b.card.key];
                    Mem.moveCard(b.card.key, "doing", false, () => phase = 2);
                }));
                phase = 99;
            } else if (phase === 2 && Mem.cards.some(c => c.col === "doing")) {
                Prompts.open({ mode: "start", card: keys[0] }); phase = 3;
            } else if (phase === 3 && !Prompts.building && Prompts.result.tokens > 0) {
                if (Prompts.target !== "start:claude") return fail("start target");
                if (Mem.cardByKey(keys[0]).worktree) return fail("worktree before send");
                Prompts.send(); phase = 4;
            } else if (phase === 4) {
                if (!Prompts.startWarning.includes("lleno")) return fail("WIP warning");
                if (Prompts.sending) return fail("started despite WIP");
                Prompts.startCard(Prompts.startKind, true); phase = 5;
            } else if (phase === 5 && !Prompts.composerOpen) {
                const c = Mem.cardByKey(keys[0]);
                if (!c || c.col !== "doing" || c.agent_ref !== "pane-9" || !c.worktree.endsWith("repo-ax1") || c.branch !== "feat/ax-1-filtros-de-facturas") return;
                console.log("FASE5C_START_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 25000; running: true; onTriggered: fail("timeout " + Prompts.actionError + " " + Prompts.startStep + " " + JSON.stringify(Mem.cardByKey(keys[0]))) }
}
"""


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class StartFlow(unittest.TestCase):
    def test_worktree_agent_prompt_and_card(self):
        def setup(home, env):
            git_repo(home, env)
        out, data = run_shell(START, setup=setup, fakes=('dragon-prompt', 'dragon-gate', 'dragon-herdr'))
        self.assertIn('FASE5C_START_OK', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)
        sent = [json.loads(l) for l in data['sent'].splitlines()]
        self.assertEqual([s['target'] for s in sent], ['herdr:pane-9'])
        self.assertIn('## Tarjeta', sent[0]['text'])
        self.assertEqual(len(data['herdr']), 1, data['herdr'])
        self.assertTrue(data['herdr'][0]['cwd_exists'])
        self.assertEqual(data['herdr'][0]['args'][data['herdr'][0]['args'].index('--kind') + 1], 'claude')


REVIEW = """import Quickshell
import QtQuick
import "services"
ShellRoot {
    property int phase: 0
    property string key: ""
    readonly property string repo: Quickshell.env("HOME") + "/repo"
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    Component { id: sh; ToolRequest {} }
    Component.onCompleted: Mem.addProject(repo, "Proyecto", "AX", r => {
        if (!r.ok) return fail("project");
        Mem.addCard("Revisar", "feat", c => { key = c.card.key; Mem.setCard(key, { worktree: repo, agent_ref: "pane-1" }, () => phase = 1); });
    })
    Timer { interval: 60; running: true; repeat: true
        onTriggered: {
            if (phase === 1 && Mem.cardByKey(key)?.worktree) { Review.setCard(key); Review.activate(true); phase = 2; }
            else if (phase === 2 && Review.status === "ok" && Review.files.length === 1 && Review.diffData.hunks?.length) {
                if (!Review.watching) return fail("live watch should run while visible");
                if (Review.unseenCount !== 1 || Review.files[0].path !== "nuevo.txt") return fail("files");
                Review.markSeen("nuevo.txt"); phase = 3;
            } else if (phase === 3 && Review.seenCount === 1) {
                sh.createObject(null, { callback: () => phase = 4 }).exec(["sh", "-c", 'printf "otra\\\\n" >> "$0"; echo "{\\\\"ok\\\\":true}"', repo + "/nuevo.txt"]);
                phase = 97;
            } else if (phase === 4 && Review.files[0]?.changed) {
                if (Review.seenCount !== 0) return fail("changed file must be unseen");
                Review.addComment("nuevo.txt", 1, "¿Por qué este texto?"); phase = 5;
            } else if (phase === 5 && Review.comments.length === 1 && Review.reviewTokens > 0) {
                Prompts.open({ template: "revisar-cambios", card: key }); phase = 6;
            } else if (phase === 6 && !Prompts.building && Prompts.result.tokens > 0) {
                Prompts.send(); phase = 7;
            } else if (phase === 7 && Review.comments[0]?.sent === 1) {
                Review.activate(false); phase = 8;
            } else if (phase === 8) {
                if (Review.watching) return fail("watch must stop when the tab is hidden");
                console.log("FASE5C_REVIEW_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 25000; running: true; onTriggered: fail("timeout " + Review.status + " " + Review.message + " " + JSON.stringify(Review.files)) }
}
"""


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class ReviewFlow(unittest.TestCase):
    def test_seen_by_content_comments_and_watch(self):
        out, data = run_shell(REVIEW, setup=lambda home, env: git_repo(home, env))
        self.assertIn('FASE5C_REVIEW_OK', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)
        self.assertEqual([json.loads(l)['target'] for l in data['sent'].splitlines()], ['clipboard'])


if __name__ == '__main__':
    unittest.main()
