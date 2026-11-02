"""Archive adapter: libarchive metadata + bounded streaming, never extractall.

The reader supplied by bsdtar/libarchive handles all its installed formats. Its
passphrase API keeps passwords in memory, out of argv and diagnostic output.
"""
import ctypes as C
import ctypes.util
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import tempfile
import time

from taller_common import ToolError

BOMB_SIZE = 2 * 1024**3
BOMB_RATIO = 200
MAX_ENTRIES = 100000
CHUNK = 128 * 1024


def unsafe(message='El comprimido contiene rutas o tipos inseguros.'):
    raise ToolError('unsafe_paths', message)


def safe_name(name):
    if (not name or name.startswith(('/', '\\')) or '\\' in name
            or re.match(r'^[A-Za-z]:', name)
            or any(ord(c) < 32 or 127 <= ord(c) < 160 for c in name)
            or '..' in name.split('/')):
        unsafe()
    return PurePosixPath(name)


class Reader:
    def __init__(self, path, password=None):
        library = ctypes.util.find_library('archive')
        if not library:
            raise ToolError('missing_tool', 'Falta libarchive.', 'Instala libarchive (bsdtar).')
        self.lib = lib = C.CDLL(library)
        for name, result, args in (
            ('archive_read_new', C.c_void_p, []),
            ('archive_read_support_filter_all', C.c_int, [C.c_void_p]),
            ('archive_read_support_format_all', C.c_int, [C.c_void_p]),
            ('archive_read_add_passphrase', C.c_int, [C.c_void_p, C.c_char_p]),
            ('archive_read_open_filename', C.c_int, [C.c_void_p, C.c_char_p, C.c_size_t]),
            ('archive_read_next_header', C.c_int, [C.c_void_p, C.POINTER(C.c_void_p)]),
            ('archive_read_data', C.c_ssize_t, [C.c_void_p, C.c_void_p, C.c_size_t]),
            ('archive_read_free', C.c_int, [C.c_void_p]),
            ('archive_error_string', C.c_char_p, [C.c_void_p]),
            ('archive_format_name', C.c_char_p, [C.c_void_p]),
            ('archive_entry_pathname', C.c_char_p, [C.c_void_p]),
            ('archive_entry_symlink', C.c_char_p, [C.c_void_p]),
            ('archive_entry_hardlink', C.c_char_p, [C.c_void_p]),
            ('archive_entry_mode', C.c_uint, [C.c_void_p]),
            ('archive_entry_size', C.c_int64, [C.c_void_p]),
            ('archive_entry_mtime', C.c_int64, [C.c_void_p]),
            ('archive_entry_is_encrypted', C.c_int, [C.c_void_p]),
        ):
            fn = getattr(lib, name)
            fn.restype, fn.argtypes = result, args
        self.password = password
        self.handle = lib.archive_read_new()
        lib.archive_read_support_filter_all(self.handle)
        lib.archive_read_support_format_all(self.handle)
        if password is not None:
            lib.archive_read_add_passphrase(self.handle, password.encode())
        code = lib.archive_read_open_filename(self.handle, os.fsencode(path), CHUNK)
        if code < 0:
            try:
                self.fail()
            finally:
                self.close()

    def fail(self):
        raw = self.lib.archive_error_string(self.handle) or b''
        text = raw.decode(errors='replace').lower()
        if any(s in text for s in ('passphrase', 'password', 'encrypted')):
            code = 'bad_password' if self.password is not None else 'password_required'
            raise ToolError(code, 'El comprimido necesita una contraseña válida por stdin.')
        raise ToolError('archive_error', 'No se pudo leer el comprimido.',
                        'Comprueba su integridad y el soporte de este formato en libarchive.')

    def __iter__(self):
        count = 0
        while True:
            entry = C.c_void_p()
            code = self.lib.archive_read_next_header(self.handle, C.byref(entry))
            if code == 1:
                break
            if code < 0:
                self.fail()
            count += 1
            if count > MAX_ENTRIES:
                raise ToolError('bomb_suspected', 'Demasiadas entradas en el comprimido.')
            def field(name):
                raw = getattr(self.lib, 'archive_entry_' + name)(entry)
                return os.fsdecode(raw) if raw else None
            name = field('pathname') or ''
            mode = self.lib.archive_entry_mode(entry)
            yield dict(path=name, size=max(0, self.lib.archive_entry_size(entry)),
                       mtime=self.lib.archive_entry_mtime(entry), mode=mode,
                       is_dir=stat.S_ISDIR(mode), symlink=field('symlink'),
                       hardlink=field('hardlink'), encrypted=bool(self.lib.archive_entry_is_encrypted(entry)),
                       packed=None)

    def blocks(self):
        buf = C.create_string_buffer(CHUNK)
        while True:
            size = self.lib.archive_read_data(self.handle, buf, CHUNK)
            if size < 0:
                self.fail()
            if not size:
                break
            yield buf.raw[:size]

    def close(self):
        if self.handle:
            self.lib.archive_read_free(self.handle)
            self.handle = None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


