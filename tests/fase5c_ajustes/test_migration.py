import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT/'migrations/065-taller-ui-files.txt'


class Migration065(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='dragon065-'); self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name); self.home = self.base/'home'; self.home.mkdir()
        self.repo = self.base/'source'; (self.repo/'lib').mkdir(parents=True); (self.repo/'migrations').mkdir()
        for name in ('common.sh', 'migration-env.sh'): shutil.copy2(ROOT/'lib'/name, self.repo/'lib'/name)
        shutil.copy2(MANIFEST, self.repo/'migrations'/MANIFEST.name)
        self.files = MANIFEST.read_text().splitlines()
        for name in self.files:
            file = self.repo/'config/quickshell'/name; file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('// synthetic 5c: '+name+'\n')
        self.target = self.home/'config/quickshell'; self.target.mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home/'config'),
                        XDG_STATE_HOME=str(self.home/'state'), XDG_DATA_HOME=str(self.home/'data'),
                        REPO_DIR=str(self.repo), BACKUP_DIR=str(self.home/'backups'), LINK_MODE='copy', ASSUME_YES='true')

    def run_migration(self, code=0, **env):
        r = subprocess.run(['bash', str(ROOT/'migrations/065-taller-ui.sh')], env=dict(self.env, **env),
                           capture_output=True, text=True, timeout=15)
        self.assertEqual(r.returncode, code, r.stdout+r.stderr)
        return r

    def snapshot(self):
        return {str(p.relative_to(self.home)): (p.is_symlink(), os.readlink(p) if p.is_symlink() else p.read_bytes(), p.lstat().st_mtime_ns)
                for p in self.home.rglob('*') if p.is_file() or p.is_symlink()}

    def test_all_new_and_changed_files_copy_backup_idempotence(self):
        old = self.target/'services/Mem.qml'; old.parent.mkdir(); old.write_text('custom old version')
        unrelated = self.target/'user.qml'; unrelated.write_text('keep')
        self.run_migration()
        for name in self.files: self.assertEqual((self.target/name).read_bytes(), (self.repo/'config/quickshell'/name).read_bytes())
        self.assertEqual((self.home/'backups/config/quickshell/services/Mem.qml').read_text(), 'custom old version')
        self.assertEqual(unrelated.read_text(), 'keep')
        before = self.snapshot(); self.run_migration(); self.assertEqual(before, self.snapshot())
        self.assertEqual(len(self.files), 20)
        self.assertIn('services/qmldir', self.files); self.assertIn('modules/taller/ReviewDiff.qml', self.files)

    def test_dry_run_never_writes_even_with_existing_files(self):
        old = self.target/'Theme.qml'; old.write_text('old')
        before = self.snapshot()
        for flag in ('1', 'true'):
            self.run_migration(DRY_RUN=flag); self.assertEqual(before, self.snapshot())
        self.assertFalse((self.home/'backups').exists())

    def test_linked_install_never_changes_repository(self):
        self.target.rmdir(); self.target.symlink_to(self.repo/'config/quickshell', target_is_directory=True)
        before = {p: p.read_bytes() for p in (self.repo/'config/quickshell').rglob('*') if p.is_file()}
        self.run_migration(); self.run_migration()
        self.assertEqual(before, {p: p.read_bytes() for p in before})
        self.assertFalse((self.home/'backups').exists())

    def test_missing_source_skips_entire_deployment(self):
        (self.repo/'config/quickshell/services/Tokens.qml').unlink()
        self.run_migration(code=10)
        self.assertEqual(list(self.target.iterdir()), [])
        self.assertFalse((self.home/'backups').exists())

    def test_symlink_deployment_is_idempotent_and_backs_up_copies(self):
        (self.target/'Theme.qml').write_text('custom')
        self.run_migration(LINK_MODE='symlink'); before = self.snapshot()
        self.run_migration(LINK_MODE='symlink'); self.assertEqual(before, self.snapshot())
        self.assertTrue((self.target/'Theme.qml').is_symlink())
        self.assertEqual((self.home/'backups/config/quickshell/Theme.qml').read_text(), 'custom')
