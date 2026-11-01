"""Tests for dragon-files (d1: ls, places, watch, props, open, open-with, terminal-here, thumb) in temp HOME/XDG."""
import hashlib
import json
import os
from pathlib import Path
import select
import stat
import struct
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / 'bin/dragon-files'


def make_jpeg_with_exif(width=4032, height=3024):
    # Minimal valid JPEG with APP1 Exif (Make, Model, DateTimeOriginal, ExposureTime, FNumber, ISO, FocalLength) + SOF0
    endian = '<'
    make = b'Google\x00'
    model = b'Pixel 8\x00'
    dt = b'2026:10:22 17:12:00\x00'
    # TIFF header (8 bytes): 'II', 42, offset to IFD0 = 8
    # IFD0: 3 entries (Make 0x010F, Model 0x0110, ExifIFD 0x8769) -> 2 + 3*12 + 4 = 42 bytes (ends at offset 50)
    # Data after IFD0:
    #   offset 50: make (7 bytes -> pad to 8: offset 58)
    #   offset 58: model (8 bytes -> ends at 66)
    #   offset 66: ExifIFD: 5 entries (DateTimeOriginal 0x9003, ExposureTime 0x829A, FNumber 0x829D, ISO 0x8827, FocalLength 0x920A)
    #     2 + 5*12 + 4 = 66 bytes (ends at 132)
    #   offset 132: dt (20 bytes -> ends at 152)
    #   offset 152: exp rational (1, 250) (8 bytes -> 160)
    #   offset 160: fnum rational (17, 10) (8 bytes -> 168)
    #   offset 168: focal rational (69, 10) (8 bytes -> 176)
    tiff = bytearray(176)
    tiff[0:2] = b'II'
    struct.pack_into('<HI', tiff, 2, 42, 8)
    struct.pack_into('<H', tiff, 8, 3)
    struct.pack_into('<HHII', tiff, 10, 0x010F, 2, len(make), 50)
    struct.pack_into('<HHII', tiff, 22, 0x0110, 2, len(model), 58)
    struct.pack_into('<HHII', tiff, 34, 0x8769, 4, 1, 66)
    tiff[50:50 + len(make)] = make
    tiff[58:58 + len(model)] = model
    struct.pack_into('<H', tiff, 66, 5)
    struct.pack_into('<HHII', tiff, 68, 0x9003, 2, len(dt), 132)
    struct.pack_into('<HHII', tiff, 80, 0x829A, 5, 1, 152)
    struct.pack_into('<HHII', tiff, 92, 0x829D, 5, 1, 160)
    struct.pack_into('<HHII', tiff, 104, 0x8827, 3, 1, 64)
    struct.pack_into('<HHII', tiff, 116, 0x920A, 5, 1, 168)
    tiff[132:132 + len(dt)] = dt
    struct.pack_into('<II', tiff, 152, 1, 250)
    struct.pack_into('<II', tiff, 160, 17, 10)
    struct.pack_into('<II', tiff, 168, 69, 10)

    app1_payload = b'Exif\x00\x00' + bytes(tiff)
    app1 = b'\xff\xe1' + struct.pack('>H', len(app1_payload) + 2) + app1_payload
    sof0_payload = struct.pack('>BHHB', 8, height, width, 3) + b'\x01\x11\x00\x02\x11\x00\x03\x11\x00'
    sof0 = b'\xff\xc0' + struct.pack('>H', len(sof0_payload) + 2) + sof0_payload
    return b'\xff\xd8' + app1 + sof0 + b'\xff\xd9'


def make_png(width=64, height=48):
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + ihdr + b'\x00\x00\x00\x00'


