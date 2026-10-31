import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dragon-core'))


class EngineCase(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='dragon-engines-test-')
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.env = dict(HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / 'config'),
                        XDG_STATE_HOME=str(self.home / 'state'), XDG_DATA_HOME=str(self.home / 'data'),
                        XDG_CACHE_HOME=str(self.home / 'cache'), XDG_RUNTIME_DIR=str(self.home / 'runtime'),
                        HISTFILE=str(self.home / 'history'), PYTHONDONTWRITEBYTECODE='1')
        self.environment = patch.dict(os.environ, self.env)
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def cli(self, name, *args, input=None, code=0):
        process = subprocess.run([str(ROOT / 'bin' / name), *args], input=input,
                                 text=True, capture_output=True, timeout=5)
        self.assertEqual(process.returncode, code, process.stderr + process.stdout)
        return json.loads(process.stdout)

    def shim(self, name, source):
        directory = self.home / 'shims'
        directory.mkdir(exist_ok=True)
        path = directory / name
        path.write_text('#!/usr/bin/python3\n' + source, encoding='utf-8')
        path.chmod(0o755)
        os.environ['PATH'] = str(directory) + ':/usr/bin:/bin'
        return path
