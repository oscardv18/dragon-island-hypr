"""Every `qs ipc call <target> <function> …` in the Hyprland binds passes exactly the arguments its IpcHandler
declares. Quickshell refuses a call with too few («Too few arguments provided») and still exits 0, so a bind like
SUPER+E → `files open` with no path silently did nothing (fase 5 integration)."""
import re
import shlex
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def ipc_signatures():
    sigs = {}
    for qml in (ROOT / 'config/quickshell').rglob('*.qml'):
        text = qml.read_text(encoding='utf-8')
        for block in re.finditer(r'IpcHandler\s*\{', text):
            # the handler body: balance braces from the opening one
            depth, i = 0, block.end() - 1
            while i < len(text):
                depth += {'{': 1, '}': -1}.get(text[i], 0)
                if depth == 0:
                    break
                i += 1
            body = text[block.end():i]
            target = re.search(r'target:\s*"([^"]+)"', body)
            if not target:
                continue
            for fn in re.finditer(r'function\s+(\w+)\s*\(([^)]*)\)', body):
                params = [p for p in fn.group(2).split(',') if p.strip()]
                sigs[(target.group(1), fn.group(1))] = len(params)
    return sigs


def bind_calls():
    text = (ROOT / 'config/hypr/binds.lua').read_text(encoding='utf-8')
    for m in re.finditer(r'"([^"\n]*qs ipc call [^"\n]*)"', text):
        for part in re.split(r'&&|;|\|\|', m.group(1)):
            words = shlex.split(part)
            if words[:3] == ['qs', 'ipc', 'call'] and len(words) >= 5:
                yield words[3], words[4], len(words) - 5, m.group(1)


class IpcBinds(unittest.TestCase):
    def test_every_bind_passes_the_declared_arguments(self):
        sigs = ipc_signatures()
        calls = list(bind_calls())
        self.assertGreater(len(calls), 10)
        for target, fn, given, raw in calls:
            with self.subTest(call=raw):
                self.assertIn((target, fn), sigs, f'no IpcHandler declares {target}.{fn}')
                self.assertEqual(given, sigs[(target, fn)], f'{raw}: {given} args, {sigs[(target, fn)]} declared')

    def test_super_e_opens_the_explorer(self):
        calls = [c for c in bind_calls() if c[:2] == ('files', 'open')]
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][2], 1)


if __name__ == '__main__':
    unittest.main()
