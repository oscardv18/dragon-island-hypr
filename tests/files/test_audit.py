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


class SpecialFiles(AuditBase):
    """Hallazgo 6: copying a FIFO (or a device) blocked forever in open()."""

    def test_fifo_is_refused_fast(self):
        fifo = self.home / 'tuberia'
        os.mkfifo(fifo)
        dest = self.home / 'dest'; dest.mkdir()
        self.cli_error('op', 'copy', str(fifo), '--dest', str(dest), code='special_file', timeout=10)
        self.assertEqual(list(dest.iterdir()), [])

    def test_fifo_inside_a_folder(self):
        (self.home / 'd').mkdir()
        (self.home / 'd/ok.txt').write_text('x')
        os.mkfifo(self.home / 'd/tuberia')
        dest = self.home / 'dest'; dest.mkdir()
        self.cli_error('op', 'copy', str(self.home / 'd'), '--dest', str(dest), code='special_file', timeout=10)


@unittest.skipUnless(SHM.is_dir() and os.access(SHM, os.W_OK), 'a second filesystem (/dev/shm) is needed')
class TrashOtherDisk(AuditBase):
    """Hallazgo 7: trashing from another filesystem used shutil.move (any error → copy) with no space check."""

    def setUp(self):
        super().setUp()
        self.other = Path(tempfile.mkdtemp(prefix='df-audit-', dir=SHM))
        self.addCleanup(lambda: subprocess.run(['rm', '-rf', '--', str(self.other)], check=False))
        if os.stat(self.other).st_dev == os.stat(self.home).st_dev:
            self.skipTest('/dev/shm is on the same filesystem')

    def test_trash_and_restore_from_other_disk(self):
        d = self.other / 'carpeta'
        d.mkdir()
        (d / 'f.txt').write_text('x')
        self.cli_ok('op', 'trash', str(d))
        self.assertFalse(d.exists())
        self.assertEqual((self.trash / 'files/carpeta/f.txt').read_text(), 'x')
        self.assertEqual([p.name for p in (self.trash / 'files').iterdir() if p.name.startswith('.dragon-')], [])
        self.cli_ok('trash', 'restore', 'trash:///carpeta')
        self.assertEqual((d / 'f.txt').read_text(), 'x')

    def test_failed_copy_keeps_original_and_no_trashinfo(self):
        d = self.other / 'bloqueada'
        d.mkdir()
        (d / 'f.txt').write_text('x')
        (d / 'f.txt').chmod(0)
        self.addCleanup((d / 'f.txt').chmod, 0o644)
        if os.access(d / 'f.txt', os.R_OK):
            self.skipTest('running as root')
        self.cli_error('op', 'trash', str(d))
        self.assertTrue((d / 'f.txt').exists())
        self.assertEqual(list((self.trash / 'info').glob('*.trashinfo')), [])
        self.assertEqual(list((self.trash / 'files').iterdir()), [], 'no half-copied folder left in the trash')


