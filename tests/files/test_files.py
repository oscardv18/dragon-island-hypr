"""Tests for dragon-files (d1 + d2) in temp HOME/XDG."""
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

    def test_d2_mkdir_rename_link_and_errors(self):
        work = self.home / 'work'
        work.mkdir()
        res_mk = self.cli('op', 'mkdir', str(work), '--name', 'Nueva carpeta')
        self.assertTrue((work / 'Nueva carpeta').is_dir())
        self.assertEqual(res_mk['path'], str(work / 'Nueva carpeta'))

        # Duplicate mkdir fails cleanly
        err_dup = self.cli('op', 'mkdir', str(work), '--name', 'Nueva carpeta', ok=False)
        self.assertEqual(err_dup['error']['code'], 'already_exists')

        # Invalid name with slash fails
        err_bad = self.cli('op', 'mkdir', str(work), '--name', 'a/b', ok=False)
        self.assertEqual(err_bad['error']['code'], 'invalid_name')

        # Rename reports moved pair for undo
        src_file = work / 'borrador.txt'
        src_file.write_text('contenido', encoding='utf-8')
        p_ren = subprocess.run(
            [str(BIN), 'op', 'rename', str(src_file), '--name', 'final.txt', '--json-progress'],
            env=self.env,
            capture_output=True,
            text=True,
            check=True,
        )
        lines = [json.loads(line) for line in p_ren.stdout.splitlines() if line.strip()]
        done = lines[-1]
        self.assertEqual(done['t'], 'done')
        self.assertEqual(done['moved'], [{'from': str(src_file), 'to': str(work / 'final.txt')}])
        self.assertFalse(src_file.exists())
        self.assertTrue((work / 'final.txt').is_file())

        # Symlink creation via op link
        links_dir = self.home / 'links'
        links_dir.mkdir()
        self.cli('op', 'link', str(work / 'final.txt'), '--dest', str(links_dir))
        self.assertTrue((links_dir / 'final.txt').is_symlink())
        self.assertEqual((links_dir / 'final.txt').resolve(), (work / 'final.txt').resolve())

    def test_d2_copy_move_progress_and_stdin_conflicts(self):
        src_dir = self.home / 'src'
        dst_dir = self.home / 'dst'
        src_dir.mkdir()
        dst_dir.mkdir()

        # Prepare files including compound extension .tar.gz
        (src_dir / 'uno.txt').write_text('version-nueva-1', encoding='utf-8')
        (src_dir / 'dos.txt').write_text('version-nueva-2', encoding='utf-8')
        (src_dir / 'paquete.tar.gz').write_text('tarball-nuevo', encoding='utf-8')
        (dst_dir / 'uno.txt').write_text('version-vieja-1', encoding='utf-8')
        (dst_dir / 'dos.txt').write_text('version-vieja-2', encoding='utf-8')
        (dst_dir / 'paquete.tar.gz').write_text('tarball-viejo', encoding='utf-8')

        # Copy with --conflict ask:
        # 1st conflict (uno.txt) -> skip
        # 2nd conflict (dos.txt) -> overwrite
        # 3rd conflict (paquete.tar.gz) -> rename
        answers = (
            json.dumps({'answer': 'skip', 'all': False}) + '\n'
            + json.dumps({'answer': 'overwrite', 'all': False}) + '\n'
            + json.dumps({'answer': 'rename', 'all': False}) + '\n'
        )
        p_copy = subprocess.run(
            [
                str(BIN), 'op', 'copy',
                str(src_dir / 'uno.txt'),
                str(src_dir / 'dos.txt'),
                str(src_dir / 'paquete.tar.gz'),
                '--dest', str(dst_dir),
                '--conflict', 'ask',
                '--json-progress',
            ],
            input=answers,
            env=self.env,
            capture_output=True,
            text=True,
            check=True,
        )
        events = [json.loads(line) for line in p_copy.stdout.splitlines() if line.strip()]
        conflicts = [e for e in events if e.get('t') == 'conflict']
        progress = [e for e in events if e.get('t') == 'progress']
        done = events[-1]
        self.assertEqual(len(conflicts), 3)
        self.assertTrue(len(progress) >= 2)
        self.assertEqual(done['t'], 'done')
        self.assertTrue(done['ok'])
        self.assertEqual((dst_dir / 'uno.txt').read_text(encoding='utf-8'), 'version-vieja-1')
        self.assertEqual((dst_dir / 'dos.txt').read_text(encoding='utf-8'), 'version-nueva-2')
        self.assertEqual((dst_dir / 'paquete.tar.gz').read_text(encoding='utf-8'), 'tarball-viejo')
        self.assertEqual((dst_dir / 'paquete (1).tar.gz').read_text(encoding='utf-8'), 'tarball-nuevo')

        # Test "all: true" in conflict answer during move, and verify moved list for undo
        move_src = self.home / 'move_src'
        move_dst = self.home / 'move_dst'
        move_src.mkdir()
        move_dst.mkdir()
        for name in ('a.txt', 'b.txt'):
            (move_src / name).write_text(f'new-{name}', encoding='utf-8')
            (move_dst / name).write_text(f'old-{name}', encoding='utf-8')

        p_move = subprocess.run(
            [
                str(BIN), 'op', 'move',
                str(move_src / 'a.txt'),
                str(move_src / 'b.txt'),
                '--dest', str(move_dst),
                '--conflict', 'ask',
                '--json-progress',
            ],
            input=json.dumps({'answer': 'rename', 'all': True}) + '\n',
            env=self.env,
            capture_output=True,
            text=True,
            check=True,
        )
        m_events = [json.loads(line) for line in p_move.stdout.splitlines() if line.strip()]
        m_conflicts = [e for e in m_events if e.get('t') == 'conflict']
        self.assertEqual(len(m_conflicts), 1, 'Expected only 1 conflict prompt when all=True')
        m_done = m_events[-1]
        self.assertEqual(
            m_done['moved'],
            [
                {'from': str(move_src / 'a.txt'), 'to': str(move_dst / 'a (1).txt')},
                {'from': str(move_src / 'b.txt'), 'to': str(move_dst / 'b (1).txt')},
            ],
        )
        self.assertFalse((move_src / 'a.txt').exists())
        self.assertFalse((move_src / 'b.txt').exists())
        self.assertEqual((move_dst / 'a (1).txt').read_text(encoding='utf-8'), 'new-a.txt')
        self.assertEqual((move_dst / 'b (1).txt').read_text(encoding='utf-8'), 'new-b.txt')

        # Prevent copying/moving a folder into itself
        err_inside = self.cli('op', 'copy', str(move_dst), '--dest', str(move_dst), ok=False)
        self.assertEqual(err_inside['error']['code'], 'invalid_dest')

    def test_d2_cancel_copy_cleans_partial_temp_file(self):
        src = self.home / 'grande.bin'
        src.write_bytes(b'A' * (262144 * 8))
        dst_dir = self.home / 'cancel_dst'
        dst_dir.mkdir()

        slow_env = dict(self.env, DRAGON_FILES_SLOW_MS='80')
        p = subprocess.Popen(
            [str(BIN), 'op', 'copy', str(src), '--dest', str(dst_dir), '--json-progress'],
            env=slow_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            # Wait for the first progress line so we know the temp file is open and being written
            ready, _, _ = select.select([p.stdout], [], [], 3.0)
            self.assertTrue(ready, 'Expected progress output before cancelling')
            first = json.loads(p.stdout.readline())
            self.assertEqual(first['t'], 'progress')
            p.terminate()
            p.communicate(timeout=3)
            self.assertEqual(p.returncode, 0)
            leftovers = list(dst_dir.iterdir())
            self.assertEqual(leftovers, [], f'Temporary partial file was not cleaned up: {leftovers}')
        finally:
            if p.poll() is None:
                p.kill()
                p.communicate()

    def test_d2_trash_restore_empty_and_permanent_delete(self):
        folder = self.home / 'documentos'
        folder.mkdir()
        f1 = folder / 'informe.txt'
        f2 = folder / 'borrable.txt'
        f1.write_text('importante', encoding='utf-8')
        f2.write_text('temporal', encoding='utf-8')

        # Send both to trash
        self.cli('op', 'trash', str(f1), str(f2))
        self.assertFalse(f1.exists())
        self.assertFalse(f2.exists())

        trashed = self.cli('ls', 'trash:///')
        by_name = {e['name']: e for e in trashed['entries']}
        self.assertIn('informe.txt', by_name)
        self.assertIn('borrable.txt', by_name)
        self.assertEqual(by_name['informe.txt']['orig_path'], str(f1))

        # Restore informe.txt
        restored = self.cli('trash', 'restore', by_name['informe.txt']['uri'])
        self.assertTrue(f1.is_file())
        self.assertEqual(f1.read_text(encoding='utf-8'), 'importante')
        self.assertEqual(restored['moved'], [{'from': by_name['informe.txt']['uri'], 'to': str(f1)}])

        # Permanent delete without --confirm must fail
        err_del = self.cli('op', 'delete', str(f1), ok=False)
        self.assertEqual(err_del['error']['code'], 'confirm_required')
        self.assertTrue(f1.is_file())

        # Permanent delete with --confirm removes file
        self.cli('op', 'delete', str(f1), '--confirm')
        self.assertFalse(f1.exists())

        # Empty trash without --confirm must fail
        err_empty = self.cli('trash', 'empty', ok=False)
        self.assertEqual(err_empty['error']['code'], 'confirm_required')

        # Empty trash with --confirm clears remaining items
        self.cli('trash', 'empty', '--confirm')
        after_empty = self.cli('ls', 'trash:///')
        self.assertEqual(after_empty['entries'], [])


if __name__ == '__main__':
    unittest.main()
