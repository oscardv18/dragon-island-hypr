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


class ConflictRaces(AuditBase):
    """Hallazgo 4: a file created at the destination after the conflict check was silently overwritten."""

    def slow_copy_with_intruder(self, policy, kind='copy'):
        src = self.home / 'big.bin'
        src.write_bytes(os.urandom(4 * 262144))
        dest = self.home / 'dest'; dest.mkdir()
        env = dict(self.env, DRAGON_FILES_SLOW_MS='120')
        proc = subprocess.Popen([str(BIN), 'op', kind, str(src), '--dest', str(dest), '--conflict', policy,
                                 '--json-progress', '--json'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        first = proc.stdout.readline()          # the copy is running: the conflict check is behind us
        self.assertIn('progress', first)
        (dest / 'big.bin').write_text('written meanwhile')
        out, err = proc.communicate(timeout=30)
        return proc.returncode, first + out + err, src, dest

    def test_copy_skip_keeps_intruder(self):
        rc, out, _, dest = self.slow_copy_with_intruder('skip')
        self.assertEqual(rc, 0, out)
        self.assertEqual((dest / 'big.bin').read_text(), 'written meanwhile')
        self.assertEqual([p.name for p in dest.iterdir()], ['big.bin'], 'no temporary left behind')

    def test_copy_rename_takes_next_name(self):
        rc, out, src, dest = self.slow_copy_with_intruder('rename')
        self.assertEqual(rc, 0, out)
        self.assertEqual((dest / 'big.bin').read_text(), 'written meanwhile')
        self.assertEqual((dest / 'big (1).bin').read_bytes(), src.read_bytes())

    def test_rename_never_replaces(self):
        a = self.home / 'a'; a.write_text('a')
        b = self.home / 'b'; b.write_text('b')
        self.cli_error('op', 'rename', str(a), '--name', 'b', code='already_exists')
        self.assertEqual(b.read_text(), 'b')

    def test_restore_does_not_overwrite(self):
        f = self.home / 'nota.txt'; f.write_text('vieja')
        self.cli_ok('op', 'trash', str(f))
        f.write_text('nueva')
        self.cli_ok('trash', 'restore', 'trash:///nota.txt')     # default policy: rename
        self.assertEqual(f.read_text(), 'nueva')
        self.assertEqual((self.home / 'nota (1).txt').read_text(), 'vieja')

    def test_restore_over_a_folder_of_that_name(self):
        f = self.home / 'cosa'; f.write_text('archivo')
        self.cli_ok('op', 'trash', str(f))
        f.mkdir()
        (f / 'dentro').write_text('x')
        self.cli_ok('trash', 'restore', 'trash:///cosa')
        self.assertEqual(sorted(p.name for p in f.iterdir()), ['dentro'], 'never moved inside the folder')
        self.assertEqual((self.home / 'cosa (1)').read_text(), 'archivo')


SHM = Path('/dev/shm')


@unittest.skipUnless(SHM.is_dir() and os.access(SHM, os.W_OK), 'a second filesystem (/dev/shm) is needed')
class CrossDeviceMove(AuditBase):
    """Hallazgo 5: moving between filesystems fell back to copy+delete on any error and, with overwrite, deleted
    the destination before knowing whether the move would work."""

    def setUp(self):
        super().setUp()
        self.other = Path(tempfile.mkdtemp(prefix='df-audit-', dir=SHM))
        self.addCleanup(lambda: subprocess.run(['rm', '-rf', '--', str(self.other)], check=False))
        if os.stat(self.other).st_dev == os.stat(self.home).st_dev:
            self.skipTest('/dev/shm is on the same filesystem')
        self.src = self.other / 'proj'
        (self.src / 'sub').mkdir(parents=True)
        (self.src / 'sub/a.txt').write_text('nuevo')
        (self.src / 'b.txt').write_text('nuevo b')
        self.dest = self.home / 'dest'
        self.dest.mkdir()

    def leftovers(self):
        return [p.name for p in self.dest.iterdir() if p.name.startswith('.dragon-')]

    def test_move_dir_between_filesystems(self):
        self.cli_ok('op', 'move', str(self.src), '--dest', str(self.dest))
        self.assertEqual((self.dest / 'proj/sub/a.txt').read_text(), 'nuevo')
        self.assertFalse(self.src.exists())
        self.assertEqual(self.leftovers(), [])

    def test_failed_copy_keeps_source_and_old_destination(self):
        old = self.dest / 'proj'
        old.mkdir()
        (old / 'antiguo.txt').write_text('no lo pierdas')
        locked = self.src / 'sub/a.txt'
        locked.chmod(0)
        self.addCleanup(locked.chmod, 0o644)
        if os.access(locked, os.R_OK):
            self.skipTest('running as root: permissions do not block reads')
        self.cli_error('op', 'move', str(self.src), '--dest', str(self.dest), '--conflict', 'overwrite')
        self.assertEqual((old / 'antiguo.txt').read_text(), 'no lo pierdas')
        self.assertTrue((self.src / 'b.txt').exists(), 'the source must survive a failed copy')
        self.assertEqual(self.leftovers(), [])

    def test_overwrite_replaces_only_after_success(self):
        old = self.dest / 'proj'
        old.mkdir()
        (old / 'antiguo.txt').write_text('x')
        self.cli_ok('op', 'move', str(self.src), '--dest', str(self.dest), '--conflict', 'overwrite')
        self.assertEqual(sorted(p.name for p in old.iterdir()), ['b.txt', 'sub'])
        self.assertEqual(self.leftovers(), [])
