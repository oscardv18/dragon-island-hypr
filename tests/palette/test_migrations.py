"""Actual migration execution in disposable homes, including symlinked configs."""
import os
import json
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Migrations(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='palette-test-')
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name) / 'home with spaces'
        self.home.mkdir()
        self.cfg = self.home / '.config'
        self.cfg.mkdir()
        self.environment = dict(os.environ, HOME=str(self.home), REPO_DIR=str(ROOT),
                                XDG_CONFIG_HOME=str(self.cfg),
                                XDG_STATE_HOME=str(self.home / '.local/state'),
                                XDG_DATA_HOME=str(self.home / '.local/share'),
                                ASSUME_YES='true', NO_SUDO='true', LINK_MODE='copy')
        self.environment.pop('STARSHIP_CONFIG', None)

    def run_migration(self, dry=False):
        result = subprocess.run(['bash', str(ROOT / 'migrations/030-palette-templates.sh')],
                                env=dict(self.environment, DRY_RUN=str(dry).lower()),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def snapshot(self):
        return {str(p.relative_to(self.home)): (str(p.readlink()) if p.is_symlink() else p.read_bytes(),
                                               p.lstat().st_mtime_ns)
                for p in self.home.rglob('*') if p.is_symlink() or p.is_file()}

    def seed_user_configs(self):
        for name, main, text in [('ghostty', 'config', 'font-size = 17\ncursor-color = #112233\n'),
                                 ('kitty', 'kitty.conf', 'font_size 17\ncolor1 #112233\n')]:
            (self.cfg / name).mkdir()
            (self.cfg / name / main).write_text(text)
        (self.cfg / 'starship.toml').write_text('# mine\n[directory]\nstyle = "bold #F04DFF"\n')

    def test_dry_run_creates_nothing(self):
        self.seed_user_configs()
        before = self.snapshot()
        self.run_migration(dry=True)
        self.assertEqual(before, self.snapshot())
        self.assertFalse((self.home / '.local').exists())

    def test_two_runs_preserve_configs_and_back_up_before_edit(self):
        self.seed_user_configs()
        self.run_migration()
        before = self.snapshot()
        self.run_migration()
        self.assertEqual(before, self.snapshot())
        ghostty = (self.cfg / 'ghostty/config').read_text()
        kitty = (self.cfg / 'kitty/kitty.conf').read_text()
        starship = (self.cfg / 'starship.toml').read_text()
        self.assertEqual(ghostty.count('config-file = '), 1)
        self.assertTrue(ghostty.startswith('font-size = 17\ncursor-color = #112233\n'))
        self.assertEqual(kitty.count('include '), 1)
        self.assertIn('color1 #112233', kitty)
        self.assertIn('# mine', starship)
        self.assertEqual(starship.count('# >>> dragon-palette'), 1)
        backups = list((self.home / '.local/state/dragon-island/backups').glob('*/.config/ghostty/config'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'font-size = 17\ncursor-color = #112233\n')

    def test_symlinked_directories_do_not_edit_the_repository(self):
        originals = {name: (ROOT / 'config' / name / main).read_bytes()
                     for name, main in [('ghostty','config'), ('kitty','kitty.conf')]}
        for name in originals:
            (self.cfg / name).symlink_to(ROOT / 'config' / name, target_is_directory=True)
        (self.cfg / 'starship.toml').symlink_to(ROOT / 'config/starship/starship.toml')
        starship = (ROOT / 'config/starship/starship.toml').read_bytes()
        self.run_migration()
        self.assertFalse((self.cfg / 'ghostty').is_symlink())
        self.assertFalse((self.cfg / 'kitty').is_symlink())
        for name, content in originals.items():
            main = 'config' if name == 'ghostty' else 'kitty.conf'
            self.assertEqual((ROOT / 'config' / name / main).read_bytes(), content)
        self.assertEqual((ROOT / 'config/starship/starship.toml').read_bytes(), starship)
        before = self.snapshot()
        self.run_migration()
        self.assertEqual(before, self.snapshot())

    def test_installed_copy_of_command_finds_its_library(self):
        self.run_migration()
        result = subprocess.run([str(self.home / '.local/bin/dragon-palette'), 'status'],
                                env=self.environment, capture_output=True, text=True, cwd='/')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'disabled Dragon')

    @unittest.skipUnless(shutil.which('ghostty'), 'Ghostty no está instalado')
    def test_ghostty_native_parser_overrides_explicit_legacy_colors(self):
        self.seed_user_configs()
        self.run_migration()
        result = subprocess.run(['ghostty', '+show-config'],
                                env=self.environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('cursor-color = #c8b6e6', result.stdout.lower())
        self.assertIn('palette = 4=#7e6ba8', result.stdout.lower())
        self.assertIn('font-size = 17', result.stdout)
        self.assertNotIn('theme not found', result.stderr.lower())

    @unittest.skipUnless(shutil.which('kitty'), 'kitty no está instalado')
    def test_kitty_native_parser_preserves_other_ansi_colors(self):
        self.seed_user_configs()
        self.run_migration()
        code = ('from kitty.config import load_config; '
                'import sys; o=load_config(sys.argv[1]); '
                'print(o.font_size, o.color1, o.color4, o.color12)')
        result = subprocess.run(['kitty', '+runpy', code, str(self.cfg / 'kitty/kitty.conf')],
                                env=self.environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('color(17, 34, 51)', result.stdout.lower())
        self.assertIn('color(126, 107, 168)', result.stdout.lower())
        self.assertIn('color(200, 182, 230)', result.stdout.lower())

    def test_update_recognizes_configs_it_must_preserve(self):
        self.seed_user_configs()
        self.run_migration()
        command = ('source "$REPO_DIR/lib/palette.sh"; '
                   'for t in "$XDG_CONFIG_HOME/ghostty" "$XDG_CONFIG_HOME/kitty" '
                   '"$XDG_CONFIG_HOME/starship.toml"; do '
                   'palette_config_managed "$t" || exit 1; done')
        result = subprocess.run(['bash','-c',command], env=self.environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_migration_keeps_a_previously_reset_palette(self):
        self.run_migration()
        command = self.home / '.local/bin/dragon-palette'
        subprocess.run([str(command), 'reset', '--quiet'], env=self.environment, check=True)
        previous = (self.cfg / 'dragon-island/palette/dragon-dynamic').read_text()
        self.run_migration()
        self.assertEqual((self.cfg / 'dragon-island/palette/dragon-dynamic').read_text(), previous)
        self.assertIn('#C50ED2', previous)

    def test_generation_alone_is_not_applied_by_migration(self):
        state = self.home / '.local/state/dragon-island'
        state.mkdir(parents=True)
        data = dict(version=1, source='/wallpaper.png', sourceHash='a'*40, fallback=False,
                    accent='#FFAAAA', accentSoft='#FFCCCC', accentDeep='#AA5555',
                    glow='#FF6666', onAccent='#000000', tint='#100000', swatches=['#FFAAAA']*5)
        (state / 'palette.json').write_text(json.dumps(data))
        self.run_migration()
        theme = self.cfg / 'dragon-island/palette/dragon-dynamic'
        self.assertIn('#C8B6E6', theme.read_text())
        # If that palette is applied, then another generate without apply must
        # leave the external files as they were even when migration is repeated.
        command = self.home / '.local/bin/dragon-palette'
        subprocess.run([str(command), 'apply', '--quiet'], env=self.environment, check=True)
        previous = theme.read_text()
        (state / 'palette.json').write_text(json.dumps(dict(data, sourceHash='b'*40, accent='#AABBFF')))
        self.run_migration()
        self.assertEqual(theme.read_text(), previous)

    def test_templates_defer_until_python_is_available(self):
        shims = self.home / 'empty-path'
        shims.mkdir()
        result = subprocess.run([shutil.which('bash'), str(ROOT / 'migrations/030-palette-templates.sh')],
                                env=dict(self.environment, PATH=str(shims), DRY_RUN='true'),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 10, result.stdout + result.stderr)
        self.assertFalse((self.home / '.local').exists())

    def test_dependency_decline_exits_ten_without_sudo(self):
        shims = self.home / 'shims'
        shims.mkdir()
        (shims / 'python3').write_text('#!/bin/sh\nexit 1\n')
        (shims / 'gum').write_text('#!/bin/sh\n[ "$1" != confirm ]\n')
        for shim in shims.iterdir():
            shim.chmod(0o755)
        result = subprocess.run(['bash', str(ROOT / 'migrations/031-palette-dependencies.sh')],
                                env=dict(self.environment, PATH=str(shims)+':'+os.environ['PATH'], ASSUME_YES='false'),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 10, result.stdout + result.stderr)
        self.assertFalse((self.home / '.local').exists())

    def test_dependency_migration_when_pillow_exists(self):
        result = subprocess.run(['bash', str(ROOT / 'migrations/031-palette-dependencies.sh')],
                                env=self.environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / '.local').exists())


if __name__ == '__main__':
    unittest.main()