class FilesD1Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='df-')
        self.home = Path(self.tmp.name)
        self.env = dict(os.environ, HOME=str(self.home), PYTHONDONTWRITEBYTECODE='1', TZ='UTC')
        for key in ('CONFIG', 'DATA', 'STATE', 'CACHE', 'RUNTIME'):
            p = self.home / key.lower()
            p.mkdir(mode=0o700, exist_ok=True)
            self.env['XDG_' + key + ('_DIR' if key == 'RUNTIME' else '_HOME')] = str(p)

    def tearDown(self):
        self.tmp.cleanup()

    def cli(self, *args, ok=True, env=None):
        p = subprocess.run(
            [str(BIN), *args, '--json'],
            env=env or self.env,
            capture_output=True,
            text=True,
            timeout=15,
        )
        self.assertEqual(p.returncode, 0 if ok else 1, p.stdout + p.stderr)
        res = json.loads(p.stdout)
        self.assertEqual(res.get('ok'), ok, res)
        return res

    def test_ls_5000_entries_sorting_links_and_counts(self):
        big = self.home / 'big'
        big.mkdir()
        for i in range(5000):
            (big / f'item-{i}.txt').write_text('x', encoding='utf-8')
        res = self.cli('ls', str(big), '--sort', 'name', '--dirs-first')
        self.assertEqual(len(res['entries']), 5000)
        self.assertEqual(res['entries'][0]['name'], 'item-0.txt')
        self.assertEqual(res['entries'][2]['name'], 'item-2.txt')
        self.assertEqual(res['entries'][10]['name'], 'item-10.txt')
        self.assertGreater(res['total'], 0)
        self.assertTrue(res['fs'])

        limited = self.cli('ls', str(big), '--limit', '15')
        self.assertEqual(len(limited['entries']), 15)

        weird = self.home / 'weird'
        weird.mkdir()
        sub = weird / 'carpeta ñ'
        sub.mkdir()
        (sub / 'uno.txt').write_text('1', encoding='utf-8')
        (sub / 'dos.txt').write_text('2', encoding='utf-8')
        (weird / '.oculto').write_text('secreto', encoding='utf-8')
        (weird / 'archivo [1] "raro".md').write_text('# título\n', encoding='utf-8')
        (weird / 'roto').symlink_to(weird / 'no-existe')
        (weird / 'enlace-dir').symlink_to(sub)

        no_hidden = self.cli('ls', str(weird), '--sort', 'name', '--dirs-first')
        names = [e['name'] for e in no_hidden['entries']]
        self.assertNotIn('.oculto', names)
        self.assertEqual(names[0], 'carpeta ñ')

        with_hidden = self.cli('ls', str(weird), '--sort', 'name', '--dirs-first', '--hidden')
        by_name = {e['name']: e for e in with_hidden['entries']}
        self.assertIn('.oculto', by_name)
        self.assertTrue(by_name['.oculto']['hidden'])
        self.assertEqual(by_name['carpeta ñ']['count'], 2)
        self.assertEqual(by_name['roto']['kind'], 'link')
        self.assertTrue(by_name['roto']['broken'])
        self.assertFalse(by_name['roto']['link_dir'])
        self.assertIsNone(by_name['roto']['mime'])
        self.assertEqual(by_name['enlace-dir']['kind'], 'link')
        self.assertFalse(by_name['enlace-dir']['broken'])
        self.assertTrue(by_name['enlace-dir']['link_dir'])
        self.assertEqual(by_name['enlace-dir']['count'], 2)

    def test_ls_errors_and_permissions(self):
        err = self.cli('ls', str(self.home / 'inexistente'), ok=False)
        self.assertEqual(err['error']['code'], 'not_found')

        f = self.home / 'archivo.txt'
        f.write_text('hola', encoding='utf-8')
        err2 = self.cli('ls', str(f), ok=False)
        self.assertEqual(err2['error']['code'], 'not_a_directory')

        if os.geteuid() != 0:
            locked_dir = self.home / 'sin-permiso'
            locked_dir.mkdir(mode=0o000)
            try:
                err3 = self.cli('ls', str(locked_dir), ok=False)
                self.assertEqual(err3['error']['code'], 'permission_denied')
            finally:
                locked_dir.chmod(0o700)

    def test_ls_git_and_trash(self):
        repo = self.home / 'repo'
        repo.mkdir()
        git_env = dict(
            self.env,
            GIT_CONFIG_NOSYSTEM='1',
            GIT_AUTHOR_NAME='Test',
            GIT_AUTHOR_EMAIL='t@example.org',
            GIT_COMMITTER_NAME='Test',
            GIT_COMMITTER_EMAIL='t@example.org',
        )
        subprocess.run(['git', '-C', str(repo), 'init', '-b', 'main'], env=git_env, check=True, capture_output=True)
        (repo / 'arquitectura.md').write_text('v1\n', encoding='utf-8')
        subprocess.run(['git', '-C', str(repo), 'add', 'arquitectura.md'], env=git_env, check=True, capture_output=True)
        subprocess.run(['git', '-C', str(repo), 'commit', '-m', 'init'], env=git_env, check=True, capture_output=True)

        (repo / 'arquitectura.md').write_text('v2\n', encoding='utf-8')
        (repo / 'diagrama.svg').write_text('<svg/>', encoding='utf-8')
        subprocess.run(['git', '-C', str(repo), 'add', 'diagrama.svg'], env=git_env, check=True, capture_output=True)
        (repo / 'nuevo.txt').write_text('sin seguimiento\n', encoding='utf-8')

        res = self.cli('ls', str(repo), '--git')
        marks = {e['name']: e['git'] for e in res['entries']}
        self.assertEqual(marks['arquitectura.md'], 'M')
        self.assertEqual(marks['diagrama.svg'], 'A')
        self.assertEqual(marks['nuevo.txt'], '?')

        # Trash listing in isolated XDG_DATA_HOME
        tfiles = Path(self.env['XDG_DATA_HOME']) / 'Trash/files'
        tinfo = Path(self.env['XDG_DATA_HOME']) / 'Trash/info'
        tfiles.mkdir(parents=True)
        tinfo.mkdir(parents=True)
        (tfiles / 'borrado.txt').write_text('papelera', encoding='utf-8')
        (tinfo / 'borrado.txt.trashinfo').write_text(
            '[Trash Info]\nPath=/home/test/borrado.txt\nDeletionDate=2026-10-30T14:20:00\n',
            encoding='utf-8',
        )
        tres = self.cli('ls', 'trash:///')
        self.assertEqual(len(tres['entries']), 1)
        self.assertEqual(tres['entries'][0]['name'], 'borrado.txt')
        self.assertEqual(tres['entries'][0]['uri'], 'trash:///borrado.txt')
        self.assertEqual(tres['entries'][0]['orig_path'], '/home/test/borrado.txt')

    def test_places_xdg_bookmarks_projects_and_trash(self):
        cfg = Path(self.env['XDG_CONFIG_HOME'])
        (self.home / 'Escritorio').mkdir()
        (self.home / 'Descargas').mkdir()
        (self.home / 'Descargas/a.zip').write_text('1', encoding='utf-8')
        (self.home / 'Descargas/b.pdf').write_text('2', encoding='utf-8')
        (cfg / 'user-dirs.dirs').write_text(
            'XDG_DESKTOP_DIR="$HOME/Escritorio"\nXDG_DOWNLOAD_DIR="$HOME/Descargas"\n',
            encoding='utf-8',
        )
        gtk_dir = cfg / 'gtk-3.0'
        gtk_dir.mkdir(parents=True)
        bm_folder = self.home / 'Notas'
        bm_folder.mkdir()
        (gtk_dir / 'bookmarks').write_text(f'{bm_folder.as_uri()} Mis Notas\n', encoding='utf-8')

        # Register a project in dragon-mem
        proj_dir = self.home / 'arxnet-erp'
        proj_dir.mkdir()
        subprocess.run(['git', '-C', str(proj_dir), 'init'], env=self.env, check=True, capture_output=True)
        subprocess.run(
            [str(ROOT / 'bin/dragon-mem'), 'project', 'add', '--path', str(proj_dir), '--name', 'ArxNet', '--json'],
            env=self.env,
            check=True,
            capture_output=True,
        )

        # Add a custom bookmark via dragon-files places add
        custom_dir = self.home / 'Diseños'
        custom_dir.mkdir()
        res = self.cli('places', 'add', str(custom_dir), '--label', 'Arte')
        by_label = {p['label']: p for p in res['places']}
        self.assertIn('Inicio', by_label)
        self.assertIn('Escritorio', by_label)
        self.assertEqual(by_label['Descargas']['badge'], 2)
        self.assertIn('Mis Notas', by_label)
        self.assertIn('ArxNet', by_label)
        self.assertTrue(by_label['ArxNet']['repo'])
        self.assertIn('Arte', by_label)
        self.assertIn('Papelera', by_label)

        # Remove bookmark
        after = self.cli('places', 'rm', str(custom_dir))
        self.assertNotIn('Arte', {p['label'] for p in after['places']})

    def test_props_files_dirs_links_and_images(self):
        folder = self.home / 'docs'
        folder.mkdir()
        sub = folder / 'sub'
        sub.mkdir()
        (sub / 'datos.bin').write_bytes(b'x' * 1024)
        photo = folder / 'foto.jpg'
        photo.write_bytes(make_jpeg_with_exif(4032, 3024))
        png = folder / 'icono.png'
        png.write_bytes(make_png(128, 96))

        p_dir = self.cli('props', str(folder))
        self.assertEqual(p_dir['kind'], 'dir')
        self.assertEqual(p_dir['dir_count'], 4)
        self.assertGreaterEqual(p_dir['dir_size'], 1024)
        self.assertFalse(p_dir['truncated'])
        self.assertEqual(len(p_dir['perms']), 9)

        p_trunc = self.cli('props', str(folder), '--max-entries', '2')
        self.assertTrue(p_trunc['truncated'])

        p_jpg = self.cli('props', str(photo))
        self.assertEqual(p_jpg['mime'], 'image/jpeg')
        self.assertEqual(p_jpg['image']['width'], 4032)
        self.assertEqual(p_jpg['image']['height'], 3024)
        self.assertEqual(p_jpg['image']['camera'], 'Pixel 8')
        self.assertEqual(p_jpg['image']['exposure'], '1/250 s · f/1.7 · ISO 64')
        self.assertEqual(p_jpg['image']['lens'], '6,9 mm')
        self.assertIsInstance(p_jpg['image']['taken'], int)

        p_png = self.cli('props', str(png))
        self.assertEqual(p_png['image'], {'width': 128, 'height': 96})

    def test_thumb_cache_generation_and_missing_tool_fallback(self):
        img = self.home / 'muestra.png'
        img.write_bytes(make_png(200, 200))

        # Without thumbnailer tools in an empty PATH (only python3/sh), returns thumb=None cleanly
        minimal_bin = self.home / 'minbin'
        minimal_bin.mkdir()
        for cmd in ('python3', 'bash', 'readlink', 'dirname'):
            real = subprocess.run(['which', cmd], capture_output=True, text=True, check=True).stdout.strip()
            (minimal_bin / cmd).symlink_to(real)
        no_tool_env = dict(self.env, PATH=str(minimal_bin))
        res_none = self.cli('thumb', str(img), '--size', 'large', env=no_tool_env)
        self.assertIsNone(res_none['thumb'])

        # With a shim vipsthumbnail in PATH, generates once and reuses cache on second call
        shims = self.home / 'shims'
        shims.mkdir()
        calls_log = self.home / 'thumb-calls.log'
        shim = shims / 'vipsthumbnail'
        shim.write_text(
            '#!/usr/bin/env python3\n'
            'import sys\n'
            'from pathlib import Path\n'
            f'Path({str(calls_log)!r}).open("a").write("called\\n")\n'
            'out = sys.argv[sys.argv.index("-o") + 1]\n'
            'Path(out).write_bytes(b"\\x89PNG\\r\\n\\x1a\\nfake")\n',
            encoding='utf-8',
        )
        shim.chmod(0o755)
        shim_env = dict(self.env, PATH=f"{shims}:{self.env['PATH']}")

        res1 = self.cli('thumb', str(img), '--size', 'large', env=shim_env)
        expected_md5 = hashlib.md5(img.resolve().as_uri().encode('utf-8')).hexdigest()
        expected_path = Path(self.env['XDG_CACHE_HOME']) / 'thumbnails/large' / f'{expected_md5}.png'
        self.assertEqual(res1['thumb'], str(expected_path))
        self.assertTrue(expected_path.is_file())
        self.assertEqual(stat.S_IMODE(expected_path.stat().st_mode), 0o600)
        self.assertEqual(len(calls_log.read_text().splitlines()), 1)

        # Second call hits cache without calling vipsthumbnail again
        res2 = self.cli('thumb', str(img), '--size', 'large', env=shim_env)
        self.assertEqual(res2['thumb'], str(expected_path))
        self.assertEqual(len(calls_log.read_text().splitlines()), 1)

    def test_open_open_with_and_terminal_here(self):
        doc = self.home / 'nota.txt'
        doc.write_text('hola', encoding='utf-8')
        apps_dir = Path(self.env['XDG_DATA_HOME']) / 'applications'
        apps_dir.mkdir(parents=True)
        log_file = self.home / 'launched.log'

        shims = self.home / 'bin'
        shims.mkdir()
        for name in ('xdg-open', 'mi-editor', 'ghostty'):
            script = shims / name
            script.write_text(
                '#!/usr/bin/env python3\n'
                'import json, os, sys\n'
                f'open({str(log_file)!r}, "a").write(json.dumps(["{name}", sys.argv[1:], os.getcwd()]) + "\\n")\n',
                encoding='utf-8',
            )
            script.chmod(0o755)

        (apps_dir / 'mi-editor.desktop').write_text(
            '[Desktop Entry]\nType=Application\nName=Mi Editor\nExec=mi-editor %f\nMimeType=text/plain;\n',
            encoding='utf-8',
        )
        env = dict(self.env, PATH=f"{shims}:{self.env['PATH']}", XDG_DATA_DIRS='/nonexistent')

        apps = self.cli('open-with', str(doc), '--list', env=env)
        self.assertEqual(apps['apps'], [{'id': 'mi-editor.desktop', 'name': 'Mi Editor', 'default': True}])

        self.cli('open', str(doc), env=env)
        self.cli('open-with', str(doc), '--app', 'mi-editor.desktop', env=env)
        self.cli('terminal-here', str(doc), env=env)

        deadline = time.time() + 2.0
        while time.time() < deadline:
            if log_file.is_file() and len(log_file.read_text().splitlines()) >= 3:
                break
            time.sleep(0.05)
        records = [json.loads(line) for line in log_file.read_text().splitlines()]
        self.assertIn(['xdg-open', [str(doc)], os.getcwd()], records)
        self.assertIn(['mi-editor', [str(doc)], os.getcwd()], records)
        self.assertIn(['ghostty', [f'--working-directory={self.home}'], str(self.home)], records)

    def test_watch_polling_and_inotify_child_cleanup(self):
        watched = self.home / 'watched'
        watched.mkdir()

        # 1. Polling fallback (no inotifywait)
        p = subprocess.Popen(
            [str(BIN), 'watch', str(watched)],
            env=self.env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            time.sleep(0.2)
            (watched / 'nuevo.txt').write_text('hola', encoding='utf-8')
            ready, _, _ = select.select([p.stdout], [], [], 3.0)
            self.assertTrue(ready, 'watch did not emit change event')
            ev = json.loads(p.stdout.readline())
            self.assertEqual(ev['t'], 'changed')
            self.assertEqual(ev['path'], str(watched))
            p.terminate()
            p.communicate(timeout=3)
            self.assertEqual(p.returncode, 0)
        finally:
            if p.poll() is None:
                p.kill()
                p.communicate()

        # 2. inotifywait path + child cleanup on SIGTERM
        helpers = self.home / 'inotify-bin'
        helpers.mkdir()
        pid_file = self.home / 'inotify.pid'
        fake_inotify = helpers / 'inotifywait'
        fake_inotify.write_text(
            '#!/usr/bin/env python3\n'
            'import os, time\n'
            'from pathlib import Path\n'
            f'Path({str(pid_file)!r}).write_text(str(os.getpid()))\n'
            'time.sleep(0.2)\n'
            'print("CREATE nuevo", flush=True)\n'
            'time.sleep(30)\n',
            encoding='utf-8',
        )
        fake_inotify.chmod(0o755)
        ienv = dict(self.env, PATH=f"{helpers}:{self.env['PATH']}")
        p2 = subprocess.Popen(
            [str(BIN), 'watch', str(watched)],
            env=ienv,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            ready, _, _ = select.select([p2.stdout], [], [], 3.0)
            self.assertTrue(ready)
            ev2 = json.loads(p2.stdout.readline())
            self.assertEqual(ev2['t'], 'changed')
            child_pid = int(pid_file.read_text().strip())
            p2.terminate()
            p2.communicate(timeout=3)
            self.assertEqual(p2.returncode, 0)
            self.assertFalse(Path(f'/proc/{child_pid}').exists(), 'inotifywait child was not cleaned up')
        finally:
            if p2.poll() is None:
                p2.kill()
                p2.communicate()

    def test_migration_070_copied_install_and_backup(self):
        bindir = self.home / '.local/bin'
        bindir.mkdir(parents=True)
        existing = bindir / 'dragon-files'
        existing.write_text('#!/usr/bin/env bash\necho old\n', encoding='utf-8')
        existing.chmod(0o755)
        mig_env = dict(
            self.env,
            REPO_DIR=str(ROOT),
            LINK_MODE='copy',
            DRY_RUN='false',
            ASSUME_YES='true',
        )
        r1 = subprocess.run(['bash', str(ROOT / 'migrations/070-files-tools.sh')], env=mig_env, capture_output=True, text=True, check=True)
        self.assertEqual(r1.returncode, 0)
        backups = list((Path(self.env['XDG_STATE_HOME']) / 'dragon-island/backups').rglob('dragon-files'))
        self.assertTrue(backups, 'expected backup of pre-existing dragon-files')
        # Run the deployed copy standalone
        sample = self.home / 'sample'
        sample.mkdir()
        (sample / 'a.txt').write_text('ok', encoding='utf-8')
        out = subprocess.run([str(existing), 'ls', str(sample), '--json'], env=self.env, capture_output=True, text=True, check=True)
        parsed = json.loads(out.stdout)
        self.assertTrue(parsed['ok'])
        self.assertEqual(parsed['entries'][0]['name'], 'a.txt')
        # Second run is idempotent
        r2 = subprocess.run(['bash', str(ROOT / 'migrations/070-files-tools.sh')], env=mig_env, capture_output=True, text=True, check=True)
        self.assertEqual(r2.returncode, 0)


if __name__ == '__main__':
    unittest.main()
