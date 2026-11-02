"""Migrations 160 / 161 in a temporary HOME: DRY_RUN (1 and true) leaves no trace, backups, idempotence, and 161 never touches /boot
without a terminal."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class M(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='dbm')
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.home = Path(self.tmp)
        self.env = dict(os.environ, HOME=self.tmp, XDG_CONFIG_HOME=str(self.home / 'config'), XDG_STATE_HOME=str(self.home / 'state'),
                        XDG_DATA_HOME=str(self.home / 'data'), XDG_CACHE_HOME=str(self.home / 'cache'), BACKUP_DIR=str(self.home / 'backup'),
                        ASSUME_YES='true', LINK_MODE='symlink', BOOT_SYSTEM_DIR=str(self.home / 'system'), PYTHONDONTWRITEBYTECODE='1')

    def snap(self):
        return {str(p.relative_to(self.home)): (os.readlink(p) if p.is_symlink() else (p.read_bytes() if p.is_file() else None)) for p in sorted(self.home.rglob('*'))}

    def run_m(self, name, **extra):
        return subprocess.run(['bash', str(ROOT / 'migrations' / name)], env=dict(self.env, **extra), capture_output=True, text=True, stdin=subprocess.DEVNULL)

    def test_160_dry_run_apply_idempotent_copy(self):
        before = self.snap()
        for dry in ('1', 'true'):
            self.assertEqual(self.run_m('160-boot-tools.sh', DRY_RUN=dry).returncode, 0)
            self.assertEqual(before, self.snap())
        self.assertEqual(self.run_m('160-boot-tools.sh', DRY_RUN='false').returncode, 0)
        self.assertEqual(os.path.realpath(self.home / 'data/dragon-island/engines/dragon_boot.py'), str(ROOT / 'dragon-core/dragon_boot.py'))
        after = self.snap()
        self.assertEqual(self.run_m('160-boot-tools.sh', DRY_RUN='false').returncode, 0)
        self.assertEqual(after, self.snap())
        shutil.rmtree(self.home / 'data'), shutil.rmtree(self.home / '.local')
        self.assertEqual(self.run_m('160-boot-tools.sh', DRY_RUN='false', LINK_MODE='copy').returncode, 0)
        done = subprocess.run([str(self.home / '.local/bin/dragon-boot'), 'detect', '--root', str(self.home / 'nada')], capture_output=True, text=True, env=self.env)
        self.assertIn('"ok":true', done.stdout)             # runs from the copied engine, not from the repo

    def test_161_skips_when_not_installed_and_never_touches_boot_without_a_terminal(self):
        before = self.snap()
        self.assertEqual(self.run_m('161-boot-refresh.sh', DRY_RUN='false').returncode, 10)
        system = self.home / 'system'
        system.mkdir()
        (system / 'settings.json').write_text('{}')
        (system / 'dragon_boot.py').write_text('# old engine\n')
        before = self.snap()
        r = self.run_m('161-boot-refresh.sh', DRY_RUN='false')
        self.assertEqual(r.returncode, 10, r.stdout + r.stderr)
        self.assertEqual(before, self.snap())
        for dry in ('1', 'true'):
            r = self.run_m('161-boot-refresh.sh', DRY_RUN=dry)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(before, self.snap())

    def test_161_up_to_date_is_skipped(self):
        system = self.home / 'system'
        system.mkdir()
        (system / 'settings.json').write_text('{}')
        shutil.copy(ROOT / 'dragon-core/dragon_boot.py', system / 'dragon_boot.py')
        self.assertEqual(self.run_m('161-boot-refresh.sh', DRY_RUN='false').returncode, 10)


if __name__ == '__main__':
    unittest.main()