class EventDrivenWatch(AuditBase):
    """Hallazgo 8: `watch` re-read the folder and `devices --watch` ran lsblk every second even with inotify/udev."""

    def shim(self, name, body):
        shims = self.home / 'shims'
        shims.mkdir(exist_ok=True)
        f = shims / name
        f.write_text('#!/bin/sh\n' + body)
        f.chmod(0o755)
        return dict(self.env, PATH=f"{shims}:{self.env['PATH']}")

    def run_for(self, args, env, seconds, during=None):
        proc = subprocess.Popen([str(BIN), *args, '--json'], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            if during:
                import time
                time.sleep(0.6)
                during()
            proc.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            proc.terminate()
        out, _ = proc.communicate(timeout=5)
        return out

    def test_watch_trusts_inotify(self):
        folder = self.home / 'carpeta'
        folder.mkdir()
        # a silent inotifywait: with inotify alive, a change it does not report must not be found by polling
        env = self.shim('inotifywait', 'exec sleep 30\n')
        out = self.run_for(['watch', str(folder)], env, 3.0, during=lambda: (folder / 'nuevo').write_text('x'))
        self.assertNotIn('changed', out)

    def test_watch_reports_inotify_events(self):
        folder = self.home / 'carpeta'
        folder.mkdir()
        env = self.shim('inotifywait', 'sleep 1; echo "$4 CREATE nuevo"; exec sleep 30\n')
        out = self.run_for(['watch', str(folder)], env, 3.0)
        self.assertIn('changed', out)

    def test_watch_polls_without_inotify(self):
        folder = self.home / 'carpeta'
        folder.mkdir()
        env = self.shim('inotifywait', 'exit 1\n')
        out = self.run_for(['watch', str(folder)], env, 3.0, during=lambda: (folder / 'nuevo').write_text('x'))
        self.assertIn('changed', out)

    def test_devices_watch_does_not_poll_lsblk(self):
        calls = self.home / 'lsblk-calls'
        env = self.shim('lsblk', f'echo x >> "{calls}"; echo \'{{"blockdevices": []}}\'\n')
        env = dict(env, PATH=env['PATH'])
        (self.home / 'shims/udevadm').write_text('#!/bin/sh\nexec sleep 30\n')
        (self.home / 'shims/udevadm').chmod(0o755)
        (self.home / 'shims/gio').write_text('#!/bin/sh\nexit 0\n')
        (self.home / 'shims/gio').chmod(0o755)
        self.run_for(['devices', '--watch'], env, 4.0)
        n = len(calls.read_text().splitlines()) if calls.exists() else 0
        self.assertLessEqual(n, 2, f'lsblk ran {n} times in 4 s with udev alive')


class OddNames(AuditBase):
    """Hallazgo 9: names starting with '-' (rejected by argparse) and names with line breaks."""

    def test_rename_and_mkdir_to_dash_names(self):
        f = self.home / 'nota.txt'; f.write_text('x')
        self.cli_ok('op', 'rename', str(f), '--name', '-borrador.txt')
        self.assertTrue((self.home / '-borrador.txt').exists())
        self.cli_ok('op', 'mkdir', str(self.home), '--name', '--raro')
        self.assertTrue((self.home / '--raro').is_dir())

    def test_dash_value_never_eats_a_real_option(self):
        f = self.home / 'nota.txt'; f.write_text('x')
        self.cli_error('op', 'rename', str(f), '--name', code='invalid_usage')   # `--json` follows: still an option

    def test_line_breaks_round_trip(self):
        f = self.home / 'a'; f.write_text('x')
        weird = 'línea 1\nlínea 2'
        self.cli_ok('op', 'rename', str(f), '--name', weird)
        listing = self.cli_ok('ls', str(self.home))
        self.assertIn(weird, [e['name'] for e in listing['entries']])
        dest = self.home / 'dest'; dest.mkdir()
        self.cli_ok('op', 'copy', str(self.home / weird), '--dest', str(dest), '--json-progress')
        self.cli_ok('op', 'trash', str(dest / weird))
        listing = self.cli_ok('ls', 'trash:///')
        self.cli_ok('trash', 'restore', listing['entries'][0]['uri'])
        self.assertTrue((dest / weird).exists())

    def test_dash_paths_after_double_dash(self):
        (self.home / '-x').write_text('x')
        dest = self.home / 'dest'; dest.mkdir()
        p = subprocess.run([str(BIN), 'op', 'copy', '--dest', str(dest), '--json', '--', str(self.home / '-x')],
                           env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertTrue((dest / '-x').exists())


class LongNames(AuditBase):
    """Hallazgo 10: the copy temporary `.dragon-part-<name>-XXXX` went over 255 bytes for long names."""

    def test_copy_255_byte_name(self):
        name = 'x' * 251 + '.txt'
        (self.home / name).write_text('x')
        dest = self.home / 'dest'; dest.mkdir()
        self.cli_ok('op', 'copy', str(self.home / name), '--dest', str(dest))
        self.cli_ok('op', 'copy', str(self.home / name), '--dest', str(dest), '--conflict', 'overwrite')
        self.assertEqual([p.name for p in dest.iterdir()], [name])


class UnexpectedErrors(AuditBase):
    """Hallazgo 11: an unexpected exception (RecursionError, ValueError…) printed a traceback instead of JSON."""

    def test_unexpected_exception_is_json(self):
        code = ('import sys; sys.path.insert(0, sys.argv[1]); import dragon_files as d\n'
                'def boom(args): raise ValueError("secreto ghp_abcdefghijklmnopqrstuvwxyz0123456789")\n'
                'd.cmd_ls = boom; sys.argv = ["dragon-files", "ls", sys.argv[2], "--json"]; d.run_cli()')
        p = subprocess.run(['python3', '-S', '-c', code, str(ROOT / 'dragon-core'), str(self.home)], env=self.env,
                           capture_output=True, text=True, timeout=15)
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertNotIn('Traceback', p.stdout + p.stderr)
        res = json.loads(p.stdout.strip().splitlines()[-1])
        self.assertEqual(res['error']['code'], 'internal_error')
        self.assertNotIn('ghp_', p.stdout, 'the exception text (which may carry secrets) is not echoed')


class ThumbnailDemuxers(AuditBase):
    """Hallazgo 12: ffmpeg probed untrusted files freely (an HLS/concat «image» can pull other local files in)."""

    def test_ffmpeg_formats_are_pinned(self):
        shims = self.home / 'shims'; shims.mkdir()
        log = self.home / 'ffmpeg-args'
        (shims / 'ffmpeg').write_text(f'#!/bin/sh\nprintf "%s\\n" "$*" >> "{log}"\nexit 1\n')
        (shims / 'ffmpeg').chmod(0o755)
        for other in ('vipsthumbnail', 'magick', 'convert', 'ffmpegthumbnailer', 'pdftoppm'):
            (shims / other).write_text('#!/bin/sh\nexit 1\n')
            (shims / other).chmod(0o755)
        env = dict(self.env, PATH=f"{shims}:{self.env['PATH']}")
        (self.home / 'foto.png').write_text('#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:1,\nfile:///etc/passwd\n')
        (self.home / 'clip.mp4').write_bytes(b'\0' * 64)
        self.run_cli('thumb', str(self.home / 'foto.png'), env=env)
        self.run_cli('thumb', str(self.home / 'clip.mp4'), env=env)
        calls = log.read_text().splitlines()
        self.assertEqual(len(calls), 2, calls)
        self.assertIn('-f image2 -i', calls[0])
        self.assertIn('-format_whitelist', calls[1])
        self.assertNotIn('hls', calls[1].split('-format_whitelist ')[1].split(' ')[0])


class OpenWithIds(AuditBase):
    """Hallazgo 13: `open-with --app ../../x` joined the id to each applications folder and escaped it."""

    def test_path_like_ids_are_refused(self):
        evil = self.outside / 'evil.desktop'
        marker = self.outside / 'ran'
        evil.write_text(f'[Desktop Entry]\nType=Application\nName=x\nExec=touch {marker}\n')
        target = self.home / 'f.txt'; target.write_text('x')
        apps = self.home / 'data/applications'; apps.mkdir(parents=True)
        rel = os.path.relpath(self.outside / 'evil', apps)
        for app in (rel, '/usr/bin/touch', 'a/../b'):
            self.cli_error('open-with', str(target), '--app', app, code='invalid_app')
        self.assertFalse(marker.exists())


class TrashInfoPaths(AuditBase):
    """Hallazgo 14: a relative Path= in .trashinfo was restored relative to the current directory."""

    def test_relative_path_goes_home(self):
        (self.trash / 'files').mkdir(parents=True)
        (self.trash / 'info').mkdir(parents=True)
        (self.trash / 'files/nota.txt').write_text('x')
        (self.trash / 'info/nota.txt.trashinfo').write_text('[Trash Info]\nPath=sub/nota.txt\nDeletionDate=2026-01-01T00:00:00\n')
        p = subprocess.run([str(BIN), 'trash', 'restore', 'trash:///nota.txt', '--json'], env=self.env, cwd=self.outside,
                           capture_output=True, text=True, timeout=15)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertTrue((self.home / 'nota.txt').exists())
        self.assertEqual(list(self.outside.iterdir()), [])
