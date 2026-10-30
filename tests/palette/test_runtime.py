"""Commands execute in a temporary HOME; reloads are mocked, never real windows."""
from contextlib import ExitStack
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dragon-core'))
import palette
import palette_apps
import palette_runtime as runtime


class Application(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.config = self.home / '.config'
        self.state = self.home / '.local/state/dragon-island'
        self.environment = dict(HOME=str(self.home), XDG_CONFIG_HOME=str(self.config),
                                XDG_STATE_HOME=str(self.home / '.local/state'),
                                XDG_DATA_HOME=str(self.home / '.local/share'))
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.dict(os.environ, self.environment))
        os.environ.pop('STARSHIP_CONFIG', None)
        self.reload = self.stack.enter_context(patch.object(runtime, 'reload_apps'))
        self.data = dict(version=1, source='/background.png', sourceHash='a'*40,
                         fallback=False, **palette.DRAGON)

    def prepare(self):
        self.config.mkdir()
        block = palette_apps.render(palette.DRAGON)['starship.toml']
        (self.config / 'starship.toml').write_text('palette = "dragon"\n# keep me\n\n' + block)
        palette.atomic_write(self.state / 'palette.json', json.dumps(self.data))

    def test_apply_is_idempotent_and_preserves_starship(self):
        self.prepare()
        self.assertTrue(runtime.apply_palette(self.data, quiet=True))
        directory = self.config / 'dragon-island/palette'
        times = {p: p.stat().st_mtime_ns for p in directory.iterdir()}
        self.assertFalse(runtime.apply_palette(self.data, quiet=True))
        self.assertEqual(self.reload.call_count, 1)
        self.assertEqual(times, {p: p.stat().st_mtime_ns for p in directory.iterdir()})
        self.assertEqual((self.state / 'palette.applied').read_text(), 'a'*40+'\n')
        self.assertIn('# keep me', (self.config / 'starship.toml').read_text())

    def test_dry_run_no_changes_no_reload_no_applied_marker(self):
        self.prepare()
        before = {p: p.read_bytes() for p in self.home.rglob('*') if p.is_file()}
        runtime.apply_palette(self.data, dry_run=True, quiet=True)
        self.assertEqual(before, {p: p.read_bytes() for p in self.home.rglob('*') if p.is_file()})
        self.reload.assert_not_called()

    def test_bad_json_and_flags(self):
        self.prepare()
        bad = dict(self.data, accent='red')
        palette.atomic_write(self.state / 'palette.json', json.dumps(bad))
        with self.assertRaises(ValueError):
            runtime.read_palette()
        for args in (['--quiet', 'apply', '--dry-run'], ['apply', '--quiet', '--dry-run']):
            result = subprocess.run([str(ROOT / 'bin/dragon-palette'), *args],
                                    env=os.environ, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')
            self.assertFalse((self.state / 'palette.applied').exists())

    def test_foreign_starship_is_preserved_but_other_apps_apply(self):
        self.prepare()
        path = self.config / 'starship.toml'
        path.write_text('palette = "mine"\n')
        self.assertTrue(runtime.apply_palette(self.data, quiet=True))
        self.assertEqual(path.read_text(), 'palette = "mine"\n')
        self.assertTrue((self.config / 'dragon-island/palette/ghostty.conf').exists())

    def test_reset_restores_legacy_files_and_removes_only_json(self):
        self.prepare()
        runtime.apply_palette(self.data, quiet=True)
        runtime.reset_palette(quiet=True)
        self.assertFalse((self.state / 'palette.json').exists())
        self.assertEqual((self.state / 'palette.applied').read_text(), 'legacy-v1\n')
        for name, expected in palette_apps.render(palette.DRAGON, legacy=True).items():
            self.assertEqual((self.config / 'dragon-island/palette' / name).read_text(), expected)
        self.assertIn('# keep me', (self.config / 'starship.toml').read_text())
        times = {p: p.stat().st_mtime_ns for p in (self.config / 'dragon-island/palette').iterdir()}
        runtime.reset_palette(quiet=True)
        self.assertEqual(times, {p: p.stat().st_mtime_ns for p in times})
        runtime.apply_palette(self.data, quiet=True)
        self.assertEqual((self.state / 'palette.applied').read_text(), 'a'*40+'\n')

    def test_reset_dry_run_changes_nothing(self):
        self.prepare()
        before = {p: p.read_bytes() for p in self.home.rglob('*') if p.is_file()}
        runtime.reset_palette(dry_run=True, quiet=True)
        self.assertEqual(before, {p: p.read_bytes() for p in self.home.rglob('*') if p.is_file()})
        self.reload.assert_not_called()

    def test_no_signal_without_a_registered_handler(self):
        proc = self.home / 'proc'
        entry = proc / '1234'
        entry.mkdir(parents=True)
        (entry / 'exe').symlink_to('/usr/bin/ghostty')
        (entry / 'environ').write_bytes(b'HOME=' + os.fsencode(self.home) + b'\0XDG_CONFIG_HOME=' + os.fsencode(self.config) + b'\0')
        (entry / 'status').write_text('SigCgt: 0000000000000000\n')
        native_path = Path
        with patch.object(runtime, 'Path', side_effect=lambda p: proc if p == '/proc' else native_path(p)), \
             patch.object(runtime.os, 'kill') as kill:
            self.assertEqual(runtime.signal_app('ghostty', signal.SIGUSR2, quiet=True), 0)
            kill.assert_not_called()
            (entry / 'status').write_text('SigCgt: ' + format(1 << (signal.SIGUSR2 - 1), 'x') + '\n')
            self.assertEqual(runtime.signal_app('ghostty', signal.SIGUSR2, quiet=True), 1)
            kill.assert_called_once_with(1234, signal.SIGUSR2)
            kill.reset_mock()
            (entry / 'environ').write_bytes(b'HOME=/another/user-home\0')
            self.assertEqual(runtime.signal_app('ghostty', signal.SIGUSR2, quiet=True), 0)
            kill.assert_not_called()

    def test_broken_reload_does_not_prevent_other_app(self):
        with patch.object(runtime.shutil, 'which', return_value='/bin/app'), \
             patch.object(runtime, 'signal_app', return_value=0) as calls, \
             patch.dict(os.environ, {'KITTY_LISTEN_ON': 'unix:/missing'}), \
             patch.object(runtime.subprocess, 'run', side_effect=subprocess.TimeoutExpired('kitty', 2)):
            # Use the real function, not the setup mock.
            real_reload(self.config, quiet=True)
            self.assertEqual(calls.call_args_list[0].args[:2], ('ghostty', signal.SIGUSR2))
            self.assertEqual(calls.call_args_list[1].args[:2], ('kitty', signal.SIGUSR1))


real_reload = runtime.reload_apps

if __name__ == '__main__':
    unittest.main()
