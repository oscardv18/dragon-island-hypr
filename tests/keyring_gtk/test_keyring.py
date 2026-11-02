import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Keyring(unittest.TestCase):
    def test_flags_backup_idempotence_and_dry_run(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cfg = home / 'cfg'
            cfg.mkdir()
            binary = home / 'bin'
            binary.mkdir()
            launcher = binary / 'claude-desktop'
            launcher.write_text('#!/bin/sh\n# claude-desktop-flags.conf\n')
            launcher.chmod(0o755)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(cfg),
                       XDG_STATE_HOME=str(home / 'state'), XDG_DATA_HOME=str(home / 'data'),
                       PATH=str(binary) + ':' + os.environ['PATH'], ASSUME_YES='1',
                       BACKUP_DIR=str(home / 'backup'))
            flags = cfg / 'claude-desktop-flags.conf'
            original = '# keep\n--ozone-platform=wayland --password-store=kwallet6\n--password-store basic\n'
            flags.write_text(original)
            script = ['bash', str(ROOT / 'migrations/120-claude-libsecret.sh')]
            subprocess.run(script, env=dict(env, DRY_RUN='1'), check=True, capture_output=True)
            self.assertEqual(flags.read_text(), original)
            self.assertFalse((home / 'state').exists())
            subprocess.run(script, env=env, check=True, capture_output=True)
            backup = home / 'backup/cfg/claude-desktop-flags.conf'
            self.assertEqual(backup.read_text(), original)
            expected = flags.read_text()
            self.assertIn('# keep', expected)
            self.assertIn('--ozone-platform=wayland', expected)
            self.assertEqual(expected.count('--password-store'), 1)
            self.assertIn('--password-store=gnome-libsecret', expected)
            subprocess.run(script, env=env, check=True, capture_output=True)
            self.assertEqual(flags.read_text(), expected)
            self.assertEqual(backup.read_text(), original)
