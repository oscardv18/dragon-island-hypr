import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TelegramPortal(unittest.TestCase):
    def test_migration_preserves_entries_backup_dry_run_and_launch_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            data = home / 'data'
            applications = data / 'applications'
            applications.mkdir(parents=True)
            desktop = applications / 'org.telegram.desktop.desktop'
            original = ('[Desktop Entry]\nName=Telegram Custom\nExec=Telegram -- %U\n'
                        'DBusActivatable=true\nIcon=custom\nActions=quit;\n'
                        '[Desktop Action quit]\nName=Quit\nExec=Telegram -quit\n')
            desktop.write_text(original)
            binary = home / 'bin'
            binary.mkdir()
            fake = binary / 'Telegram'
            fake.write_text('#!/bin/sh\nprintf "%s\\n" "$QT_QPA_PLATFORMTHEME" "$@"\n')
            fake.chmod(0o755)
            refresh = binary / 'update-desktop-database'
            calls = home / 'refresh.calls'
            refresh.write_text('#!/bin/sh\necho refresh >> ' + shlex.quote(str(calls)) + '\n')
            refresh.chmod(0o755)
            runner = home / '.local/bin/dragon-telegram'
            runner.parent.mkdir(parents=True)
            runner.write_text('old runner\n')
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=str(home / 'cfg'),
                       XDG_DATA_HOME=str(data), XDG_STATE_HOME=str(home / 'state'),
                       PATH=str(binary) + ':' + os.environ['PATH'], ASSUME_YES='1',
                       BACKUP_DIR=str(home / 'backup'), QT_QPA_PLATFORMTHEME='hyprqt6engine')
            migration = ['bash', str(ROOT / 'migrations/122-telegram-portal.sh')]
            for dry in ('1', 'true'):
                subprocess.run(migration, env=dict(env, DRY_RUN=dry), check=True, capture_output=True)
            self.assertEqual(desktop.read_text(), original)
            self.assertEqual(runner.read_text(), 'old runner\n')
            self.assertFalse(calls.exists())
            self.assertFalse((home / 'state').exists())
            subprocess.run(migration, env=env, check=True, capture_output=True)
            text = desktop.read_text()
            self.assertIn('Name=Telegram Custom', text)
            self.assertIn('Icon=custom', text)
            self.assertIn('DBusActivatable=false', text)
            self.assertIn('Exec=Telegram -quit', text)
            self.assertIn('dragon-telegram" -- %U', text)
            self.assertEqual((home / 'backup/data/applications/org.telegram.desktop.desktop').read_text(), original)
            self.assertEqual((home / 'backup/.local/bin/dragon-telegram').read_text(), 'old runner\n')
            before = desktop.stat().st_mtime_ns
            subprocess.run(migration, env=env, check=True, capture_output=True)
            self.assertEqual(desktop.stat().st_mtime_ns, before)
            self.assertEqual(calls.read_text(), 'refresh\n')
            for desktop_name, theme in [('Hyprland', 'xdgdesktopportal'), ('KDE:Hyprland', 'xdgdesktopportal'), ('KDE', 'hyprqt6engine')]:
                result = subprocess.run([str(runner), '--', 'tg://test'],
                                        env=dict(env, XDG_CURRENT_DESKTOP=desktop_name),
                                        capture_output=True, text=True, check=True)
                self.assertEqual(result.stdout.splitlines(), [theme, '--', 'tg://test'])
