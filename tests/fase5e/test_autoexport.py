"""Punto 8: .dragon/CONTEXT.md follows card changes with no click. Real Quickshell, real dragon-mem, isolated HOME."""
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'fase5c'))
from helpers import run_shell, git_repo, BAD  # noqa: E402

SHELL = '''import Quickshell
import QtQuick
import "services"
ShellRoot {
    property int phase: 0
    property string slug: ""
    property string key: ""
    property int calls: 0
    readonly property string repo: Quickshell.env("HOME") + "/repo"
    readonly property string context: repo + "/.dragon/CONTEXT.md"
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    Component.onCompleted: Mem.addProject(repo, "Proyecto", "AX", r => {
        if (!r.ok) return fail("project " + JSON.stringify(r));
        slug = r.project.slug;
        Mem.call(["card", "add", "--project", slug, "--title", "Filtros de busqueda"], c => { key = c.card.key; phase = 1; });
    })
    Connections { target: Mem; function onExportsChanged() { root_calls(); } }
    function root_calls() { calls++; }
    Timer { interval: 60; running: true; repeat: true
        onTriggered: {
            if (phase === 1 && Mem.project) {
                if (Mem.exports[slug]) return fail("nothing exported before a card change");
                // A burst of changes collapses into one export.
                Mem.moveCard(key, "doing", false, null);
                Mem.addCriterion(key, "Filtra por fecha");
                phase = 2;
            } else if (phase === 2 && Mem.exports[slug] && calls >= 1) {
                phase = 3;
                const e = Mem.exports[slug];
                if (!e.path.endsWith("/repo/.dragon/CONTEXT.md") || e.bytes <= 0 || e.bytes >= 4096) return fail("export " + JSON.stringify(e));
                Mem.setCard(key, { title: "Filtros por fecha" }, null);
            } else if (phase === 3 && calls >= 2) {
                console.log("CALLS", calls); console.log("AUTOEXPORT_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 20000; running: true; onTriggered: fail("timeout") }
}
'''


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class AutoExport(unittest.TestCase):
    def test_card_changes_export_context(self):
        def collect(home):
            path = home / 'repo/.dragon/CONTEXT.md'
            return {'text': path.read_text(), 'mode': path.stat().st_mode & 0o777} if path.exists() else None
        out, data = run_shell(SHELL, setup=lambda home, env: git_repo(home, env), collect=collect)
        self.assertIn('AUTOEXPORT_OK', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)
        self.assertIn('CALLS 2', out, 'move + criterion must collapse into one export, then the rename makes a second')
        got = data['collected']
        self.assertIsNotNone(got, 'CONTEXT.md was not written')
        self.assertEqual(got['mode'], 0o600)
        self.assertIn('Filtros por fecha', got['text'])      # the last change (rename) is in the file
        self.assertIn('Filtra por fecha', got['text'])       # the criterion of the current card too
        self.assertLess(len(got['text'].encode()), 4096)


if __name__ == '__main__':
    unittest.main()
