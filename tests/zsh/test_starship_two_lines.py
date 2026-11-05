"""Migration 192: the two-line Starship prompt reaches detached copies of Dragon's starship.toml, keeping the
dragon-palette block; foreign, linked and dry-run cases are left alone."""
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[2]
REPO = (ROOT / 'config/starship/starship.toml').read_text(encoding='utf-8')
BEGIN = '# >>> dragon-palette'
OLD_BODY = 'palette = "dragon"\n# dragon-island — starship prompt (one line)\nadd_newline = true\n[character]\nsuccess_symbol = "[>](bold success)"\n\n'
MY_BLOCK = BEGIN + '\n[palettes.dragon]\naccent = "#123456"\nsuccess = "#00FF00"\n# <<< dragon-palette\n'


class StarshipTwoLines(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix='starship-192-')
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name) / 'home with spaces'
        (self.home / '.config').mkdir(parents=True)
        self.dest = self.home / '.config/starship.toml'
        self.env = dict(os.environ, HOME=str(self.home), REPO_DIR=str(ROOT), XDG_CONFIG_HOME=str(self.home / '.config'),
                        XDG_STATE_HOME=str(self.home / '.local/state'), ASSUME_YES='true', LINK_MODE='copy')
        self.env.pop('STARSHIP_CONFIG', None)

    def migrate(self, dry=False, code=0):
        r = subprocess.run(['bash', str(ROOT / 'migrations/192-starship-two-lines.sh')],
                           env=dict(self.env, DRY_RUN=str(dry).lower()), capture_output=True, text=True)
        self.assertEqual(r.returncode, code, r.stdout + r.stderr)

    def test_detached_copy_gets_new_body_and_keeps_its_palette(self):
        self.dest.write_text(OLD_BODY + MY_BLOCK, encoding='utf-8')
        self.migrate()
        text = self.dest.read_text(encoding='utf-8')
        self.assertEqual(text, REPO.split(BEGIN, 1)[0] + MY_BLOCK)
        self.assertEqual(tomllib.loads(text)['palettes']['dragon']['accent'], '#123456')
        self.assertTrue(tomllib.loads(text)['format'].count('\n') >= 1)
        backups = list((self.home / '.local/state/dragon-island/backups').rglob('starship.toml'))
        self.assertEqual([b.read_text(encoding='utf-8') for b in backups], [OLD_BODY + MY_BLOCK])
        self.migrate()   # idempotent: nothing more is written or backed up
        self.assertEqual(self.dest.read_text(encoding='utf-8'), text)
        self.assertEqual(len(list((self.home / '.local/state/dragon-island/backups').rglob('starship.toml'))), 1)

    def test_dry_run_writes_nothing(self):
        self.dest.write_text(OLD_BODY + MY_BLOCK, encoding='utf-8')
        self.migrate(dry=True)
        self.assertEqual(self.dest.read_text(encoding='utf-8'), OLD_BODY + MY_BLOCK)
        self.assertFalse((self.home / '.local').exists())

    def test_foreign_and_linked_files_are_left_alone(self):
        self.dest.write_text('# mine\nadd_newline = true\n', encoding='utf-8')
        self.migrate()
        self.assertEqual(self.dest.read_text(encoding='utf-8'), '# mine\nadd_newline = true\n')
        self.dest.unlink()
        self.dest.symlink_to(ROOT / 'config/starship/starship.toml')
        self.migrate()
        self.assertTrue(self.dest.is_symlink())

    def test_no_starship_config_is_skipped(self):
        self.migrate(code=10)


if __name__ == '__main__':
    unittest.main()
