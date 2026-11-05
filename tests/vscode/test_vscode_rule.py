"""VS Code translucency rule (rules.lua): Lua 0.57 syntax, anchored classes, no other app affected."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RULES = (ROOT / 'config/hypr/rules.lua').read_text(encoding='utf-8')
BLOCK = RULES[RULES.index('local VSCODE_OPACITY_ACTIVE'):RULES.index('-- Keep window transparency in every state')]


class VSCodeRule(unittest.TestCase):
    def test_variables_up_front(self):
        self.assertRegex(BLOCK, r'VSCODE_OPACITY_ACTIVE\s*=\s*"0\.\d+"')
        self.assertRegex(BLOCK, r'VSCODE_OPACITY_INACTIVE\s*=\s*"0\.\d+"')

    def test_lua_rule_syntax_not_legacy(self):
        self.assertIn('hl.window_rule({', BLOCK)
        self.assertNotRegex(RULES, r'windowrule(v2)?\s*=')   # hyprlang syntax is dead on a Lua config

    def test_only_vscode_classes(self):
        classes = re.search(r'VSCODE_CLASSES\s*=\s*\{([^}]*)\}', BLOCK).group(1)
        names = re.findall(r'"([^"]+)"', classes)
        self.assertEqual(set(names), {'com\\\\.microsoft\\\\.VSCode', 'Code', 'code', 'code-oss', 'Antigravity'})
        self.assertIn('"^(" .. table.concat(VSCODE_CLASSES, "|") .. ")$"', BLOCK)   # anchored: no substring matches


if __name__ == '__main__':
    unittest.main()
