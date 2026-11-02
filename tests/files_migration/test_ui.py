import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class MigrationUI(unittest.TestCase):
    def test_copy_dry_run_backup_and_idempotence(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config = home / 'config'
            (config / 'quickshell').mkdir(parents=True)
            (config / 'hypr').mkdir()
            old = config / 'quickshell/shell.qml'
            old.write_text('// old shell')
            rules = config / 'hypr/rules.lua'
            rules.write_text('-- old rules')
            env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=str(config),
                       XDG_STATE_HOME=str(home / 'state'), XDG_DATA_HOME=str(home / 'data'),
                       XDG_CACHE_HOME=str(home / 'cache'), XDG_RUNTIME_DIR=str(home / 'runtime'),
                       BACKUP_DIR=str(home / 'backup'), ASSUME_YES='true')
            def snapshot():
                return {str(p.relative_to(home)): (p.read_bytes() if p.is_file() else None)
                        for p in home.rglob('*')}
            def run(**extra):
                return subprocess.run(['bash', str(ROOT / 'migrations/080-files-ui.sh')],
                                      env=dict(env, **extra), capture_output=True, text=True)
            before = snapshot()
            for dry in ('1', 'true'):
                result = run(DRY_RUN=dry)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(before, snapshot())
            result = run(DRY_RUN='false')
            self.assertEqual(result.returncode, 0, result.stderr)
            for rel in ('Theme.qml', 'Icons.qml', 'shell.qml', 'services/qmldir',
                        'services/Archives.qml', 'modules/files/files.js', 'modules/files/FilesWindow.qml'):
                self.assertEqual((config / 'quickshell' / rel).read_bytes(),
                                 (ROOT / 'config/quickshell' / rel).read_bytes())
            self.assertEqual((home / 'backup/config/quickshell/shell.qml').read_text(), '// old shell')
            self.assertEqual((home / 'backup/config/hypr/rules.lua').read_text(), '-- old rules')
            before = snapshot()
            self.assertEqual(run().returncode, 10)
            self.assertEqual(before, snapshot())

    def test_repo_links_are_not_replaced(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / 'quickshell').symlink_to(ROOT / 'config/quickshell', target_is_directory=True)
            (home / 'hypr').symlink_to(ROOT / 'config/hypr', target_is_directory=True)
            result = subprocess.run(['bash', str(ROOT / 'migrations/080-files-ui.sh')],
                env=dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=tmp,
                         XDG_STATE_HOME=str(home / 'state'), DRY_RUN='1'), capture_output=True)
            self.assertEqual(result.returncode, 10, result.stderr)
            self.assertFalse((home / 'state').exists())
