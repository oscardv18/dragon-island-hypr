"""Ajustes › Taller with real Quickshell, real dragon-mem and an isolated HOME: thresholds and prompt history in
settings.json (Prompts follows them), WIP / test command through `project set`, CONTEXT.md export, attributed sends
and the Taller page inside the real SettingsPanel."""
import json
import shutil
import unittest
from helpers import run_shell, git_repo, BAD

SHELL = '''import Quickshell
import QtQuick
import "services"
ShellRoot {
    property int phase: 0
    property string slug: ""
    property string key: ""
    readonly property string repo: Quickshell.env("HOME") + "/repo"
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    Component.onCompleted: Mem.addProject(repo, "Proyecto", "AX", r => {
        if (!r.ok) return fail("project " + JSON.stringify(r));
        slug = r.project.slug;
        Mem.call(["card", "add", "--project", slug, "--title", "Filtros"], c => { key = c.card.key; phase = 1; });
    })
    Timer { interval: 80; running: true; repeat: true
        onTriggered: {
            if (phase === 1) {
                if (Prompts.warnAt !== 1500 || Prompts.highAt !== 3000 || Settings.promptHistory) return fail("defaults");
                Settings.setTokenThresholds(2000, 1000);   // high below warn: kept above it
                Settings.setFlag("promptHistory", true);
                phase = 2;
            } else if (phase === 2) {
                if (Prompts.warnAt !== 2000 || Prompts.highAt !== 2250) return fail("thresholds " + Prompts.warnAt + " " + Prompts.highAt);
                if (Prompts.levelFor(2100) !== "medio" || Prompts.colorLevel(2300) !== "high") return fail("levels");
                phase = 3;
                Mem.setProject(slug, { wip_limit: 0 }, r => {
                    if (r.ok || Mem.status !== "ok") return fail("invalid WIP must fail quietly " + JSON.stringify(r) + Mem.status);
                    Mem.setProject(slug, { wip_limit: 5, test_cmd: "pytest -q" }, s => {
                        if (!s.ok || Mem.project?.wip_limit !== 5 || Mem.project?.test_cmd !== "pytest -q") return fail("set " + JSON.stringify(s));
                        Mem.exportContext(slug, e => {
                            if (!e.ok || !e.path.endsWith("/repo/.dragon/CONTEXT.md") || e.bytes >= 4096) return fail("export " + JSON.stringify(e));
                            Prompts.open({ card: key }); phase = 4;
                        });
                    });
                });
            } else if (phase === 4 && !Prompts.building && Prompts.result.tokens > 0) {
                Prompts.send(); phase = 5;
            } else if (phase === 5 && !Prompts.composerOpen) {
                console.log("SETTINGS_OK"); Qt.quit();
            }
        }
    }
    Timer { interval: 20000; running: true; onTriggered: fail("timeout") }
}
'''

PANEL = '''import Quickshell
import QtQuick
import "services"
import "modules/settings"
ShellRoot {
    property int phase: 0
    function fail(msg) { console.error("FAIL", phase, msg); Qt.quit(); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const c of item.children) { const f = find(c, name); if (f) return f; }
        return null;
    }
    Component.onCompleted: Mem.call(["project", "add", "--path", Quickshell.env("HOME") + "/repo", "--name", "Proyecto", "--prefix", "AX", "--test-cmd", "make test"], r => { phase = r.ok ? 1 : -1; })
    FloatingWindow {
        implicitWidth: 1000; implicitHeight: 700
        SettingsPanel { id: panel; anchors.fill: parent; shown: true; page: "bar" }
    }
    Timer { interval: 80; running: true; repeat: true
        onTriggered: {
            if (phase === -1) return fail("project add");
            if (phase === 1) {
                if (Mem.projects.length) return fail("dragon-mem must not be read before the Taller page is shown");
                panel.page = "taller"; phase = 2;
            } else if (phase === 2 && Mem.project) {
                if (!panel.pages.some(p => p.key === "taller")) return fail("nav");
                console.log("PANEL_OK", Mem.project.test_cmd, Mem.project.wip_limit); Qt.quit();
            }
        }
    }
    Timer { interval: 15000; running: true; onTriggered: fail("timeout") }
}
'''


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class TallerSettings(unittest.TestCase):
    def test_settings_mem_and_prompts(self):
        def collect(home):
            context = home / 'repo/.dragon/CONTEXT.md'
            return {'settings': (home / 'config/dragon-island/settings.json').read_text(),
                    'context': context.read_text(), 'mode': context.stat().st_mode & 0o777}
        out, data = run_shell(SHELL, setup=lambda home, env: git_repo(home, env), collect=collect)
        self.assertIn('SETTINGS_OK', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)
        saved = json.loads(data['collected']['settings'])
        self.assertEqual((saved['tokenWarnAt'], saved['tokenHighAt'], saved['promptHistory']), (2000, 2250, True))
        self.assertIn('generado por dragon-mem', data['collected']['context'])
        self.assertEqual(data['collected']['mode'], 0o600)
        sent = [json.loads(l) for l in data['sent'].splitlines()]
        self.assertEqual(len(sent), 1)
        args = sent[0]['args']
        self.assertEqual(args[args.index('--project') + 1], 'repo')
        self.assertEqual(args[args.index('--card') + 1], 'AX-1')
        self.assertEqual(args[args.index('--template') + 1], 'implementar-tarjeta')

    def test_page_in_the_real_panel(self):
        extra = 'singleton Glass 1.0 Glass.qml\nsingleton WallPalette 1.0 WallPalette.qml\n'
        out, _ = run_shell(PANEL, extra_qmldir=extra, setup=lambda home, env: git_repo(home, env))
        self.assertIn('PANEL_OK make test 3', out, out)
        for bad in BAD: self.assertNotIn(bad, out, out)


if __name__ == '__main__':
    unittest.main()
