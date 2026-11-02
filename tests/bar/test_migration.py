import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from fixture_shell import ROOT


class Migration(unittest.TestCase):
    def test_copied_install_backups_dry_run_and_idempotence(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cfg = home / 'config/quickshell'
            shutil.copytree(ROOT / 'config/quickshell', cfg)
            files = ['Theme.qml', 'modules/bar/RightIsland.qml']
            for name in files:
                (cfg / name).write_text('old ' + name)
            (cfg / 'modules/bar/NotificationBell.qml').unlink()
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=str(home / 'config'),
                       XDG_STATE_HOME=str(home / 'state'), XDG_DATA_HOME=str(home / 'data'),
                       BACKUP_DIR=str(home / 'backup'), ASSUME_YES='1')
            command = ['bash', str(ROOT / 'migrations/130-notification-bell.sh')]
            def snapshot():
                return {str(p.relative_to(home)): (p.lstat().st_mtime_ns, p.read_bytes())
                        for p in home.rglob('*') if p.is_file()}
            before = snapshot()
            for dry in ('1', 'true'):
                result = subprocess.run(command, env=dict(env, DRY_RUN=dry), capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(snapshot(), before)
                self.assertFalse((home / 'state').exists())
            subprocess.run(command, env=env, check=True, capture_output=True)
            for name in files:
                self.assertEqual((home / 'backup/config/quickshell' / name).read_text(), 'old ' + name)
            for name in files + ['modules/bar/NotificationBell.qml']:
                self.assertEqual((cfg / name).read_bytes(), (ROOT / 'config/quickshell' / name).read_bytes())
            after = snapshot()
            self.assertEqual(subprocess.run(command, env=env, capture_output=True).returncode, 10)
            self.assertEqual(snapshot(), after)

    def test_linked_bar_directory_is_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cfg = home / 'config/quickshell'
            (cfg / 'modules').mkdir(parents=True)
            external = home / 'external-bar'
            external.mkdir()
            (external / 'RightIsland.qml').write_text('linked content')
            (cfg / 'modules/bar').symlink_to(external)
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=str(home / 'config'),
                       XDG_STATE_HOME=str(home / 'state'))
            result = subprocess.run(['bash', str(ROOT / 'migrations/130-notification-bell.sh')], env=env, capture_output=True)
            self.assertEqual(result.returncode, 0)
            self.assertTrue((cfg / 'modules/bar').is_symlink())
            self.assertEqual((external / 'RightIsland.qml').read_text(), 'linked content')
            self.assertFalse((external / 'NotificationBell.qml').exists())

    def test_linked_install_is_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / 'config').mkdir()
            cfg = home / 'config/quickshell'
            cfg.symlink_to(ROOT / 'config/quickshell')
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=str(home / 'config'), XDG_STATE_HOME=str(home / 'state'))
            result = subprocess.run(['bash', str(ROOT / 'migrations/130-notification-bell.sh')], env=env, capture_output=True)
            self.assertEqual(result.returncode, 10)
            self.assertTrue(cfg.is_symlink())
