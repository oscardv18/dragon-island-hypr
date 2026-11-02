"""The Taller and the explorer use the glass material (ahumado by default) so the native blur shows through: their
panel fill is the translucent popover glass (Theme.popoverBg, main's 094: glassFill let the content show under menus, so
in-window overlays use Theme.overlay), and the explorer window's blur is clipped to the panel radius (global rounding is 14,
the panel 22)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THEME = (ROOT / 'config/quickshell/Theme.qml').read_text(encoding='utf-8')
RULES = (ROOT / 'config/hypr/rules.lua').read_text(encoding='utf-8')


def group(name):
    start = THEME.index(f'readonly property QtObject {name}: QtObject {{')
    depth, i = 0, THEME.index('{', start)
    for j in range(i, len(THEME)):
        depth += {'{': 1, '}': -1}.get(THEME[j], 0)
        if depth == 0:
            return THEME[i:j]
    raise AssertionError(name)


class GlassPanels(unittest.TestCase):
    def test_panels_use_the_popover_glass(self):
        for name in ('taller', 'files'):
            with self.subTest(group=name):
                m = re.search(r'readonly property color panel:\s*([^\n/]+)', group(name))
                self.assertEqual(m.group(1).strip(), 'root.popoverBg')

    def test_layers_and_window_get_blur(self):
        self.assertIn('"dragon-taller"', RULES)                     # layer blur list
        rule = RULES[RULES.index('name = "dragon-files-window"'):]
        self.assertIn('no_blur = false', rule[:400])

    def test_explorer_blur_clipped_to_panel_radius(self):
        radius = re.search(r'readonly property real radius:\s*(\d+)', group('files')).group(1)
        self.assertRegex(RULES, r'match\("\^Archivos · "\).*\n.*prop = "rounding", value = "%s"' % radius)


if __name__ == '__main__':
    unittest.main()
