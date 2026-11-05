"""Migration 195 / files_filemanager1_setup: the D-Bus activation file for org.freedesktop.FileManager1 points at
Archivos Dragon; idempotent; a foreign service file is respected; an older Dragon one is backed up and replaced;
dry-run writes nothing. The service itself (files_filemanager1.py) is covered by tests/files."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FileManager1(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix='fm1-195-')
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name) / 'home with spaces'
        self.home.mkdir()
        self.dest = self.home / '.local/share/dbus-1/services/org.freedesktop.FileManager1.service'
        self.env = dict(os.environ, HOME=str(self.home), REPO_DIR=str(ROOT), XDG_DATA_HOME=str(self.home / '.local/share'),
                        XDG_STATE_HOME=str(self.home / '.local/state'), ASSUME_YES='true')
        self.wanted = ('[D-BUS Service]\nName=org.freedesktop.FileManager1\n'
                       f'Exec={self.home}/.local/bin/dragon-files --filemanager1\n')

    def migrate(self, code=0, **extra):
        r = subprocess.run(['bash', str(ROOT / 'migrations/195-filemanager1-dragon.sh')], env=dict(self.env, **extra),
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, code, r.stdout + r.stderr)

    def backups(self):
        return list((self.home / '.local/state/dragon-island/backups').rglob('org.freedesktop.FileManager1.service'))

    def test_registers_once(self):
        self.migrate()
        self.assertEqual(self.dest.read_text(), self.wanted)
        mtime = self.dest.stat().st_mtime_ns
        self.migrate()
        self.assertEqual(self.dest.stat().st_mtime_ns, mtime)
        self.assertEqual(self.backups(), [])

    def test_foreign_service_is_respected(self):
        self.dest.parent.mkdir(parents=True)
        self.dest.write_text('[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=/usr/bin/nautilus --gapplication-service\n')
        self.migrate()
        self.assertIn('nautilus', self.dest.read_text())

    def test_old_dragon_service_is_replaced_with_backup(self):
        self.dest.parent.mkdir(parents=True)
        self.dest.write_text('[D-BUS Service]\nName=org.freedesktop.FileManager1\nExec=/old/path/dragon-files --filemanager1\n')
        self.migrate()
        self.assertEqual(self.dest.read_text(), self.wanted)
        self.assertEqual(len(self.backups()), 1)

    def test_dry_run_writes_nothing(self):
        self.migrate(DRY_RUN='true')
        self.assertFalse(self.dest.exists())
        self.assertFalse((self.home / '.local').exists())


if __name__ == '__main__':
    unittest.main()