def catalog(path, password=None):
    with Reader(path, password) as reader:
        entries = list(reader)
        method = (reader.lib.archive_format_name(reader.handle) or b'').decode(errors='replace')
    total = sum(e['size'] for e in entries)
    return dict(format=method, method=method, encrypted=any(e['encrypted'] for e in entries),
                count=len(entries), total_size=total, entries=entries, warnings=[])


def validate(entries):
    seen = {}
    for entry in entries:
        name = safe_name(entry['path'])
        if str(name) == '.':
            if not entry['is_dir']:
                unsafe()
            continue
        key = str(name)
        if key in seen:
            unsafe('Hay rutas duplicadas en el comprimido.')
        seen[key] = entry
        mode = entry['mode']
        if entry['hardlink']:
            # Hardlinks can alias files published under a different conflict policy.
            unsafe('No se admiten enlaces duros en comprimidos.')
        if not (stat.S_ISREG(mode) or stat.S_ISDIR(mode) or stat.S_ISLNK(mode)):
            unsafe('No se admiten dispositivos ni archivos especiales.')
        if entry['symlink']:
            target = safe_name(entry['symlink'])
            if str(target) == '.':
                unsafe()
    for key in seen:
        for parent in PurePosixPath(key).parents:
            ent = seen.get(str(parent))
            if ent and not ent['is_dir']:
                unsafe('Una ruta atraviesa un enlace o archivo del comprimido.')


def check_resources(total, packed, free, confirm=False):
    if total > free:
        raise ToolError('no_space', 'No hay espacio libre suficiente para extraer.')
    if total > BOMB_SIZE and total > max(1, packed) * BOMB_RATIO and not confirm:
        raise ToolError('bomb_suspected', 'Posible bomba de descompresión.',
                        'Revisa el tamaño antes de usar --confirm-bomb.')


