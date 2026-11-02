"""Migrations 100 / 101 / 102 and scripts/portal-rollback.sh in a temporary HOME: DRY_RUN leaves no trace (1 and true), backups,
idempotence, repo links untouched, and the safety guard of 102 (a backend that does not start is never registered)."""
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GTK_PORTAL = Path('/usr/share/xdg-desktop-portal/portals/gtk.portal')
CAN_SELFTEST = bool(shutil.which('dbus-run-session') and shutil.which('busctl') and GTK_PORTAL.exists()) and subprocess.run(
    ['python3', '-c', 'import gi'], capture_output=True).returncode == 0


class Home(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='dpm', dir='/tmp')
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.home = Path(self.tmp)
        self.config = self.home / 'config'
        (self.home / 'runtime').mkdir(mode=0o700)
        self.env = dict(os.environ, HOME=self.tmp, XDG_CONFIG_HOME=str(self.config), XDG_STATE_HOME=str(self.home / 'state'),
                        XDG_DATA_HOME=str(self.home / 'data'), XDG_CACHE_HOME=str(self.home / 'cache'),
                        XDG_RUNTIME_DIR=str(self.home / 'runtime'), BACKUP_DIR=str(self.home / 'backup'), ASSUME_YES='true',
                        LINK_MODE='symlink', PYTHONDONTWRITEBYTECODE='1')
        for key in ('PORTAL_PYTHON',):
            self.env.pop(key, None)

    def snapshot(self):
        out = {}
        for p in sorted(self.home.rglob('*')):
            rel = str(p.relative_to(self.home))
            out[rel] = ('link', os.readlink(p)) if p.is_symlink() else (p.read_bytes() if p.is_file() else None)
        return out

    def run_script(self, name, *args, **extra):
        env = dict(self.env, **extra)
        return subprocess.run(['bash', str(ROOT / name), *args], env=env, capture_output=True, text=True, timeout=90)

    def dry_runs_leave_nothing(self, name):
        before = self.snapshot()
        for dry in ('1', 'true'):
            r = self.run_script(name, DRY_RUN=dry)
            self.assertIn(r.returncode, (0, 10), r.stderr)
            self.assertEqual(before, self.snapshot(), 'DRY_RUN=%s changed something' % dry)

    @property
    def portal_file(self):
        return self.home / 'data/xdg-desktop-portal/portals/dragon.portal'

    @property
    def service_file(self):
        return self.home / 'data/dbus-1/services/org.freedesktop.impl.portal.desktop.dragon.service'


class Tools(Home):
    def test_100_dry_run_apply_and_idempotence(self):
        self.dry_runs_leave_nothing('migrations/100-portal-tools.sh')
        r = self.run_script('migrations/100-portal-tools.sh', DRY_RUN='false')
        self.assertEqual(r.returncode, 0, r.stderr)
        engines = self.home / 'data/dragon-island/engines'
        for name in ('portal_core.py', 'dragon_portal.py'):
            self.assertEqual(os.path.realpath(engines / name), str(ROOT / 'dragon-core' / name))
        self.assertTrue(os.access(self.home / '.local/bin/dragon-portal', os.X_OK))
        before = self.snapshot()
        self.assertEqual(self.run_script('migrations/100-portal-tools.sh', DRY_RUN='false').returncode, 0)
        self.assertEqual(before, self.snapshot())

    def test_100_copy_mode_installs_a_working_cli(self):
        r = self.run_script('migrations/100-portal-tools.sh', LINK_MODE='copy', DRY_RUN='false')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse((self.home / '.local/bin/dragon-portal').is_symlink())
        done = subprocess.run([str(self.home / '.local/bin/dragon-portal'), 'status'], env=self.env, capture_output=True, text=True)
        self.assertIn('"ok":true', done.stdout)                     # runs from the copied engine files, not from the repo


class Ui(Home):
    def test_101_copy_backup_idempotence_and_links(self):
        (self.config / 'quickshell/modules/files').mkdir(parents=True)
        (self.config / 'quickshell/shell.qml').write_text('// old')
        self.dry_runs_leave_nothing('migrations/101-portal-ui.sh')
        r = self.run_script('migrations/101-portal-ui.sh', DRY_RUN='false')
        self.assertEqual(r.returncode, 0, r.stderr)
        for rel in ('shell.qml', 'services/FilePicker.qml', 'services/PortalRequest.qml', 'modules/files/PickerBar.qml', 'modules/files/files.js'):
            self.assertEqual((self.config / 'quickshell' / rel).read_bytes(), (ROOT / 'config/quickshell' / rel).read_bytes(), rel)
        self.assertEqual((self.home / 'backup/config/quickshell/shell.qml').read_text(), '// old')
        before = self.snapshot()
        self.assertEqual(self.run_script('migrations/101-portal-ui.sh', DRY_RUN='false').returncode, 10)
        self.assertEqual(before, self.snapshot())

    def test_101_repo_link_is_not_replaced(self):
        self.config.mkdir()
        (self.config / 'quickshell').symlink_to(ROOT / 'config/quickshell', target_is_directory=True)
        r = self.run_script('migrations/101-portal-ui.sh', DRY_RUN='false')
        self.assertEqual(r.returncode, 10, r.stderr)
        self.assertEqual(os.readlink(self.config / 'quickshell'), str(ROOT / 'config/quickshell'))


