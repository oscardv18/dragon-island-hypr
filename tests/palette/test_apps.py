"""App fixtures and preservation of the user's TOML around the managed block."""
import sys
from pathlib import Path
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "dragon-core"))
from palette import DRAGON
from palette_apps import render, convert_starship, update_starship, BEGIN, END


class Templates(unittest.TestCase):
    def test_golden(self):
        for legacy in (False, True):
            folder = Path(__file__).with_name('golden') / ('legacy' if legacy else '')
            for name, content in render(DRAGON, legacy=legacy).items():
                with self.subTest(name=name, legacy=legacy):
                    self.assertEqual(content, (folder / name).read_text())

    def test_only_two_ansi_colors_change(self):
        outputs = render(DRAGON)
        self.assertEqual([line.split('=')[0].strip() for line in outputs['dragon-dynamic'].splitlines()
                          if line.startswith('palette')], ['palette', 'palette'])
        self.assertEqual([line.split()[0] for line in outputs['dragon-dynamic.conf'].splitlines()
                          if line.startswith('color')], ['color4', 'color12'])

    def test_conversion_preserves_user_settings_comments_and_semantics(self):
        text = 'command = \"printf #F04DFF\"\n# keep #F04DFF\nformat = "$directory"\n[directory]\nstyle = "bold #F04DFF"\n[character]\nerror_symbol = "[x](#FF3D48)"\nsuccess_symbol = "[>](#70FF58)"\n'
        block = render(DRAGON)['starship.toml']
        converted = convert_starship(text, block)
        self.assertIn('# keep #F04DFF', converted)
        self.assertIn('command = \"printf #F04DFF\"', converted)
        self.assertIn('style = "bold accent"', converted)
        self.assertEqual(converted.count(BEGIN), 1)
        self.assertEqual(convert_starship(converted, block), converted)
        data = tomllib.loads(converted)
        self.assertEqual(data['palettes']['dragon']['error'], '#FF3D48')
        self.assertEqual(data['palettes']['dragon']['success'], '#70FF58')
        new = render(dict(DRAGON, accent='#AABBCC'))['starship.toml']
        before, after = converted.split(BEGIN)[0], converted.split(END)[1]
        applied = update_starship(converted, new)
        self.assertEqual(applied.split(BEGIN)[0], before)
        self.assertEqual(applied.split(END)[1], after)

    def test_foreign_or_broken_toml_is_rejected(self):
        block = render(DRAGON)['starship.toml']
        for text in ('palette = "mine"\n', '[palettes.dragon]\naccent="red"\n', 'bad = [', BEGIN+'\n'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                convert_starship(text, block)

    def test_reset_restores_distinct_starship_module_colors(self):
        legacy = tomllib.loads(render(DRAGON, legacy=True)['starship.toml'])['palettes']['dragon']
        self.assertEqual(legacy['accent'], '#F04DFF')
        self.assertEqual(legacy['directory_accent'], '#FF426D')
        self.assertEqual(legacy['git_state'], '#FFEB65')
        self.assertEqual(legacy['warn'], '#FFB644')
        self.assertEqual(legacy['cyan'], '#22EEF7')
        self.assertEqual(legacy['accent_soft'], '#30C0FF')

    def test_repository_starship_is_valid(self):
        data = tomllib.loads((ROOT / 'config/starship/starship.toml').read_text())
        self.assertEqual(data['palette'], 'dragon')
        self.assertEqual(data['palettes']['dragon']['accent'], DRAGON['accent'])


if __name__ == '__main__':
    unittest.main()
