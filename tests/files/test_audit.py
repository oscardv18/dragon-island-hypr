"""Audit of dragon-files (fase 5d): every finding of docs/noche/pre-auditoria-d1d3.md and of the full d1–d8 audit
gets a regression test here. Temporary HOME/XDG only; nothing touches the real system."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / 'bin/dragon-files'


class AuditBase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='df-audit-')
        self.addCleanup(self.tmp.cleanup)
        # Everything the tool may write lives under box/; outside/ is a sibling that must never be reached.
        self.box = Path(self.tmp.name) / 'box'
        self.outside = Path(self.tmp.name) / 'outside'
        self.home = self.box / 'home'
        self.home.mkdir(parents=True)
        self.outside.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PYTHONDONTWRITEBYTECODE='1', TZ='UTC')
        for key in ('CONFIG', 'DATA', 'STATE', 'CACHE', 'RUNTIME'):
            p = self.home / key.lower()
            p.mkdir(mode=0o700, exist_ok=True)
            self.env['XDG_' + key + ('_DIR' if key == 'RUNTIME' else '_HOME')] = str(p)
        self.trash = self.home / 'data/Trash'

    def run_cli(self, *args, stdin=None, timeout=20, env=None):
        p = subprocess.run([str(BIN), *args, '--json'], env=env or self.env, input=stdin, capture_output=True,
                           text=True, timeout=timeout)
        lines = [l for l in p.stdout.splitlines() if l.strip()]
        try:
            last = json.loads(lines[-1]) if lines else None
        except json.JSONDecodeError:
            last = None
        return p, last

    def cli_error(self, *args, code=None, **kw):
        p, res = self.run_cli(*args, **kw)
        self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIsNotNone(res, 'errors must be JSON, not a traceback: ' + p.stdout + p.stderr)
        self.assertFalse(res.get('ok', True), res)
        if code:
            self.assertEqual(res['error']['code'], code, res)
        return res

    def cli_ok(self, *args, **kw):
        p, res = self.run_cli(*args, **kw)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertTrue(res and res.get('ok'), p.stdout + p.stderr)
        return res


class TrashNames(AuditBase):
    """Hallazgo 1: trash:/// names with an encoded '..' reached outside Trash/files."""

    def setUp(self):
        super().setUp()
        (self.trash / 'files').mkdir(parents=True)
        (self.trash / 'info').mkdir(parents=True)
        self.victim = self.outside / 'victim'
        self.victim.write_text('keep me')

    def test_delete_rejects_traversal(self):
        rel = os.path.relpath(self.victim, self.trash / 'files').replace('/', '%2F')
        self.cli_error('op', 'delete', 'trash:///' + rel, '--confirm', code='invalid_trash_item')
        self.assertTrue(self.victim.exists())

    def test_delete_rejects_whole_trash(self):
        (self.trash / 'files/a').write_text('x')
        self.cli_error('op', 'delete', 'trash:///', '--confirm', code='invalid_trash_item')
        self.assertTrue((self.trash / 'files/a').exists())

    def test_delete_validates_all_before_deleting(self):
        (self.trash / 'files/a').write_text('x')
        self.cli_error('op', 'delete', 'trash:///a', 'trash:///..', '--confirm', code='invalid_trash_item')
        self.assertTrue((self.trash / 'files/a').exists())

    def test_restore_rejects_traversal(self):
        rel = os.path.relpath(self.victim, self.trash / 'files').replace('/', '%2F')
        self.cli_error('trash', 'restore', 'trash:///' + rel, code='invalid_trash_item')
        self.assertEqual(self.victim.read_text(), 'keep me')

    def test_valid_name_with_percent_still_works(self):
        (self.home / 'a%2Fb').write_text('x')
        res = self.cli_ok('op', 'trash', str(self.home / 'a%2Fb'))
        listing = self.cli_ok('ls', 'trash:///')
        uri = listing['entries'][0]['uri']
        self.cli_ok('trash', 'restore', uri)
        self.assertTrue((self.home / 'a%2Fb').exists(), res)


