"""Explorer UI (tramo 5d): pure views over the fixtures, and the real QML services over a fake dragon-files.
No real folders, no real HOME, no desktop input."""
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]
FIX = ROOT / 'tests/qml/fixtures'


def isolated_env(tmp):
    work = Path(tmp)
    (work / 'runtime').mkdir(mode=0o700, exist_ok=True)
    env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(work / 'runtime'), QT_QPA_PLATFORM='offscreen',
               QT_FORCE_STDERR_LOGGING='1', TZ='UTC', PYTHONDONTWRITEBYTECODE='1')
    env.pop('QT_QPA_PLATFORMTHEME', None)
    for n in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
        env[f'XDG_{n}_HOME'] = str(work / n.lower())
    return env


def png_size(path):
    raw = Path(path).read_bytes()
    return struct.unpack('>II', raw[16:24])


@unittest.skipUnless(shutil.which('qml6'), 'qml6 required')
class Views(unittest.TestCase):
    def test_mock_renders_and_checks_pass(self):
        with tempfile.TemporaryDirectory(prefix='files-view-') as tmp:
            work = Path(tmp)
            cfg = work / 'config/quickshell'
            shutil.copytree(ROOT / 'config/quickshell', cfg)
            tests = work / 'tests/qml'
            tests.mkdir(parents=True)
            shutil.copy(ROOT / 'tests/qml/files_mock.qml', tests)
            shutil.copytree(FIX, tests / 'fixtures')
            (work / 'sddm/dragon-core').mkdir(parents=True)
            shutil.copy(ROOT / 'sddm/dragon-core/background.jpg', work / 'sddm/dragon-core')
            for name in ('Theme', 'Icons'):
                p = cfg / (name + '.qml')
                p.write_text(p.read_text().replace('import Quickshell\n', '').replace('Singleton {', 'QtObject {'))
            (cfg / 'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Icons 1.0 Icons.qml\n')
            env = isolated_env(tmp)
            env['QML_XHR_ALLOW_FILE_READ'] = '1'
            out = work / 'out'
            out.mkdir()
            r = subprocess.run(['qml6', str(tests / 'files_mock.qml'), '--', str(out)], env=env,
                               capture_output=True, text=True, timeout=60)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            for bad in ('Error:', 'ReferenceError', 'TypeError', 'files_mock:'):
                self.assertNotIn(bad, r.stderr, r.stderr)
            for name in sorted(p.name for p in out.glob('files-*.png')):
                self.assertEqual(png_size(out / name), (1226, 612), name)
            self.assertTrue((out / 'files-lista.png').exists())
            self.assertTrue((out / 'files-cuadricula.png').exists())


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class Services(unittest.TestCase):
    """Real services/Files*.qml in Quickshell, talking to tests/files_ui/fake_dragon_files.py."""

    def run_shell(self, body, timeout=12):
        tmp = tempfile.mkdtemp(prefix='files-svc-')
        self.addCleanup(shutil.rmtree, tmp, True)
        home = Path(tmp)
        cfg = home / 'shell'
        shutil.copytree(ROOT / 'config/quickshell', cfg)
        bindir = home / '.local/bin'
        bindir.mkdir(parents=True)
        (bindir / 'dragon-files').symlink_to(ROOT / 'tests/files_ui/fake_dragon_files.py')
        log = home / 'calls.log'
        log.touch()
        env = isolated_env(tmp)
        env.update(FAKE_FILES_FIXTURES=str(FIX), FAKE_FILES_LOG=str(log))
        (cfg / 'shell.qml').write_text('import Quickshell\nimport QtQuick\nimport "services"\nimport "modules/files"\n'
                                       'ShellRoot {\n' + body + '\n'
                                       '    Timer { interval: %d; running: true; onTriggered: { console.error("SVC_TIMEOUT"); Qt.quit(); } }\n}\n'
                                       % ((timeout - 3) * 1000))
        r = subprocess.run(['qs', '-p', str(cfg)], env=env, capture_output=True, text=True, timeout=timeout)
        calls = [json.loads(line) for line in log.read_text().splitlines() if line]
        return r, calls

    def test_list_git_pass_and_watch_lifecycle(self):
        r, calls = self.run_shell('''
    property int phase: 0
    property string docs: Quickshell.env("HOME") + "/Proyectos/arxnet-erp/docs"
    Component.onCompleted: Files.list(docs, { hidden: true }, res => {
        if (!res.ok || res.entries.length !== 13 || res.free !== 499289948160) throw new Error("bad ls " + JSON.stringify(res).slice(0, 200));
        Files.list(docs, { hidden: true, git: true }, g => {
            if (g.entries.find(e => e.name === "arquitectura.md").git !== "M") throw new Error("git mark missing");
            Files.acquireWatch(docs); Files.acquireWatch(docs);
        });
    })
    Connections {
        target: Files
        function onFolderChanged(p) {
            if (p !== docs) throw new Error("wrong folder " + p);
            Files.releaseWatch(docs);
            if (Object.keys(Files._watchers).length !== 1) throw new Error("released too early");
            Files.releaseWatch(docs);
            if (Object.keys(Files._watchers).length !== 0) throw new Error("watch not released");
            console.log("SVC_OK"); Qt.quit();
        }
    }''')
        self.assertIn('SVC_OK', r.stdout + r.stderr, r.stderr[-3000:])
        self.assertIn(['ls', str(Path(calls[0][1])), '--sort', 'name', '--dirs-first', '--hidden', '--json'], calls)
        self.assertTrue(any('--git' in c for c in calls if c[0] == 'ls'))
        self.assertEqual(sum(1 for c in calls if c[0] == 'watch'), 1, 'one watcher per folder, shared by two users')

    def test_window_lists_watches_and_releases_on_close(self):
        r, calls = self.run_shell('''
    property var win: null
    Variants { model: Files.windows; delegate: Component { FilesWindow {} } }
    Component.onCompleted: Files.openWindow(Quickshell.env("HOME") + "/Proyectos/arxnet-erp/docs")
    Timer {
        interval: 100; running: true; repeat: true
        property bool closing: false
        onTriggered: {
            if (!closing && Object.keys(Files._watchers).length === 1 && Files.places.length === 7 && Files.visibleWindows === 1) {
                closing = true; Files.closeWindow(Files.windows[0].uid);
            } else if (closing && Files.windows.length === 0 && Object.keys(Files._watchers).length === 0 && Files.visibleWindows === 0) {
                console.log("SVC_OK"); Qt.quit();
            }
        }
    }''')
        self.assertIn('SVC_OK', r.stdout + r.stderr, r.stderr[-3000:])
        self.assertIn('places', [c[0] for c in calls])

    def test_tool_errors_reach_the_callback(self):
        r, _ = self.run_shell('''
    Component.onCompleted: {
        Files.call(["definitely-not-simulated"], res => {
            if (res.ok || res.error.code !== "unsupported") throw new Error("expected error object");
            console.log("SVC_OK"); Qt.quit();
        });
    }''')
        self.assertIn('SVC_OK', r.stdout + r.stderr, r.stderr[-3000:])


if __name__ == '__main__':
    unittest.main()
