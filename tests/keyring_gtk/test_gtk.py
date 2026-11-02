import json
import os
from pathlib import Path
import subprocess
import shlex
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dragon-core'))
from palette import DRAGON
from palette_apps import render


class Gtk(unittest.TestCase):
    def test_setup_backup_links_palette_and_dry_run(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cfg = home / 'cfg'
            cfg.mkdir()
            upstream = home / 'original'
            upstream.mkdir()
            original = '[Settings]\ngtk-theme-name=Breeze\ngtk-font-name=Test 12\n[Other]\nx=y\n'
            (upstream / 'settings.ini').write_text(original)
            (upstream / 'gtk.css').write_text('button { border-radius: 7px; }\n')
            (cfg / 'gtk-3.0').symlink_to(upstream, target_is_directory=True)
            fake = home / 'bin'
            fake.mkdir()
            # No real session bus/systemctl/dconf in temporary HOME tests.
            for name, body in {
                'gsettings': 'if [ "$1" = get ]; then echo "\047prefer-dark\047"; fi\n',
                'systemctl': 'exit 1\n', 'pacman': 'exit 0\n',
            }.items():
                p = fake / name
                if name == 'gsettings':
                    body = 'echo "$*" >> ' + shlex.quote(str(home / 'gsettings.calls')) + '\n' + body
                p.write_text('#!/bin/sh\n' + body)
                p.chmod(0o755)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(cfg),
                       XDG_DATA_HOME=str(home / 'data'), XDG_STATE_HOME=str(home / 'state'),
                       PATH=str(fake) + ':' + os.environ['PATH'], ASSUME_YES='1',
                       BACKUP_DIR=str(home / 'backup'))
            runner = home / '.local/bin/dragon-palette'
            runner.parent.mkdir(parents=True)
            previous_runner = home / 'previous-palette'
            previous_runner.write_text('#!/bin/sh\nexit 0\n')
            runner.symlink_to(previous_runner)
            script = ['bash', str(ROOT / 'migrations/121-gtk-dark-palette.sh')]
            subprocess.run(script, env=dict(env, DRY_RUN='1'), check=True, capture_output=True)
            self.assertTrue((cfg / 'gtk-3.0').is_symlink())
            self.assertFalse((home / 'state').exists())
            self.assertFalse((home / 'gsettings.calls').exists())
            subprocess.run(script, env=env, check=True, capture_output=True)
            self.assertEqual(runner.resolve(), ROOT / 'bin/dragon-palette')
            self.assertEqual((upstream / 'settings.ini').read_text(), original)
            self.assertFalse((cfg / 'gtk-3.0').is_symlink())
            self.assertEqual((home / 'backup/cfg/gtk-3.0/settings.ini').read_text(), original)
            files = [cfg / 'gtk-3.0/settings.ini', cfg / 'gtk-4.0/settings.ini', cfg / 'gtk-3.0/gtk.css']
            before = [p.read_text() for p in files]
            self.assertIn('gtk-theme-name=adw-gtk3-dark', before[0])
            self.assertIn('gtk-font-name=Test 12', before[0])
            self.assertIn('[Other]\nx=y', before[0])
            self.assertIn('button { border-radius: 7px; }', before[2])
            self.assertIn('file://', before[2])
            self.assertEqual((cfg / 'dragon-island/palette/gtk.css').read_text(), render(DRAGON)['gtk.css'])
            subprocess.run(script, env=env, check=True, capture_output=True)
            self.assertEqual([p.read_text() for p in files], before)
            self.assertEqual((home / 'backup/cfg/gtk-3.0/settings.ini').read_text(), original)

    def test_correct_ini_symlink_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cfg = home / 'cfg'
            gtk = cfg / 'gtk-4.0'
            gtk.mkdir(parents=True)
            settings = gtk / 'settings.ini'
            settings.symlink_to(ROOT / 'config/gtk-4.0/settings.ini')
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=str(cfg),
                       XDG_STATE_HOME=directory + '/state', XDG_DATA_HOME=directory + '/data')
            subprocess.run(['python3', str(ROOT / 'scripts/gtk-setup.py')],
                           env=env, check=True, capture_output=True)
            self.assertTrue(settings.is_symlink())

    def test_css_follows_apply_reset_and_dry_run(self):
        with tempfile.TemporaryDirectory() as directory:
            env = dict(os.environ, HOME=directory, XDG_CONFIG_HOME=directory + '/cfg',
                       XDG_STATE_HOME=directory + '/state', XDG_DATA_HOME=directory + '/data')
            state = Path(directory) / 'state/dragon-island'
            state.mkdir(parents=True)
            data = dict(DRAGON, accent='#AABBCC', tint='#112233', version=1,
                        source='fixture', sourceHash='a' * 40, fallback=False)
            (state / 'palette.json').write_text(json.dumps(data))
            command = ['bash', str(ROOT / 'bin/dragon-palette')]
            # CLI loads the library next to the repository wrapper.
            subprocess.run(command + ['apply', '--dry-run', '--quiet'], env=env, check=True, capture_output=True)
            self.assertFalse((Path(directory) / 'cfg').exists())
            subprocess.run(command + ['apply', '--quiet'], env=env, check=True, capture_output=True)
            css = Path(directory) / 'cfg/dragon-island/palette/gtk.css'
            self.assertIn('@define-color accent_color #AABBCC;', css.read_text())
            self.assertIn('@define-color window_bg_color #112233;', css.read_text())
            subprocess.run(command + ['reset', '--quiet'], env=env, check=True, capture_output=True)
            self.assertEqual(css.read_text(), render(DRAGON)['gtk.css'])
