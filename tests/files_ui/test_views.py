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

    def run_shell(self, body, timeout=12, **extra_env):
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
        env.update(FAKE_FILES_FIXTURES=str(FIX), FAKE_FILES_LOG=str(log), **extra_env)
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

    def test_queue_conflict_answer_and_undo(self):
        r, calls = self.run_shell('''
    property int step: 0
    Component.onCompleted: FileOps.move(["/h/a.txt", "/h/b.txt"], "/h/Docs")
    Connections {
        target: FileOps
        function onActiveChanged() {
            if (FileOps.active?.state === "conflict") FileOps.answer(FileOps.active.id, "rename", true);
        }
        function onFinished(op) {
            if (op.state !== "done") throw new Error("op failed " + JSON.stringify(op.error));
            step++;
            if (step === 1) {
                if (!FileOps.canUndo || FileOps.undoLabel !== "Deshacer mover a.txt y 1 más") throw new Error("undo label " + FileOps.undoLabel);
                FileOps.undo();
            } else if (step === 2) { console.log("SVC_OK"); Qt.quit(); }
        }
    }''', FAKE_CONFLICT='1')
        self.assertIn('SVC_OK', r.stdout + r.stderr, r.stderr[-3000:])
        ops = [c for c in calls if c[0] == 'op']
        self.assertEqual(ops[0], ['op', 'move', '/h/a.txt', '/h/b.txt', '--dest', '/h/Docs', '--conflict', 'ask', '--json-progress'])
        self.assertIn(['answer', {'answer': 'rename', 'all': True}], calls)
        self.assertEqual(ops[1][:5], ['op', 'move', '/h/Docs/a.txt', '/h/Docs/b.txt', '--dest'], 'undo moves back')
        self.assertEqual(ops[1][5], '/h')

    def test_cancel_terminates_and_quick_ops_do_not_wait(self):
        r, calls = self.run_shell('''
    property int copyId: 0
    Component.onCompleted: { copyId = FileOps.copy(["/h/big.iso"], "/media/usb") || 1; }
    Connections {
        target: FileOps
        function onFinished(op) {
            if (op.kind === "mkdir") {
                if (FileOps.active?.kind !== "copy" || FileOps.active.state !== "running") throw new Error("copy should still run");
                FileOps.cancel(FileOps.active.id);
            } else if (op.kind === "copy") {
                if (op.state !== "cancelled") throw new Error("expected cancelled, got " + op.state);
                console.log("SVC_OK"); Qt.quit();
            }
        }
        function onActiveChanged() { if (FileOps.active?.pct === 5 && !mk.done) { mk.done = true; FileOps.mkdir("/h", "nueva"); } }
    }
    QtObject { id: mk; property bool done: false }''', FAKE_SLOW='1')
        self.assertIn('SVC_OK', r.stdout + r.stderr, r.stderr[-3000:])
        self.assertIn(['op', 'mkdir', '/h', '--name', 'nueva', '--json-progress'], calls)

    def test_failed_operation_stays_visible(self):
        r, _ = self.run_shell('''
    Component.onCompleted: FileOps.copy(["/h/a"], "/full")
    Connections {
        target: FileOps
        function onFinished(op) {
            if (op.state !== "error" || FileOps.lastError?.error?.code !== "no_space") throw new Error("error lost");
            FileOps.dismissError();
            if (FileOps.lastError !== null || FileOps.queue.length !== 0) throw new Error("dismiss");
            console.log("SVC_OK"); Qt.quit();
        }
    }''', FAKE_FAIL='copy')
        self.assertIn('SVC_OK', r.stdout + r.stderr, r.stderr[-3000:])

    def test_devices_watch_only_with_windows_and_passphrase_by_stdin(self):
        r, calls = self.run_shell('''
    property int phase: 0
    Component.onCompleted: { if (Devices.watching) throw new Error("watching without windows"); Files.windowShown(true); }
    Connections {
        target: Devices
        function onDevicesChanged() {
            if (phase !== 0 || Devices.devices.length !== 4) return;
            if (Devices.devices.some(d => d.hidden)) throw new Error("hidden device shown");
            if (!Devices.watching) throw new Error("not watching with a window");
            phase = 1;
            Devices.unlock("sdb1", "mala", res => {
                if (res.ok || Devices.errors.sdb1 !== "Contraseña incorrecta") throw new Error("bad unlock not reported");
                Devices.unlock("sdb1", "correcta", ok => {
                    if (!ok.ok || Devices.errors.sdb1 !== undefined) throw new Error("unlock");
                    Files.windowShown(false);
                    if (Devices.watching) throw new Error("still watching without windows");
                    console.log("SVC_OK"); Qt.quit();
                });
            });
        }
    }''')
        self.assertIn('SVC_OK', r.stdout + r.stderr, r.stderr[-3000:])
        unlocks = [c for c in calls if c[0] == 'unlock']
        self.assertEqual(unlocks, [['unlock', 'sdb1', '--passphrase-stdin', '--json']] * 2)
        self.assertNotIn('correcta', json.dumps(calls).replace('"stdin"', ''))
        self.assertIn(['stdin', 8], calls)
        self.assertEqual(sum(1 for c in calls if c[:2] == ['devices', '--watch']), 1)

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
