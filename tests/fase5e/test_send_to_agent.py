"""«Enviar al agente» from the explorer: Files.sendToAgent opens the real composer with a `paths` block, on the
clipboard target, and sends nothing by itself. Real Quickshell services; fake dragon-prompt records any send."""
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'fase5c'))
from helpers import run_shell, git_repo, BAD  # noqa: E402

EXTRA = '''singleton Files 1.0 Files.qml
FilesRequest 1.0 FilesRequest.qml
singleton Taller 1.0 Taller.qml
singleton Git 1.0 Git.qml
singleton Docker 1.0 Docker.qml
'''

SHELL = '''import Quickshell
import QtQuick
import "services"
ShellRoot {
    property int phase: 0
    property var requested: null
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    Connections { target: Files; function onAgentRequested(paths) { requested = paths; } }
    Component.onCompleted: Mem.addProject(Quickshell.env("HOME") + "/repo", "Proyecto", "AX", r => {
        if (!r.ok) return fail("project");
        if (!Files.composerAvailable) return fail("composer must be available");
        Files.sendToAgent([]);
        if (Prompts.composerOpen) return fail("no paths, no composer");
        Files.sendToAgent(["/home/u/Proyecto/a b.txt", "/home/u/Proyecto/src"]);
        phase = 1;
    })
    Timer { interval: 60; running: true; repeat: true
        onTriggered: {
            if (phase === 1 && Prompts.composerOpen && !Prompts.building && Prompts.result.blocks.length) {
                const b = Prompts.result.blocks.find(x => x.type === "paths");
                if (!b) return fail("no paths block " + JSON.stringify(Prompts.result.blocks));
                if (Prompts.target !== "clipboard") return fail("target " + Prompts.target);
                if (!Prompts.result.text.includes("/home/u/Proyecto/a b.txt") || !Prompts.result.text.includes("/home/u/Proyecto/src"))
                    return fail("text " + Prompts.result.text);
                if (!requested || requested.length !== 2) return fail("signal");
                if (ShellState.openPanel !== "taller") return fail("panel " + ShellState.openPanel);
                console.log("AGENT_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 20000; running: true; onTriggered: fail("timeout") }
}
'''


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class SendToAgent(unittest.TestCase):
    def test_paths_block_on_clipboard_nothing_sent(self):
        out, data = run_shell(SHELL, extra_qmldir=EXTRA, setup=lambda home, env: git_repo(home, env))
        self.assertIn('AGENT_OK', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)
        self.assertEqual(data['sent'], '', 'nothing may be sent before «Enviar»')


if __name__ == '__main__':
    unittest.main()