@unittest.skipUnless(CAN_SELFTEST, 'needs dbus-run-session, busctl, PyGObject and xdg-desktop-portal-gtk')
class Enable(Home):
    def prepare(self, conf=None):
        self.assertEqual(self.run_script('migrations/100-portal-tools.sh', DRY_RUN='false').returncode, 0)
        (self.config / 'quickshell/services').mkdir(parents=True)
        (self.config / 'quickshell/services/FilePicker.qml').write_text('// ui')
        if conf is not None:
            (self.config / 'xdg-desktop-portal').mkdir(parents=True)
            (self.config / 'xdg-desktop-portal/hyprland-portals.conf').write_text(conf)

    def test_dry_run_leaves_no_trace(self):
        self.prepare('[preferred]\ndefault=hyprland;gtk\n')
        self.dry_runs_leave_nothing('migrations/102-portal-enable.sh')

    def test_registers_backs_up_and_is_idempotent(self):
        old = '[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.Secret=gnome-keyring\n'
        self.prepare(old)
        r = self.run_script('migrations/102-portal-enable.sh', DRY_RUN='false')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.portal_file.read_text(), (ROOT / 'config/portal/dragon.portal').read_text())
        self.assertEqual(self.service_file.read_text(),
                         '[D-BUS Service]\nName=org.freedesktop.impl.portal.desktop.dragon\nExec=%s/.local/bin/dragon-portal serve\n' % self.tmp)
        conf = (self.config / 'xdg-desktop-portal/hyprland-portals.conf').read_text()
        self.assertEqual(conf.count('org.freedesktop.impl.portal.FileChooser=dragon;gtk'), 1)
        self.assertIn('Secret=gnome-keyring', conf)
        self.assertEqual((self.home / 'backup/config/xdg-desktop-portal/hyprland-portals.conf').read_text(), old)
        self.assertIn('Dragon Portal', (self.home / 'state/dragon-island/needs-relogin').read_text())
        before = self.snapshot()
        r = self.run_script('migrations/102-portal-enable.sh', DRY_RUN='false')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(before, self.snapshot(), 'the second run changed something')

    def test_conf_that_links_to_the_repo_is_not_written(self):
        self.prepare()
        (self.config / 'xdg-desktop-portal').mkdir(parents=True)
        (self.config / 'xdg-desktop-portal/hyprland-portals.conf').symlink_to(ROOT / 'config/xdg-desktop-portal/hyprland-portals.conf')
        repo_before = (ROOT / 'config/xdg-desktop-portal/hyprland-portals.conf').read_bytes()
        self.assertEqual(self.run_script('migrations/102-portal-enable.sh', DRY_RUN='false').returncode, 0)
        self.assertEqual((ROOT / 'config/xdg-desktop-portal/hyprland-portals.conf').read_bytes(), repo_before)
        self.assertTrue(self.portal_file.exists())

    def test_existing_choice_of_the_user_is_kept(self):
        self.prepare('[preferred]\norg.freedesktop.impl.portal.FileChooser=gtk\n')
        self.assertEqual(self.run_script('migrations/102-portal-enable.sh', DRY_RUN='false').returncode, 0)
        self.assertIn('FileChooser=gtk\n', (self.config / 'xdg-desktop-portal/hyprland-portals.conf').read_text())
        self.assertNotIn('dragon;gtk', (self.config / 'xdg-desktop-portal/hyprland-portals.conf').read_text())

    def test_nothing_is_registered_when_the_service_does_not_start(self):
        self.prepare('[preferred]\ndefault=hyprland;gtk\n')
        bin_ = self.home / '.local/bin/dragon-portal'
        bin_.unlink()
        bin_.write_text('#!/bin/sh\nexit 1\n')
        bin_.chmod(0o755)
        before = self.snapshot()
        r = self.run_script('migrations/102-portal-enable.sh', DRY_RUN='false')
        self.assertEqual(r.returncode, 10, r.stdout + r.stderr)
        quiet = lambda snap: {k: v for k, v in snap.items() if not k.startswith(('state', 'runtime'))}      # logs and the bus's own files
        self.assertEqual(quiet(before), quiet(self.snapshot()))
        self.assertFalse(self.portal_file.exists() or self.service_file.exists())

    def test_nothing_is_registered_without_pygobject(self):
        self.prepare()
        r = self.run_script('migrations/102-portal-enable.sh', DRY_RUN='false', PORTAL_PYTHON='/bin/false')
        self.assertEqual(r.returncode, 10)
        self.assertIn('python-gobject', r.stdout + r.stderr)
        self.assertFalse(self.portal_file.exists())

    def test_waits_for_the_ui(self):
        self.prepare()
        (self.config / 'quickshell/services/FilePicker.qml').unlink()
        self.assertEqual(self.run_script('migrations/102-portal-enable.sh', DRY_RUN='false').returncode, 10)
        self.assertFalse(self.portal_file.exists())

    def test_rollback_removes_only_the_registration(self):
        self.prepare('[preferred]\ndefault=hyprland;gtk\n')
        self.run_script('migrations/102-portal-enable.sh', DRY_RUN='false')
        keep = (self.config / 'xdg-desktop-portal/hyprland-portals.conf').read_bytes()
        before = self.snapshot()
        for dry in ('--dry-run',):
            self.assertEqual(self.run_script('scripts/portal-rollback.sh', dry).returncode, 0)
            self.assertEqual(before, self.snapshot())
        r = self.run_script('scripts/portal-rollback.sh')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.portal_file.exists() or self.service_file.exists())
        self.assertEqual((self.config / 'xdg-desktop-portal/hyprland-portals.conf').read_bytes(), keep)
        self.assertEqual(self.run_script('scripts/portal-rollback.sh').returncode, 0)       # idempotent


if __name__ == '__main__':
    unittest.main()