def extract(args, api):
    password = api.sys.stdin.readline().rstrip('\r\n') if args.password_stdin else None
    archive = Path(args.archive).expanduser().resolve(strict=True)
    dest = Path(args.dest).expanduser().resolve(strict=True)
    if not dest.is_dir():
        raise ToolError('invalid_dest', 'El destino debe ser una carpeta existente.')
    # Immutable private snapshot prevents a changed source between listing and extraction.
    stage = Path(tempfile.mkdtemp(prefix='.dragon-extract-', dir=dest))
    api._CLEANUP_PATHS.add(str(stage))
    try:
        snapshot = stage / 'input'
        packed = archive.stat().st_size
        if packed > shutil.disk_usage(dest).free:
            raise ToolError('no_space', 'No hay espacio para preparar el comprimido.')
        shutil.copyfile(archive, snapshot)
        meta = catalog(snapshot, password)
        validate(meta['entries'])
        check_resources(meta['total_size'], snapshot.stat().st_size, shutil.disk_usage(dest).free, args.confirm_bomb)
        payload = stage / 'payload'
        payload.mkdir(mode=0o700)
        actual = 0
        start = time.monotonic()
        directories = []
        with Reader(snapshot, password) as reader:
            for index, entry in enumerate(reader):
                name = safe_name(entry['path'])
                if str(name) == '.':
                    continue
                target = payload.joinpath(*name.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                if entry['is_dir']:
                    target.mkdir(exist_ok=True)
                    directories.append((target, entry['mode'] & 0o777))
                elif entry['symlink']:
                    os.symlink(entry['symlink'], target)
                else:
                    size = 0
                    with target.open('xb') as out:
                        for block in reader.blocks():
                            size += len(block)
                            actual += len(block)
                            if size > entry['size'] or actual > meta['total_size']:
                                raise ToolError('bomb_suspected', 'El tamaño real supera el declarado.')
                            if len(block) > shutil.disk_usage(dest).free:
                                raise ToolError('no_space', 'Se agotó el espacio durante la extracción.')
                            out.write(block)
                            api.emit(dict(t='progress', pct=int(100 * actual / max(1, meta['total_size'])),
                                          file=entry['path'], bps=int(actual / max(.001, time.monotonic() - start)),
                                          index=index + 1, count=meta['count']))
                    if size != entry['size']:
                        raise ToolError('archive_error', 'El comprimido está truncado.')
                    target.chmod(entry['mode'] & 0o777)  # strips setuid, setgid, sticky
        # Every entry is now validated and fully read. Publish top-level items only:
        # replacing whole directories avoids following links in the existing tree.
        policy = {'mode': args.conflict, 'apply_all': args.conflict != 'ask'}
        if args.own_folder:
            name = archive.name
            for suffix in ('.tar.gz', '.tar.xz', '.tar.zst', '.tar.bz2'):
                if name.lower().endswith(suffix):
                    name = name[:-len(suffix)]
                    break
            else:
                name = archive.stem
            safe_name(name)
            items = [(payload, dest / name)]
        else:
            items = [(p, dest / p.name) for p in sorted(payload.iterdir())]
        # Resolve all conflict decisions before moving the first item.
        moves = []
        reserved = set()
        for src, target in items:
            result, overwrite = api.resolve_conflict(str(src), str(target), policy, src.is_dir())
            if result:
                if result in reserved:
                    raise ToolError('conflict', 'Dos entradas tienen el mismo destino.')
                reserved.add(result)
                moves.append((src, Path(result), overwrite))
        for directory, mode in reversed(directories):
            directory.chmod(mode)
        for src, target, overwrite in moves:
            if overwrite and os.path.lexists(target):
                api.remove_existing_target(str(target))
            os.rename(src, target)
        return dict(t='done', dest=str(dest), count=meta['count'])
    finally:
        # Directory modes from the archive may be read-only.
        for base, dirs, _ in os.walk(stage):
            os.chmod(base, 0o700)
        shutil.rmtree(stage, ignore_errors=True)
        api._CLEANUP_PATHS.discard(str(stage))


def create(args, api):
    import tarfile
    import zipfile
    out = Path(args.out).expanduser().absolute()
    paths = [Path(p).expanduser().absolute() for p in args.paths]
    if out.exists() or out.is_symlink():
        raise ToolError('already_exists', 'El comprimido de destino ya existe.')
    for path in paths:
        if not path.exists() or path.is_symlink() or out == path or path in out.parents:
            raise ToolError('invalid_path', 'No se puede comprimir esta ruta en ese destino.')
    tmpdir = Path(tempfile.mkdtemp(prefix='.dragon-create-', dir=out.parent))
    api._CLEANUP_PATHS.add(str(tmpdir))
    temp = tmpdir / ('output.7z' if args.format == '7z' else 'output')
    try:
        if args.format == 'zip':
            with zipfile.ZipFile(temp, 'w', compression=zipfile.ZIP_DEFLATED) as z:
                for path in paths:
                    for p in [path, *path.rglob('*')] if path.is_dir() else [path]:
                        if p.is_symlink():
                            raise ToolError('unsafe_paths', 'No se comprimen enlaces simbólicos en ZIP.')
                        z.write(p, str(Path(path.name) / p.relative_to(path)))
        elif args.format in ('tar.gz', 'tar.xz'):
            with tarfile.open(temp, 'w:' + args.format.split('.')[1]) as tar:
                for p in paths:
                    tar.add(p, arcname=p.name)
        else:
            tool = '7z' if args.format == '7z' else 'bsdtar'
            if not shutil.which(tool):
                raise ToolError('missing_tool', f'Falta {tool}.', f'Instala {"7zip" if tool == "7z" else "libarchive"}.')
            # Different parents are added separately to preserve top-level names.
            if len({p.parent for p in paths}) != 1:
                raise ToolError('invalid_path', 'Para este formato selecciona rutas de la misma carpeta.')
            cmd = (['7z', 'a', '-t7z', str(temp), '--'] if tool == '7z'
                   else ['bsdtar', '--zstd', '-cf', str(temp), '--'])
            proc = subprocess.Popen(cmd + [p.name for p in paths], cwd=paths[0].parent,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            api._CLEANUP_PROCS.add(proc)
            try:
                if proc.wait() != 0:
                    raise ToolError('archive_error', 'No se pudo crear el comprimido.')
            finally:
                api._CLEANUP_PROCS.discard(proc)
        # No overwrite race: link fails if another process created out meanwhile.
        os.link(temp, out)
        return dict(t='done', path=str(out))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
        api._CLEANUP_PATHS.discard(str(tmpdir))


def command(args, api):
    if args.action == 'create':
        return create(args, api)
    if args.action == 'extract':
        return extract(args, api)
    if args.action == 'list':
        return catalog(args.archive)
    with Reader(args.archive) as reader:
        for _ in reader:
            for _ in reader.blocks():
                pass
    return dict(valid=True)


def configure(sub):
    parser = sub.add_parser('archive')
    actions = parser.add_subparsers(dest='action', required=True)
    for action in ('list', 'test', 'extract', 'create'):
        p = actions.add_parser(action)
        p.add_argument('--json', action='store_true')
        p.add_argument('--json-progress', action='store_true')
        if action == 'create':
            p.add_argument('--format', choices=('zip', '7z', 'tar.gz', 'tar.xz', 'tar.zst'), required=True)
            p.add_argument('--out', required=True)
            p.add_argument('--paths', nargs='+', required=True)
        else:
            p.add_argument('archive')
        if action == 'extract':
            p.add_argument('--dest', required=True)
            p.add_argument('--password-stdin', action='store_true')
            p.add_argument('--own-folder', action='store_true')
            p.add_argument('--confirm-bomb', action='store_true')
            p.add_argument('--conflict', choices=('ask', 'skip', 'overwrite', 'rename'), default='ask')
