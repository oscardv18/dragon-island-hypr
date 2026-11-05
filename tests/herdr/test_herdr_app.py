"""Migration 193 / herdr_app_setup: the Herdr desktop app gets the dragon-ghostty theme and Ghostty's font; existing
settings are never overwritten; dry-run writes nothing; without ~/.config/herdr-app it is skipped (10)."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
OURS = json.loads((ROOT / 'config/herdr-app/dragon-settings.json').read_text(encoding='utf-8'))


class HerdrAppLook(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix='herdr-app-193-')
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name) / 'home with spaces'
        self.app = self.home / '.config/herdr-app'
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), REPO_DIR=str(ROOT), XDG_CONFIG_HOME=str(self.home / '.config'),
                        XDG_STATE_HOME=str(self.home / '.local/state'), ASSUME_YES='true', LINK_MODE='copy')

    def migrate(self, dry=False, code=0):
        r = subprocess.run(['bash', str(ROOT / 'migrations/193-herdr-app-look.sh')],
                           env=dict(self.env, DRY_RUN=str(dry).lower()), capture_output=True, text=True)
        self.assertEqual(r.returncode, code, r.stdout + r.stderr)

    def settings(self):
        return json.loads((self.app / 'settings.json').read_text(encoding='utf-8'))

    def test_app_never_opened_is_skipped(self):
        self.migrate(code=10)
        self.assertFalse(self.app.exists())

    def test_adds_theme_and_missing_keys_only(self):
        self.app.mkdir(parents=True)
        (self.app / 'settings.json').write_text(json.dumps({'zoom': 1.2, 'font_size': 16}), encoding='utf-8')
        self.migrate()
        s = self.settings()
        self.assertEqual(s['zoom'], 1.2)
        self.assertEqual(s['font_size'], 16)            # the person's choice stays
        for key in ('theme', 'font', 'ui_font'):
            self.assertEqual(s[key], OURS[key])
        theme = json.loads((self.app / 'themes/dragon-ghostty.json').read_text(encoding='utf-8'))
        self.assertEqual(theme['background'], '#0b0c14')
        self.assertEqual(len(theme['ansi']), 16)
        before = (self.app / 'settings.json').read_bytes()
        self.migrate()                                   # idempotent
        self.assertEqual((self.app / 'settings.json').read_bytes(), before)

    def test_missing_settings_file_is_created(self):
        self.app.mkdir(parents=True)
        self.migrate()
        self.assertEqual(self.settings(), OURS)

    def test_dry_run_writes_nothing(self):
        self.app.mkdir(parents=True)
        (self.app / 'settings.json').write_text('{"zoom": 1}', encoding='utf-8')
        self.migrate(dry=True)
        self.assertEqual((self.app / 'settings.json').read_text(encoding='utf-8'), '{"zoom": 1}')
        self.assertFalse((self.app / 'themes').exists())
        self.assertFalse((self.home / '.local').exists())


if __name__ == '__main__':
    unittest.main()