if __name__ == '__main__':
    unittest.main()


class IntoItself(AuditBase):
    """Hallazgo 2: copying or moving a folder into itself through a symlink recursed ~1000 levels."""

    def setUp(self):
        super().setUp()
        self.src = self.home / 'a'
        (self.src / 'sub').mkdir(parents=True)
        (self.src / 'f').write_text('hi')
        (self.home / 'to-a').symlink_to(self.src)
        (self.home / 'to-sub').symlink_to(self.src / 'sub')

    def tree(self):
        return sorted(str(p.relative_to(self.src)) for p in self.src.rglob('*'))

    def test_copy_into_symlink_to_itself(self):
        before = self.tree()
        for dest in ('to-a', 'to-sub'):
            self.cli_error('op', 'copy', str(self.src), '--dest', str(self.home / dest), '--conflict', 'rename',
                           code='invalid_dest')
        self.assertEqual(self.tree(), before)

    def test_move_into_symlink_to_itself(self):
        before = self.tree()
        self.cli_error('op', 'move', str(self.src), '--dest', str(self.home / 'to-sub'), '--conflict', 'rename',
                       code='invalid_dest')
        self.assertEqual(self.tree(), before)

    def test_copy_next_to_itself_still_works(self):
        self.cli_ok('op', 'copy', str(self.src), '--dest', str(self.home), '--conflict', 'rename')
        self.assertTrue((self.home / 'a (1)/f').exists())


class ProtectedPaths(AuditBase):
    """Hallazgo 3: `op delete --confirm` removed HOME (or ~/.config…) with no further check.
    Destructive commands only ever receive paths inside the temporary box; system paths are checked through
    protected_reason() itself, which never deletes anything."""

    def test_delete_trash_move_refuse_home_and_config(self):
        (self.home / '.config/app').mkdir(parents=True)
        (self.home / '.ssh').mkdir()
        dest = self.home / 'dest'; dest.mkdir()
        for target in (self.home, self.home / '.config', self.home / '.ssh', self.box):
            self.cli_error('op', 'delete', str(target), '--confirm', code='protected_path')
            self.cli_error('op', 'trash', str(target), code='protected_path')
        self.cli_error('op', 'move', str(self.home / '.config'), '--dest', str(dest), code='protected_path')
        self.assertTrue((self.home / '.config/app').is_dir())

    def test_tilde_and_trailing_slash(self):
        self.cli_error('op', 'delete', '~/', '--confirm', code='protected_path')
        self.cli_error('op', 'delete', str(self.home) + '/./', '--confirm', code='protected_path')
        self.assertTrue(self.home.is_dir())

    def test_system_paths_are_protected(self):
        code = ('import sys; sys.path.insert(0, sys.argv[1]); import dragon_files as d; '
                'print([p for p in sys.argv[2:] if not d.protected_reason(p)])')
        paths = ['/', '/usr', '/etc/', '/home', '/run/media', '//', '/usr/../usr']
        p = subprocess.run(['python3', '-S', '-c', code, str(ROOT / 'dragon-core'), *paths], env=self.env,
                           capture_output=True, text=True, timeout=15)
        self.assertEqual(p.stdout.strip(), '[]', p.stdout + p.stderr)

    def test_symlink_to_home_is_only_a_link(self):
        link = self.home / 'atajo'
        link.symlink_to(self.home)
        self.cli_ok('op', 'delete', str(link), '--confirm')
        self.assertFalse(os.path.lexists(link))
        self.assertTrue(self.home.is_dir())

    def test_ordinary_files_and_folders_still_go(self):
        (self.home / 'Docs/sub').mkdir(parents=True)
        (self.home / 'Docs/sub/x').write_text('x')
        (self.home / '.config/app').mkdir(parents=True)
        self.cli_ok('op', 'delete', str(self.home / '.config/app'), '--confirm')
        self.cli_ok('op', 'trash', str(self.home / 'Docs/sub'))
        self.assertFalse((self.home / 'Docs/sub').exists())
