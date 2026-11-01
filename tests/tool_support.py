"""CLI integration sandbox. Every write stays under a temporary HOME/XDG."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'tests/fixtures/fase5c'


class ToolCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='dragon-tools-'); self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name); self.repo = self.home/'repo ñ'; self.repo.mkdir()
        self.fake = self.home/'fake'; self.fake.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PYTHONDONTWRITEBYTECODE='1',
                        PATH=str(self.fake)+':'+os.environ['PATH'], XDG_RUNTIME_DIR=str(self.home/'run'))
        for kind in ('DATA', 'CONFIG', 'CACHE', 'STATE'):
            self.env[f'XDG_{kind}_HOME'] = str(self.home/kind.lower())
        self.db = self.home/'data/dragon-island/dragon.db'
        self.cli('dragon-mem', 'project', 'add', '--path', self.repo, '--slug', 'test', '--prefix', 'AX')

    def cli(self, tool, *args, code=0, stdin=None):
        r = subprocess.run([str(ROOT/'bin'/tool), *map(str, args), '--json'], env=self.env,
                           input=stdin, capture_output=True, text=True, timeout=20)
        self.assertEqual(r.returncode, code, r.stdout+r.stderr)
        return json.loads(r.stdout)

    def card(self):
        return self.cli('dragon-mem', 'card', 'add', '--project', 'test', '--title', 'Función ágil')['card']['key']

    def fake_tool(self, name, source):
        file = self.fake/name; file.write_text('#!/usr/bin/env python3\n'+source); file.chmod(0o755)
