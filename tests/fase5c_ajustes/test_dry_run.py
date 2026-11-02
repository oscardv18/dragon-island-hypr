import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('install_dry_run', ROOT/'tests/install-dry-run.py')
dry = importlib.util.module_from_spec(spec); spec.loader.exec_module(dry)


class IsolatedDryRun(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='dry-check-test-'); self.addCleanup(self.tmp.cleanup)
        self.installer = Path(self.tmp.name)/'installer'

    def fake(self, body):
        self.installer.write_text('#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\n'+body+'\n')
        self.installer.chmod(0o755)

    def test_passes_private_home_and_all_xdg_roots(self):
        original = {key: os.environ.get(key) for key in ('HOME', 'XDG_STATE_HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR')}
        self.fake('assert "--dry-run" in sys.argv\n'
                  'original = '+repr(original)+'\n'
                  'for key, value in original.items():\n'
                  '    path = Path(os.environ[key])\n'
                  '    assert str(path) != value and path.is_dir()\n'
                  '    assert path.parent.name.startswith("dragon-install-dry-")\n')
        self.assertEqual(dry.check(self.installer), [])

    def test_detects_writes_to_home_and_xdg_without_allowlist(self):
        for key, relative in [('HOME', '.zshrc'), ('XDG_STATE_HOME', 'dragon-island/activity.jsonl'),
                              ('XDG_CONFIG_HOME', 'bad'), ('XDG_DATA_HOME', 'bad'), ('XDG_CACHE_HOME', 'bad')]:
            with self.subTest(key=key):
                self.fake(f'(Path(os.environ[{key!r}])/{relative!r}).write_text("unexpected write")')
                errors = dry.check(self.installer)
                self.assertTrue(any('cambió el HOME/XDG' in e for e in errors), errors)

    def test_reports_nonzero_installer_exit(self):
        self.fake('raise SystemExit(7)')
        self.assertIn('salida 7', '\n'.join(dry.check(self.installer)))

    def test_external_activity_in_parent_state_does_not_cause_false_positive(self):
        from unittest.mock import patch
        parent_home = Path(self.tmp.name)/'desktop-home'; parent_home.mkdir()
        parent_state = Path(self.tmp.name)/'desktop-state'; parent_state.mkdir()
        activity = parent_state/'activity.jsonl'; activity.write_text('before')
        self.fake(f'Path({str(activity)!r}).write_text("desktop activity changed")')
        with patch.dict(os.environ, HOME=str(parent_home), XDG_STATE_HOME=str(parent_state)):
            self.assertEqual(dry.check(self.installer), [])
        self.assertEqual(activity.read_text(), 'desktop activity changed')
