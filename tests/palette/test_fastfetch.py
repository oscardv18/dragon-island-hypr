"""Only color tokens may change. Layout, commands, order and labels stay intact."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dragon-core'))
from palette import DRAGON
from palette_apps import render
from palette_fastfetch import loads_jsonc, tint_config


class Fastfetch(unittest.TestCase):
    def test_jsonc_strings_comments_and_trailing_commas(self):
        self.assertEqual(loads_jsonc('''{/* test */ "url":"https://a/b", // comment
          "text":"literal ,} and /*word*/", "list":[1,2,],}'''),
                         dict(url='https://a/b', text='literal ,} and /*word*/', list=[1,2]))

    def test_layout_and_commands_unchanged(self):
        base = json.loads((ROOT / 'fastfetch-theme/config/config.jsonc').read_text())
        colors = json.loads(render(DRAGON)['fastfetch-colors.json'])
        tinted = tint_config(base, colors)
        self.assertNotEqual(tinted, base)
        def without_colors(value):
            if isinstance(value, dict):
                return {k: without_colors(v) for k,v in value.items()}
            if isinstance(value, list):
                return [without_colors(v) for v in value]
            if isinstance(value, str):
                return re.sub(r'38;2;\d+;\d+;\d+', 'COLOR', value)
            return value
        self.assertEqual(without_colors(tinted), without_colors(base))
        self.assertEqual([m.get('text') for m in tinted['modules']],
                         [m.get('text') for m in base['modules']])

    def test_reset_recovers_original_fastfetch_colors(self):
        base = json.loads((ROOT / 'fastfetch-theme/config/config.jsonc').read_text())
        colors = json.loads(render(DRAGON, legacy=True)['fastfetch-colors.json'])
        self.assertEqual(tint_config(base, colors), base)

    @unittest.skipUnless(shutil.which('fastfetch'), 'fastfetch no está instalado')
    def test_fastfetch_accepts_merged_config_on_stdin(self):
        base = json.loads((ROOT / 'fastfetch-theme/config/config.jsonc').read_text())
        # Do not execute the real config's commands or query the user's session.
        base['modules'] = [{'type':'custom', 'format':'layout preserved'}]
        base['logo'] = {'type':'none'}
        tinted = tint_config(base, json.loads(render(DRAGON)['fastfetch-colors.json']))
        result = subprocess.run(['fastfetch','--config','-','--pipe'], input=json.dumps(tinted),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'layout preserved')


if __name__ == '__main__':
    unittest.main()
