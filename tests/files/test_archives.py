"""Malicious archives are generated locally; no remote input or real mounts."""
import contextlib
import importlib
import io
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dragon-core'))
import files_archives as archives
import dragon_files as api
from taller_common import ToolError

class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.dest = self.home / 'dest'
        self.dest.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PYTHONDONTWRITEBYTECODE='1')
        for key in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
            self.env['XDG_' + key + '_HOME'] = str(self.home / key.lower())

    def tearDown(self):
        self.tmp.cleanup()

    def zip(self, name, data=b'hello'):
        path = self.home / 'input.zip'
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
            z.writestr(name, data)
        return path

    def tar(self, name, kind=tarfile.REGTYPE, link='', mode=0o644):
        path = self.home / 'input.tar'
        with tarfile.open(path, 'w') as tar:
            ent = tarfile.TarInfo(name)
            ent.type, ent.linkname, ent.mode = kind, link, mode
            ent.size = 5 if kind == tarfile.REGTYPE else 0
            tar.addfile(ent, io.BytesIO(b'hello') if ent.size else None)
        return path

    def cli(self, *args, stdin='', ok=True):
        p = subprocess.run([str(ROOT / 'bin/dragon-files'), 'archive', *map(str,args)],
                           env=self.env, input=stdin, capture_output=True, text=True, timeout=20)
        self.assertEqual(p.returncode, 0 if ok else 1, p.stdout + p.stderr)
        return [json.loads(line) for line in p.stdout.splitlines()][-1]

    def reject(self, path, code='unsafe_paths'):
        result = self.cli('extract', path, '--dest', self.dest, '--json-progress', ok=False)
        self.assertEqual(result['error']['code'], code, result)
        self.assertEqual(list(self.dest.iterdir()), [])

    def test_zip_slip(self):
        self.reject(self.zip('../escape'))
        self.assertFalse((self.home / 'escape').exists())

    def test_absolute_path(self):
        self.reject(self.tar(str(self.home / 'escape')))

    def test_windows_path(self):
        self.reject(self.zip('C:\\escape'))

    def test_control_characters(self):
        for char in ('\n', '\r', '\x1b', '\x7f', '\x85'):
            with self.subTest(char=repr(char)):
                self.reject(self.zip('bad' + char + 'file'))

    def test_symlink_escape(self):
        self.reject(self.tar('escape', tarfile.SYMTYPE, '../outside'))

    def test_hardlink_escape(self):
        self.reject(self.tar('escape', tarfile.LNKTYPE, '/etc/passwd'))

    def test_device_and_fifo(self):
        for kind in (tarfile.CHRTYPE, tarfile.BLKTYPE, tarfile.FIFOTYPE):
            with self.subTest(kind=kind):
                self.reject(self.tar('special', kind))

    def test_strip_setuid_setgid(self):
        path = self.tar('privileged', mode=0o6755)
        self.cli('extract', path, '--dest', self.dest)
        self.assertEqual(stat.S_IMODE((self.dest / 'privileged').stat().st_mode), 0o755)

    def test_bomb_small_fixture_and_confirm(self):
        path = self.zip('bomb', b'\0' * (1024 * 1024))
        args = api.build_parser().parse_args(['archive','extract',str(path),'--dest',str(self.dest)])
        # Lower only the absolute threshold: the real 200:1 ratio is exercised.
        with patch.object(archives, 'BOMB_SIZE', 1024), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(ToolError) as caught:
                archives.extract(args, api)
            self.assertEqual(caught.exception.code, 'bomb_suspected')
            self.assertEqual(list(self.dest.iterdir()), [])
            args.confirm_bomb = True
            archives.extract(args, api)
        self.assertEqual((self.dest / 'bomb').stat().st_size, 1024 * 1024)

    def test_no_space(self):
        path = self.zip('big', b'x' * 8192)
        args = api.build_parser().parse_args(['archive','extract',str(path),'--dest',str(self.dest)])
        usage = type('Usage', (), {'free': 4096})()
        with patch.object(archives.shutil, 'disk_usage', return_value=usage):
            with self.assertRaises(ToolError) as caught:
                archives.extract(args, api)
            self.assertEqual(caught.exception.code, 'no_space')
        self.assertEqual(list(self.dest.iterdir()), [])

    def test_staging_no_partial_publish_and_duplicate_paths(self):
        path = self.home / 'input.zip'
        with zipfile.ZipFile(path, 'w') as z:
            z.writestr('good', 'keep private until all valid')
            z.writestr('../bad', 'x')
        self.reject(path)
        with zipfile.ZipFile(path, 'w') as z:
            z.writestr('a/../b', 'x')
        self.reject(path)

    def test_nested_symlink_write(self):
        path = self.home / 'input.tar'
        with tarfile.open(path, 'w') as tar:
            link = tarfile.TarInfo('link'); link.type=tarfile.SYMTYPE; link.linkname='safe'
            tar.addfile(link)
            ent = tarfile.TarInfo('link/child'); ent.size=1
            tar.addfile(ent, io.BytesIO(b'x'))
        self.reject(path)

    def test_existing_destination_symlink_not_followed(self):
        outside = self.home / 'outside'; outside.mkdir()
        (self.dest / 'folder').symlink_to(outside, target_is_directory=True)
        self.cli('extract', self.zip('folder/child'), '--dest', self.dest, '--conflict', 'overwrite')
        self.assertEqual(list(outside.iterdir()), [])
        self.assertEqual((self.dest / 'folder/child').read_text(), 'hello')

    def test_conflict_stdin_rename_and_skip(self):
        path = self.zip('file')
        (self.dest / 'file').write_text('old')
        self.cli('extract', path, '--dest', self.dest, stdin='{"answer":"rename"}\n')
        self.assertEqual((self.dest / 'file').read_text(), 'old')
        self.assertTrue(any(p.name != 'file' for p in self.dest.iterdir()))
        self.assertFalse(any(p.name.startswith('.dragon-extract') for p in self.dest.iterdir()))

    def test_cancel_cleans_staging_before_publish(self):
        path = self.zip('file')
        (self.dest / 'file').write_text('old')
        proc = subprocess.Popen([str(ROOT / 'bin/dragon-files'), 'archive','extract',str(path),
                                 '--dest',str(self.dest)], env=self.env, stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, text=True)
        try:
            for line in proc.stdout:
                if json.loads(line).get('t') == 'conflict':
                    break
            proc.send_signal(signal.SIGTERM)
            proc.wait(timeout=5)
            self.assertEqual([p.name for p in self.dest.iterdir()], ['file'])
            self.assertEqual((self.dest / 'file').read_text(), 'old')
        finally:
            if proc.poll() is None: proc.kill(); proc.wait()
            proc.stdin.close(); proc.stdout.close()

    def test_list_test_and_create_formats(self):
        source = self.home / 'source'; source.write_text('hello')
        for fmt in ('zip', '7z', 'tar.gz', 'tar.xz', 'tar.zst'):
            with self.subTest(fmt=fmt):
                out = self.home / ('out.' + fmt)
                self.cli('create','--format',fmt,'--out',out,'--paths',source,'--json-progress')
                res = self.cli('list',out,'--json')
                self.assertEqual(res['count'], 1)
                self.assertEqual(res['total_size'], 5)
                self.cli('test',out)
                self.cli('extract',out,'--dest',self.dest,'--conflict','overwrite')
                self.assertEqual((self.dest / 'source').read_text(),'hello')

    def test_password_only_stdin(self):
        # Produce an encrypted ZIP locally; fixture generator argv is not the adapter.
        src = self.home / 'secret'; src.write_text('payload')
        path = self.home / 'secret.zip'
        subprocess.run(['7z','a','-tzip','-pfixture-pass',str(path),str(src)],
                       check=True, stdout=subprocess.DEVNULL)
        self.reject(path, 'password_required')
        result = self.cli('extract',path,'--dest',self.dest,'--password-stdin',
                          stdin='wrong\n',ok=False)
        self.assertEqual(result['error']['code'],'bad_password')
        result = self.cli('extract',path,'--dest',self.dest,'--password-stdin',stdin='fixture-pass\n')
        self.assertNotIn('fixture-pass',str(result))
        self.assertEqual((self.dest / 'secret').read_text(),'payload')
