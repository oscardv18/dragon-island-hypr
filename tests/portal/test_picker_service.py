"""The real FilePicker service in Quickshell (qs ipc) with the real `dragon-portal take/reply` CLI and a fake dragon-files:
IPC open → window in selector mode → answer reaches the private reply file; closing the window = cancel; `has` / `cancel` IPC.
Offscreen, HOME/XDG temporary, no portal service involved (tests/portal/test_portal.py covers that side)."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dragon-core'))
import portal_core as core  # noqa: E402

SHELL = '''import Quickshell
import Quickshell.Io
import QtQuick
import "services"
import "modules/files"
ShellRoot {
    id: root
    property var panels: ({})
    Variants {
        model: Files.windows
        delegate: Component { FilesWindow {
            id: w
            Component.onCompleted: Qt.callLater(() => { for (const c of w.contentItem.children) if (c.acceptPick) root.panels[w.modelData.uid] = c; })
        } }
    }
    Component.onCompleted: FilePicker.init()
    function panelOf(id) { return root.panels[FilePicker._uidOf[id]] ?? null; }
    IpcHandler {
        target: "test"
        function ready(id: string): bool { const p = root.panelOf(id); return !!p && p.tab?.status === "ok"; }
        function pick(id: string, name: string): string { const p = root.panelOf(id); p.tab.selectNames([name]); p.acceptPick(); return "ok"; }
        function typeName(id: string, name: string): string { const p = root.panelOf(id); p.state.pickName = name; p.acceptPick(); return "ok"; }
        function cancelUi(id: string): string { root.panelOf(id).cancelPick(); return "ok"; }
        function destroyWindow(id: string): string { Files.closeWindow(FilePicker._uidOf[id]); return "ok"; }
        function windows(): int { return Files.windows.length; }
        function title(id: string): string { return root.panelOf(id).picker.title; }
    }
}
'''


@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class PickerService(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='pk-svc-')
        self.addCleanup(shutil.rmtree, self.tmp, True)
        home = Path(self.tmp)
        self.cfg = home / 'shell'
        shutil.copytree(ROOT / 'config/quickshell', self.cfg)
        (self.cfg / 'shell.qml').write_text(SHELL)
        bindir = home / '.local/bin'
        bindir.mkdir(parents=True)
        (bindir / 'dragon-files').symlink_to(ROOT / 'tests/files_ui/fake_dragon_files.py')
        (bindir / 'dragon-portal').symlink_to(ROOT / 'bin/dragon-portal')
        (home / 'runtime').mkdir(mode=0o700)
        self.env = dict(os.environ, HOME=self.tmp, XDG_RUNTIME_DIR=str(home / 'runtime'), QT_QPA_PLATFORM='offscreen',
                        QT_FORCE_STDERR_LOGGING='1', TZ='UTC', PYTHONDONTWRITEBYTECODE='1',
                        FAKE_FILES_FIXTURES=str(ROOT / 'tests/qml/fixtures'), FAKE_FILES_LOG=str(home / 'calls.log'))
        for n in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
            self.env[f'XDG_{n}_HOME'] = str(home / n.lower())
        self.docs = self.tmp + '/Proyectos/arxnet-erp/docs'
        os.environ['XDG_RUNTIME_DIR'] = self.env['XDG_RUNTIME_DIR']     # for portal_core in this process
        self.qs = subprocess.Popen(['qs', '-p', str(self.cfg)], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.addCleanup(self.stop)
        self.wait(lambda: self.ipc('test', 'windows') == '0', 'quickshell did not start')

    def stop(self):
        self.qs.terminate()
        try:
            self.qs.wait(10)
        except subprocess.TimeoutExpired:
            self.qs.kill()
        self.qs.stdout.close()

    def ipc(self, target, fn, *args):
        r = subprocess.run(['qs', 'ipc', '-p', str(self.cfg), 'call', target, fn, *args], env=self.env, capture_output=True, text=True, timeout=15)
        return r.stdout.strip() if r.returncode == 0 else None

    def wait(self, cond, what, seconds=20):
        end = time.time() + seconds
        while time.time() < end:
            try:
                if cond():
                    return
            except Exception:
                pass
            time.sleep(0.2)
        self.fail(what + '\n' + self.log())

    def log(self):
        self.qs.poll()
        return 'qs exited %s' % self.qs.returncode if self.qs.returncode is not None else '(qs running)'

    def request(self, **opts):
        req = core.build_request(opts.pop('kind', 'open'), 'org.test', opts.pop('title', 'Elige'), opts.pop('options', {}), self.docs)
        req['current_folder'] = self.docs
        req.update(opts)
        core.write_private_json(core.channel('req'), req['id'] + '.json', req)
        return req

    def reply(self, rid):
        self.wait(lambda: core.read_private_json(core.channel('rep'), rid + '.json') is not None, 'no reply for ' + rid)
        return core.read_private_json(core.channel('rep'), rid + '.json')

    def open_dialog(self, req):
        self.assertIsNotNone(self.ipc('picker', 'open', req['id']))
        self.wait(lambda: self.ipc('test', 'ready', req['id']) == 'true', 'dialog not ready')

    def test_accept_reaches_the_private_reply_file(self):
        req = self.request(title='Adjuntar')
        self.open_dialog(req)
        self.assertEqual(self.ipc('test', 'title', req['id']), 'Adjuntar')
        self.assertEqual(self.ipc('picker', 'has', req['id']), 'true')
        self.assertTrue((Path(self.env['XDG_RUNTIME_DIR']) / 'dragon-portal/req' / (req['id'] + '.taken')).exists())
        self.ipc('test', 'pick', req['id'], 'dump.sql')
        reply = self.reply(req['id'])
        self.assertEqual((reply['response'], reply['paths']), ('accept', [self.docs + '/dump.sql']))
        self.wait(lambda: self.ipc('test', 'windows') == '0', 'the window stays open after answering')
        self.assertEqual(self.ipc('picker', 'has', req['id']), 'false')
        self.assertEqual(oct((Path(self.env['XDG_RUNTIME_DIR']) / 'dragon-portal/rep' / (req['id'] + '.json')).stat().st_mode & 0o777), '0o600')

    def test_cancel_button_and_closing_the_window(self):
        a = self.request()
        self.open_dialog(a)
        self.ipc('test', 'cancelUi', a['id'])
        self.assertEqual(self.reply(a['id'])['response'], 'cancel')
        b = self.request()
        self.open_dialog(b)
        self.ipc('test', 'destroyWindow', b['id'])                      # the window goes away without an answer
        self.assertEqual(self.reply(b['id'])['response'], 'cancel')

    def test_portal_cancel_closes_silently(self):
        req = self.request()
        self.open_dialog(req)
        self.ipc('picker', 'cancel', req['id'])
        self.wait(lambda: self.ipc('test', 'windows') == '0', 'window not closed by picker.cancel')
        time.sleep(0.5)
        self.assertIsNone(core.read_private_json(core.channel('rep'), req['id'] + '.json'))     # nobody is waiting: no reply

    def test_unknown_or_repeated_requests_do_not_open_windows(self):
        self.ipc('picker', 'open', 'f' * 32)
        self.ipc('picker', 'open', 'not-an-id')
        time.sleep(1)
        self.assertEqual(self.ipc('test', 'windows'), '0')
        req = self.request()
        self.open_dialog(req)
        self.ipc('picker', 'open', req['id'])
        time.sleep(1)
        self.assertEqual(self.ipc('test', 'windows'), '1')
        self.ipc('test', 'cancelUi', req['id'])

    def test_several_dialogs_at_once_answer_their_own_request(self):
        a, b = self.request(title='A'), self.request(title='B')
        self.open_dialog(a)
        self.open_dialog(b)
        self.assertEqual(self.ipc('test', 'windows'), '2')
        self.ipc('test', 'pick', b['id'], 'dump.sql')
        self.ipc('test', 'cancelUi', a['id'])
        self.assertEqual(self.reply(a['id'])['response'], 'cancel')
        self.assertEqual(self.reply(b['id'])['paths'], [self.docs + '/dump.sql'])

    def test_save_dialog_sends_folder_plus_typed_name(self):
        req = self.request(kind='save', title='Guardar', options={'current_name': 'x.txt'})
        self.open_dialog(req)
        self.ipc('test', 'typeName', req['id'], 'mi informe.txt')
        reply = self.reply(req['id'])
        self.assertEqual(reply['paths'], [self.docs + '/mi informe.txt'])


if __name__ == '__main__':
    unittest.main()
