"""File explorer adapter (Phase 5d): fast directory listing, places, watch, properties, thumbnails and launchers.

All optional system helpers degrade cleanly: missing thumbnailers return thumb=null; missing inotifywait falls back
to one-second folder polling while watched. Passwords and secrets never appear in arguments or output.
"""
import json
import os
from pathlib import Path
import pwd
import re
import signal
import stat
import sys
import time

from secret_filter import redact
from taller_common import Parser, ToolError, error

_SECRET_TOKENS = (
    '-----begin', '_key', '_token', '_secret', 'password', 'token', 'secret', 'api_key',
    'bearer ', '://', 'sk-', 'ghp_', 'gho_', 'ghu_', 'ghs_', 'ghr_', 'akia',
)
_NUM_RE = re.compile(r'(\d+)')
_CLEANUP_PATHS = set()
_CLEANUP_PROCS = set()


def _cleanup_on_signal(*_):
    for proc in list(_CLEANUP_PROCS):
        try:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGTERM)
        except Exception:
            pass
    for path in list(_CLEANUP_PATHS):
        try:
            if os.path.islink(path) or os.path.isfile(path):
                os.unlink(path)
            elif os.path.isdir(path):
                import shutil
                shutil.rmtree(path, ignore_errors=True)
        except OSError:
            pass
    sys.exit(0)


def folded(text):
    if text.isascii():
        return text.lower()
    import unicodedata
    return ''.join(c for c in unicodedata.normalize('NFKD', text.casefold()) if not unicodedata.combining(c))

ARCHIVE_EXT = (
    '.tar.gz', '.tar.xz', '.tar.zst', '.tar.bz2', '.tar.lz', '.tgz', '.txz', '.tbz2', '.tzst',
    '.zip', '.7z', '.rar', '.tar', '.gz', '.xz', '.zst', '.bz2', '.iso', '.deb', '.rpm', '.cab',
    '.appimage', '.lha', '.lzh', '.jar', '.apk',
)

MIME_BY_EXT = {
    '.tar.gz': 'application/gzip',
    '.tgz': 'application/gzip',
    '.gz': 'application/gzip',
    '.tar.xz': 'application/x-xz',
    '.txz': 'application/x-xz',
    '.xz': 'application/x-xz',
    '.tar.zst': 'application/zstd',
    '.tzst': 'application/zstd',
    '.zst': 'application/zstd',
    '.tar.bz2': 'application/x-bzip2',
    '.tbz2': 'application/x-bzip2',
    '.bz2': 'application/x-bzip2',
    '.tar.lz': 'application/x-lzip',
    '.tar': 'application/x-tar',
    '.zip': 'application/zip',
    '.7z': 'application/x-7z-compressed',
    '.rar': 'application/vnd.rar',
    '.iso': 'application/x-iso9660-image',
    '.deb': 'application/vnd.debian.binary-package',
    '.rpm': 'application/x-rpm',
    '.cab': 'application/vnd.ms-cab-compressed',
    '.appimage': 'application/vnd.appimage',
    '.jar': 'application/java-archive',
    '.apk': 'application/vnd.android.package-archive',
    '.md': 'text/markdown',
    '.txt': 'text/plain',
    '.log': 'text/plain',
    '.pdf': 'application/pdf',
    '.sql': 'application/sql',
    '.json': 'application/json',
    '.yaml': 'application/yaml',
    '.yml': 'application/yaml',
    '.toml': 'application/toml',
    '.csv': 'text/csv',
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'text/javascript',
    '.ts': 'text/typescript',
    '.tsx': 'text/typescript',
    '.py': 'text/x-python',
    '.sh': 'application/x-shellscript',
    '.lua': 'text/x-lua',
    '.qml': 'text/x-qml',
    '.rs': 'text/x-rust',
    '.go': 'text/x-go',
    '.c': 'text/x-csrc',
    '.h': 'text/x-csrc',
    '.cpp': 'text/x-c++src',
    '.java': 'text/x-java',
    '.svg': 'image/svg+xml',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
    '.avif': 'image/avif',
    '.mp4': 'video/mp4',
    '.mkv': 'video/x-matroska',
    '.webm': 'video/webm',
    '.mov': 'video/quicktime',
    '.mp3': 'audio/mpeg',
    '.flac': 'audio/flac',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
    '.odt': 'application/vnd.oasis.opendocument.text',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.ods': 'application/vnd.oasis.opendocument.spreadsheet',
    '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
}

TYPE_LABELS = {
    '.tar.gz': 'tar + gzip', '.tgz': 'tar + gzip', '.tar.xz': 'tar + xz', '.txz': 'tar + xz',
    '.tar.zst': 'tar + zstd', '.tzst': 'tar + zstd', '.tar.bz2': 'tar + bzip2', '.tbz2': 'tar + bzip2',
    '.zip': 'Archivo ZIP', '.7z': 'Archivo 7z', '.rar': 'Archivo RAR', '.tar': 'Archivo tar', '.iso': 'Imagen ISO',
    '.deb': 'Paquete deb', '.rpm': 'Paquete rpm', '.cab': 'Archivo CAB', '.appimage': 'AppImage',
    '.md': 'Markdown', '.txt': 'Texto', '.pdf': 'PDF', '.sql': 'SQL', '.json': 'JSON', '.yaml': 'YAML', '.yml': 'YAML',
    '.toml': 'TOML', '.csv': 'CSV', '.html': 'HTML', '.css': 'CSS', '.js': 'JavaScript', '.ts': 'TypeScript',
    '.tsx': 'TypeScript', '.py': 'Python', '.sh': 'Shell', '.lua': 'Lua', '.qml': 'QML', '.rs': 'Rust', '.go': 'Go',
    '.c': 'C', '.h': 'C', '.cpp': 'C++', '.java': 'Java', '.svg': 'Imagen SVG', '.png': 'Imagen PNG',
    '.jpg': 'Imagen JPEG', '.jpeg': 'Imagen JPEG', '.webp': 'Imagen WebP', '.gif': 'Imagen GIF', '.avif': 'Imagen AVIF',
    '.mp4': 'Vídeo MP4', '.mkv': 'Vídeo MKV', '.webm': 'Vídeo WebM', '.mov': 'Vídeo MOV',
    '.mp3': 'Audio MP3', '.flac': 'Audio FLAC', '.ogg': 'Audio OGG', '.wav': 'Audio WAV',
    '.odt': 'Documento', '.docx': 'Documento', '.ods': 'Hoja de cálculo', '.xlsx': 'Hoja de cálculo',
}


def emit(value):
    raw = json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(',', ':'))
    low = raw.lower()
    if any(tok in low for tok in _SECRET_TOKENS):
        raw = redact(raw)[0]
    print(raw, flush=True)


def ext_of(name):
    lower = name.lower()
    if '.tar.' in lower:
        for ext in ('.tar.gz', '.tar.xz', '.tar.zst', '.tar.bz2', '.tar.lz'):
            if lower.endswith(ext):
                return ext
    idx = lower.rfind('.')
    return lower[idx:] if idx > 0 else ''


def guess_mime(name):
    ext = ext_of(name)
    if ext in MIME_BY_EXT:
        return MIME_BY_EXT[ext]
    import mimetypes
    guessed, _ = mimetypes.guess_type(name)
    return guessed or 'application/octet-stream'


def type_label(entry):
    if entry.get('kind') == 'dir':
        return 'Carpeta'
    if entry.get('kind') == 'link' and entry.get('broken'):
        return 'Enlace roto'
    ext = ext_of(entry.get('name', ''))
    if ext in TYPE_LABELS:
        return TYPE_LABELS[ext]
    mime = entry.get('mime') or ''
    if mime.startswith('text/'):
        return 'Texto'
    if mime.startswith('image/'):
        return 'Imagen'
    if mime.startswith('video/'):
        return 'Vídeo'
    if mime.startswith('audio/'):
        return 'Audio'
    return ext[1:].upper() if ext else 'Archivo'


def natural_key(text):
    parts = _NUM_RE.split(folded(text or ''))
    return [(0, int(part)) if part.isdigit() else (1, part) for part in parts if part]


def filesystem_info(target):
    try:
        stv = os.statvfs(target)
        free = int(stv.f_bavail * stv.f_frsize)
        total = int(stv.f_blocks * stv.f_frsize)
    except OSError:
        free, total = 0, 0
    real = os.path.realpath(target)
    best_mount = ''
    best_fs = ''
    try:
        with open('/proc/mounts', 'r', encoding='utf-8', errors='replace') as handle:
            for line in handle:
                parts = line.split()
                if len(parts) < 3:
                    continue
                mount = parts[1].replace('\\040', ' ').replace('\\011', '\t').replace('\\012', '\n').replace('\\134', '\\')
                if real == mount or real.startswith(mount.rstrip('/') + '/') or mount == '/':
                    if len(mount) >= len(best_mount):
                        best_mount = mount
                        best_fs = parts[2]
    except OSError:
        pass
    return free, total, best_fs


def trash_root():
    data_home = Path(os.environ.get('XDG_DATA_HOME') or (Path.home() / '.local/share'))
    return data_home / 'Trash'


def parse_trashinfo(info_file):
    import datetime
    import urllib.parse
    orig_path = None
    deleted_at = None
    try:
        for line in info_file.read_text(encoding='utf-8', errors='replace').splitlines():
            if line.startswith('Path='):
                raw = line[5:].strip()
                orig_path = urllib.parse.unquote(raw)
            elif line.startswith('DeletionDate='):
                raw = line[13:].strip()
                try:
                    dt = datetime.datetime.fromisoformat(raw)
                    deleted_at = int(dt.timestamp())
                except ValueError:
                    pass
    except OSError:
        pass
    return orig_path, deleted_at


def find_git_root(target):
    try:
        cur = Path(target).resolve()
        for folder in (cur, *cur.parents):
            if (folder / '.git').exists():
                return folder
    except OSError:
        pass
    return None


def git_marks_for_dir(target):
    import dragon_git
    repo_root = find_git_root(target)
    if not repo_root:
        return {}
    try:
        data = dragon_git.status(str(repo_root))
    except Exception:
        return {}
    try:
        rel_dir = Path(target).resolve().relative_to(repo_root.resolve())
    except ValueError:
        return {}
    priority = {'?': 1, 'D': 2, 'A': 3, 'M': 4}
    marks = {}

    def record(rel_path, code):
        p = Path(rel_path)
        if rel_dir != Path('.'):
            try:
                p = p.relative_to(rel_dir)
            except ValueError:
                return
        if not p.parts:
            return
        name = p.parts[0]
        effective = code if len(p.parts) == 1 else ('M' if code != '?' else '?')
        prev = marks.get(name)
        if prev is None or priority.get(effective, 0) > priority.get(prev, 0):
            marks[name] = effective

    for row in data.get('untracked', ()):
        record(row['path'], '?')
    for row in data.get('staged', ()):
        st = row.get('status', 'M')
        record(row['path'], 'A' if st == 'A' else ('D' if st == 'D' else 'M'))
    for row in data.get('changes', ()):
        st = row.get('status', 'M')
        record(row['path'], 'D' if st == 'D' else 'M')
    return marks


def count_children(dir_path, show_hidden=True, max_items=10000):
    count = 0
    try:
        with os.scandir(dir_path) as it:
            for sub in it:
                if not show_hidden and sub.name.startswith('.'):
                    continue
                count += 1
                if count >= max_items:
                    break
        return count
    except OSError:
        return None


def build_entry(entry, owners, show_hidden, git_marks, count_deadline):
    name = entry.name
    hidden = name.startswith('.')
    if hidden and not show_hidden:
        return None
    try:
        lstat = entry.stat(follow_symlinks=False)
    except OSError:
        return None
    is_link = entry.is_symlink()
    broken = False
    link_dir = False
    link_target = None
    if is_link:
        kind = 'link'
        try:
            link_target = os.readlink(entry.path)
        except OSError:
            link_target = None
        try:
            st = entry.stat(follow_symlinks=True)
            link_dir = stat.S_ISDIR(st.st_mode)
        except OSError:
            st = lstat
            broken = True
        mime = 'inode/directory' if link_dir else (None if broken else guess_mime(name))
    else:
        st = lstat
        if stat.S_ISDIR(st.st_mode):
            kind = 'dir'
            mime = 'inode/directory'
        elif stat.S_ISREG(st.st_mode):
            kind = 'file'
            mime = guess_mime(name)
        else:
            kind = 'other'
            mime = 'inode/special'

    uid = st.st_uid
    owner = owners.get(uid)
    if owner is None:
        try:
            owner = pwd.getpwuid(uid).pw_name
        except KeyError:
            owner = str(uid)
        owners[uid] = owner

    item = {
        'name': name,
        'kind': kind,
        'size': int(st.st_size),
        'mtime': int(st.st_mtime),
        'mime': mime,
        'mode': f'{stat.S_IMODE(st.st_mode):04o}',
        'owner': owner,
        'hidden': hidden,
        'link_target': link_target,
        'git': git_marks.get(name),
    }
    if kind == 'dir' or (is_link and link_dir):
        if time.perf_counter() < count_deadline:
            item['count'] = count_children(entry.path, show_hidden=True)
        else:
            item['count'] = None
    if is_link:
        item['broken'] = broken
        item['link_dir'] = link_dir
    return item


def sort_entries(entries, sort_by='name', dirs_first=False):
    def key_fn(item):
        dir_rank = (0 if item['kind'] == 'dir' else 1) if dirs_first else 0
        nkey = natural_key(item['name'])
        if sort_by == 'size':
            val = (item.get('count') or 0) if item['kind'] == 'dir' else item.get('size', 0)
            return (dir_rank, val, nkey)
        if sort_by == 'mtime':
            return (dir_rank, item.get('mtime', 0), nkey)
        if sort_by == 'type':
            return (dir_rank, natural_key(type_label(item)), nkey)
        return (dir_rank, nkey)

    entries.sort(key=key_fn)
    return entries


def cmd_ls(args):
    raw_path = args.path
    if raw_path.startswith('trash:'):
        import urllib.parse
        troot = trash_root()
        files_dir = troot / 'files'
        info_dir = troot / 'info'
        owners = {}
        entries = []
        deadline = time.perf_counter() + 0.08
        if files_dir.is_dir():
            try:
                with os.scandir(files_dir) as it:
                    for entry in it:
                        item = build_entry(entry, owners, args.hidden or True, {}, deadline)
                        if not item:
                            continue
                        if not args.hidden and item['hidden']:
                            continue
                        item['uri'] = 'trash:///' + urllib.parse.quote(entry.name)
                        orig_path, deleted_at = parse_trashinfo(info_dir / (entry.name + '.trashinfo'))
                        if orig_path:
                            item['orig_path'] = orig_path
                        if deleted_at:
                            item['mtime'] = deleted_at
                        entries.append(item)
            except OSError:
                pass
        sort_entries(entries, args.sort, args.dirs_first)
        if args.limit is not None and args.limit >= 0:
            entries = entries[:args.limit]
        probe = str(files_dir if files_dir.exists() else Path.home())
        free, total, fs = filesystem_info(probe)
        return {'path': 'trash:///', 'entries': entries, 'free': free, 'total': total, 'fs': fs}

    target = os.path.abspath(os.path.expanduser(raw_path))
    try:
        os.lstat(target)
    except FileNotFoundError:
        raise ToolError('not_found', f'No existe «{raw_path}»', 'Comprueba la ruta.') from None
    except PermissionError:
        raise ToolError('permission_denied', f'Permiso denegado en «{raw_path}»', 'Comprueba los permisos de la carpeta.') from None
    except OSError as exc:
        raise ToolError('io_error', f'No se pudo acceder a «{raw_path}»: {exc.strerror or exc}') from None

    try:
        dir_st = os.stat(target)
    except FileNotFoundError:
        raise ToolError('not_found', f'El enlace «{raw_path}» está roto', 'Comprueba el destino del enlace.') from None
    except PermissionError:
        raise ToolError('permission_denied', f'Permiso denegado en «{raw_path}»', 'Comprueba los permisos de la carpeta.') from None

    if not stat.S_ISDIR(dir_st.st_mode):
        raise ToolError('not_a_directory', f'«{raw_path}» no es una carpeta', 'Indica una carpeta válida.')

    git_marks = git_marks_for_dir(target) if args.git else {}
    owners = {}
    entries = []
    deadline = time.perf_counter() + 0.08
    try:
        with os.scandir(target) as it:
            for entry in it:
                item = build_entry(entry, owners, args.hidden, git_marks, deadline)
                if item is not None:
                    entries.append(item)
    except PermissionError:
        raise ToolError('permission_denied', f'Permiso denegado al leer «{raw_path}»', 'Comprueba los permisos de la carpeta.') from None
    except OSError as exc:
        raise ToolError('io_error', f'No se pudo leer «{raw_path}»: {exc.strerror or exc}') from None

    sort_entries(entries, args.sort, args.dirs_first)
    if args.limit is not None and args.limit >= 0:
        entries = entries[:args.limit]
    free, total, fs = filesystem_info(target)
    return {'path': target, 'entries': entries, 'free': free, 'total': total, 'fs': fs}


# ---- places ----

XDG_SPECS = (
    ('XDG_DESKTOP_DIR', 'desktop', 'Escritorio', ('Escritorio', 'Desktop')),
    ('XDG_DOCUMENTS_DIR', 'documents', 'Documentos', ('Documentos', 'Documents')),
    ('XDG_DOWNLOAD_DIR', 'downloads', 'Descargas', ('Descargas', 'Downloads')),
    ('XDG_PICTURES_DIR', 'pictures', 'Imágenes', ('Imágenes', 'Imagenes', 'Pictures')),
    ('XDG_MUSIC_DIR', 'music', 'Música', ('Música', 'Musica', 'Music')),
    ('XDG_VIDEOS_DIR', 'videos', 'Vídeos', ('Vídeos', 'Videos')),
)


def parse_user_dirs(home):
    cfg = Path(os.environ.get('XDG_CONFIG_HOME') or (home / '.config')) / 'user-dirs.dirs'
    found = {}
    if cfg.is_file():
        try:
            for raw in cfg.read_text(encoding='utf-8', errors='replace').splitlines():
                line = raw.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                key, _, val = line.partition('=')
                val = val.strip().strip('"').strip("'")
                val = val.replace('${HOME}', str(home)).replace('$HOME', str(home))
                if val:
                    found[key.strip()] = os.path.normpath(val)
        except OSError:
            pass
    return found


def load_projects(home):
    import sqlite3
    data_home = Path(os.environ.get('XDG_DATA_HOME') or (home / '.local/share'))
    db_path = data_home / 'dragon-island/dragon.db'
    projects = []
    seen = set()
    if db_path.is_file():
        try:
            conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True, timeout=1.0)
            try:
                rows = conn.execute('SELECT slug, name, path FROM project WHERE archived = 0 ORDER BY id').fetchall()
                for slug, name, path in rows:
                    norm = os.path.normpath(path)
                    seen.add(norm)
                    projects.append({
                        'id': f'project:{slug}',
                        'label': name or os.path.basename(norm),
                        'path': norm,
                        'kind': 'project',
                        'repo': find_git_root(norm) is not None,
                        'badge': None,
                    })
            finally:
                conn.close()
        except sqlite3.Error:
            pass
    for candidate in ('Proyectos', 'Projects'):
        folder = home / candidate
        norm = os.path.normpath(str(folder))
        if folder.is_dir() and norm not in seen:
            seen.add(norm)
            projects.append({
                'id': 'projects',
                'label': 'Proyectos',
                'path': norm,
                'kind': 'project',
                'repo': find_git_root(norm) is not None,
                'badge': None,
            })
    return projects


def bookmarks_file():
    from engine_common import config_path
    return config_path('files/bookmarks.json')


def load_bookmarks(home, excluded_paths):
    import urllib.parse
    from engine_common import read_json
    cfg_dir = Path(os.environ.get('XDG_CONFIG_HOME') or (home / '.config'))
    gtk_bm = cfg_dir / 'gtk-3.0/bookmarks'
    items = []
    seen = set(excluded_paths)

    if gtk_bm.is_file():
        try:
            for raw in gtk_bm.read_text(encoding='utf-8', errors='replace').splitlines():
                line = raw.strip()
                if not line or line.startswith('#'):
                    continue
                uri, _, label = line.partition(' ')
                if not uri.startswith('file://'):
                    continue
                path = os.path.normpath(urllib.parse.unquote(uri[7:]))
                if path in seen:
                    continue
                seen.add(path)
                items.append({
                    'id': f'bookmark:{path}',
                    'label': label.strip() or os.path.basename(path) or path,
                    'path': path,
                    'kind': 'bookmark',
                    'repo': find_git_root(path) is not None,
                    'badge': None,
                })
        except OSError:
            pass

    own = read_json(bookmarks_file(), {'bookmarks': []})
    raw_list = own.get('bookmarks', []) if isinstance(own, dict) else (own if isinstance(own, list) else [])
    for entry in raw_list:
        if not isinstance(entry, dict) or not entry.get('path'):
            continue
        path = os.path.normpath(str(entry['path']))
        if path in seen:
            continue
        seen.add(path)
        items.append({
            'id': f'bookmark:{path}',
            'label': entry.get('label') or os.path.basename(path) or path,
            'path': path,
            'kind': 'bookmark',
            'repo': find_git_root(path) is not None,
            'badge': None,
        })
    return items


def collect_places():
    home = Path(os.environ.get('HOME') or Path.home()).resolve()
    user_dirs = parse_user_dirs(home)
    xdg = [{
        'id': 'home',
        'label': 'Inicio',
        'path': str(home),
        'kind': 'home',
        'repo': (home / '.git').exists(),
        'badge': None,
    }]
    seen = {str(home)}
    for env_key, kind, label, fallbacks in XDG_SPECS:
        target = user_dirs.get(env_key)
        if not target:
            for candidate in fallbacks:
                p = home / candidate
                if p.is_dir():
                    target = str(p)
                    break
        if not target or target in seen:
            continue
        seen.add(target)
        badge = None
        if kind == 'downloads' and os.path.isdir(target):
            cnt = count_children(target, show_hidden=False, max_items=1000)
            badge = cnt if cnt else None
        xdg.append({
            'id': kind,
            'label': label,
            'path': target,
            'kind': kind,
            'repo': find_git_root(target) is not None,
            'badge': badge,
        })

    projects = load_projects(home)
    for proj in projects:
        seen.add(proj['path'])
    bookmarks = load_bookmarks(home, seen)

    tfiles = trash_root() / 'files'
    tcount = count_children(str(tfiles), show_hidden=True, max_items=5000) if tfiles.is_dir() else 0
    trash = {
        'id': 'trash',
        'label': 'Papelera',
        'path': 'trash:///',
        'kind': 'trash',
        'repo': False,
        'badge': tcount if tcount else None,
    }
    places = [*xdg, *projects, *bookmarks, trash]
    return {'places': places, 'xdg': xdg, 'projects': projects, 'bookmarks': bookmarks, 'trash': trash}


def cmd_places(args):
    from engine_common import atomic_json, locked, read_json
    if args.action == 'add':
        if not args.path:
            raise ToolError('invalid_usage', 'Falta la ruta para añadir a marcadores.')
        target = os.path.abspath(os.path.expanduser(args.path))
        label = args.label.strip() if args.label else (os.path.basename(target) or target)
        bfile = bookmarks_file()
        with locked(bfile):
            data = read_json(bfile, {'bookmarks': []})
            rows = data.get('bookmarks', []) if isinstance(data, dict) else []
            rows = [r for r in rows if isinstance(r, dict) and os.path.normpath(str(r.get('path', ''))) != target]
            rows.append({'path': target, 'label': label})
            atomic_json(bfile, {'bookmarks': rows})
    elif args.action == 'rm':
        if not args.path:
            raise ToolError('invalid_usage', 'Falta la ruta para quitar de marcadores.')
        target = os.path.abspath(os.path.expanduser(args.path))
        bfile = bookmarks_file()
        with locked(bfile):
            data = read_json(bfile, {'bookmarks': []})
            rows = data.get('bookmarks', []) if isinstance(data, dict) else []
            rows = [r for r in rows if isinstance(r, dict) and os.path.normpath(str(r.get('path', ''))) != target]
            atomic_json(bfile, {'bookmarks': rows})
    return collect_places()


# ---- watch ----

def dir_snapshot(target):
    snap = {}
    try:
        with os.scandir(target) as it:
            for entry in it:
                try:
                    st = entry.stat(follow_symlinks=False)
                    snap[entry.name] = (st.st_mtime_ns, st.st_size, st.st_mode)
                except OSError:
                    continue
    except OSError:
        return None
    return snap


def cmd_watch(args):
    import select
    import shutil
    import subprocess
    target = os.path.abspath(os.path.expanduser(args.path))
    if not os.path.isdir(target):
        raise ToolError('not_found', f'No existe la carpeta «{args.path}»', 'Comprueba la ruta.')
    proc = None
    previous = dir_snapshot(target)
    try:
        if shutil.which('inotifywait'):
            proc = subprocess.Popen(
                ['inotifywait', '-m', '-q', '-e', 'close_write,create,delete,moved_to,moved_from,attrib', target],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        while True:
            triggered = False
            if proc and proc.poll() is None:
                ready, _, _ = select.select([proc.stdout], [], [], 1.0)
                if ready:
                    chunk = os.read(proc.stdout.fileno(), 65536)
                    if chunk:
                        triggered = True
                        while select.select([proc.stdout], [], [], 0.15)[0]:
                            if not os.read(proc.stdout.fileno(), 65536):
                                break
            else:
                time.sleep(1.0)
            current = dir_snapshot(target)
            if triggered or current != previous:
                previous = current
                emit({'t': 'changed', 'path': target})
    finally:
        if proc and proc.poll() is None:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
                proc.communicate(timeout=2)
            except Exception:
                pass


# ---- props & image metadata ----

def _parse_exif_ifd(buf, tiff_start, offset, endian, out):
    import datetime
    import struct
    if tiff_start + offset + 2 > len(buf):
        return None
    count = struct.unpack_from(endian + 'H', buf, tiff_start + offset)[0]
    pos = tiff_start + offset + 2
    exif_ifd = None
    for _ in range(count):
        if pos + 12 > len(buf):
            break
        tag, ftype, ncomp, val_raw = struct.unpack_from(endian + 'HHII', buf, pos)
        pos += 12
        if tag == 0x8769:  # ExifIFDPointer
            exif_ifd = val_raw
            continue
        if ftype == 2:  # ASCII
            data_off = (pos - 4) if ncomp <= 4 else (tiff_start + val_raw)
            if data_off + ncomp <= len(buf):
                text = buf[data_off:data_off + ncomp].rstrip(b'\x00').decode('utf-8', errors='replace').strip()
                if tag == 0x010F:
                    out['make'] = text
                elif tag == 0x0110:
                    out['model'] = text
                elif tag in (0x9003, 0x0132) and 'taken' not in out:
                    try:
                        dt = datetime.datetime.strptime(text[:19], '%Y:%m:%d %H:%M:%S')
                        out['taken'] = int(dt.timestamp())
                    except ValueError:
                        pass
        elif ftype in (3, 4) and tag == 0x8827:  # ISO
            iso = struct.unpack_from(endian + ('H' if ftype == 3 else 'I'), buf, pos - 4)[0]
            out['iso'] = iso
        elif ftype == 5 and ncomp >= 1:  # RATIONAL
            roff = tiff_start + val_raw
            if roff + 8 <= len(buf):
                num, den = struct.unpack_from(endian + 'II', buf, roff)
                if den:
                    if tag == 0x829A:
                        out['exp'] = (num, den)
                    elif tag == 0x829D:
                        out['fnum'] = num / den
                    elif tag == 0x920A:
                        out['focal'] = num / den
    return exif_ifd


def parse_jpeg_meta(data):
    import struct
    if len(data) < 4 or data[:2] != b'\xff\xd8':
        return None
    idx = 2
    width = height = None
    raw_exif = {}
    while idx + 4 <= len(data):
        if data[idx] != 0xFF:
            idx += 1
            continue
        while idx < len(data) and data[idx] == 0xFF:
            idx += 1
        if idx >= len(data):
            break
        marker = data[idx]
        idx += 1
        if marker in (0xD8, 0xD9) or (0xD0 <= marker <= 0xD7):
            continue
        if idx + 2 > len(data):
            break
        seg_len = struct.unpack_from('>H', data, idx)[0]
        if seg_len < 2 or idx + seg_len > len(data):
            break
        seg = data[idx + 2:idx + seg_len]
        if marker == 0xE1 and seg.startswith(b'Exif\x00\x00') and len(seg) >= 14:
            tiff = seg[6:]
            endian = '<' if tiff[:2] == b'II' else ('>' if tiff[:2] == b'MM' else None)
            if endian:
                ifd0 = struct.unpack_from(endian + 'I', tiff, 4)[0]
                sub_ifd = _parse_exif_ifd(tiff, 0, ifd0, endian, raw_exif)
                if sub_ifd:
                    _parse_exif_ifd(tiff, 0, sub_ifd, endian, raw_exif)
        elif marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF) and len(seg) >= 5:
            height, width = struct.unpack_from('>HH', seg, 1)
        idx += seg_len

    if not width or not height:
        return None
    info = {'width': int(width), 'height': int(height)}
    make = raw_exif.get('make', '')
    model = raw_exif.get('model', '')
    if model:
        info['camera'] = model
    elif make:
        info['camera'] = make
    if 'taken' in raw_exif:
        info['taken'] = raw_exif['taken']
    exp_parts = []
    if 'exp' in raw_exif:
        num, den = raw_exif['exp']
        if num and den:
            if num < den:
                exp_parts.append(f'1/{round(den / num)} s')
            else:
                exp_parts.append(f'{num / den:g} s')
    if 'fnum' in raw_exif:
        exp_parts.append(f"f/{raw_exif['fnum']:.1f}".replace('.0', ''))
    if 'iso' in raw_exif:
        exp_parts.append(f"ISO {raw_exif['iso']}")
    if exp_parts:
        info['exposure'] = ' · '.join(exp_parts)
    if 'focal' in raw_exif:
        focal = f"{raw_exif['focal']:.1f}".replace('.0', '').replace('.', ',')
        info['lens'] = f'{focal} mm'
    return info


def image_metadata(path, mime):
    import struct
    try:
        with open(path, 'rb') as handle:
            head = handle.read(65536)
    except OSError:
        return None
    if head.startswith(b'\x89PNG\r\n\x1a\n') and len(head) >= 24:
        w, h = struct.unpack('>II', head[16:24])
        return {'width': int(w), 'height': int(h)}
    if head.startswith((b'GIF87a', b'GIF89a')) and len(head) >= 10:
        w, h = struct.unpack('<HH', head[6:10])
        return {'width': int(w), 'height': int(h)}
    if head.startswith(b'RIFF') and head[8:12] == b'WEBP' and len(head) >= 30:
        chunk = head[12:16]
        if chunk == b'VP8 ' and len(head) >= 30:
            w, h = struct.unpack('<HH', head[26:30])
            return {'width': w & 0x3FFF, 'height': h & 0x3FFF}
        if chunk == b'VP8L' and len(head) >= 25:
            b0, b1, b2, b3 = head[21:25]
            w = 1 + (((b1 & 0x3F) << 8) | b0)
            h = 1 + (((b3 & 0xF) << 10) | (b2 << 2) | ((b1 & 0xC0) >> 6))
            return {'width': int(w), 'height': int(h)}
        if chunk == b'VP8X' and len(head) >= 30:
            w = 1 + int.from_bytes(head[24:27], 'little')
            h = 1 + int.from_bytes(head[27:30], 'little')
            return {'width': int(w), 'height': int(h)}
    if head.startswith(b'\xff\xd8'):
        return parse_jpeg_meta(head)
    if mime == 'image/svg+xml' or str(path).lower().endswith('.svg'):
        text = head.decode('utf-8', errors='replace')
        vb = re.search(r'viewBox=["\']\s*[\d.-]+\s+[\d.-]+\s+([\d.]+)\s+([\d.]+)', text)
        if vb:
            return {'width': int(float(vb.group(1))), 'height': int(float(vb.group(2)))}
    return None


def recursive_dir_stats(root_path, max_entries=10000, timeout_s=1.5):
    total_size = 0
    total_count = 0
    truncated = False
    deadline = time.perf_counter() + timeout_s
    stack = [root_path]
    while stack:
        if time.perf_counter() >= deadline:
            truncated = True
            break
        current = stack.pop()
        try:
            with os.scandir(current) as it:
                for entry in it:
                    total_count += 1
                    try:
                        st = entry.stat(follow_symlinks=False)
                        if stat.S_ISREG(st.st_mode):
                            total_size += int(st.st_size)
                        elif stat.S_ISDIR(st.st_mode) and not entry.is_symlink():
                            stack.append(entry.path)
                    except OSError:
                        pass
                    if total_count >= max_entries or time.perf_counter() >= deadline:
                        truncated = True
                        break
        except OSError:
            continue
        if truncated:
            break
    return total_size, total_count, truncated


def cmd_props(args):
    import grp
    raw_path = args.path
    target = os.path.abspath(os.path.expanduser(raw_path))
    try:
        lstat = os.lstat(target)
    except FileNotFoundError:
        raise ToolError('not_found', f'No existe «{raw_path}»', 'Comprueba la ruta.') from None
    except PermissionError:
        raise ToolError('permission_denied', f'Permiso denegado en «{raw_path}»', 'Comprueba los permisos.') from None

    is_link = stat.S_ISLNK(lstat.st_mode)
    broken = False
    link_target = None
    if is_link:
        try:
            link_target = os.readlink(target)
        except OSError:
            link_target = None
        try:
            st = os.stat(target)
        except OSError:
            st = lstat
            broken = True
    else:
        st = lstat

    name = os.path.basename(target) or '/'
    if is_link:
        kind = 'link'
        mime = 'inode/directory' if (not broken and stat.S_ISDIR(st.st_mode)) else (None if broken else guess_mime(name))
    elif stat.S_ISDIR(st.st_mode):
        kind = 'dir'
        mime = 'inode/directory'
    elif stat.S_ISREG(st.st_mode):
        kind = 'file'
        mime = guess_mime(name)
    else:
        kind = 'other'
        mime = 'inode/special'

    try:
        owner = pwd.getpwuid(st.st_uid).pw_name
    except KeyError:
        owner = str(st.st_uid)
    try:
        group = grp.getgrgid(st.st_gid).gr_name
    except KeyError:
        group = str(st.st_gid)

    result = {
        'path': target,
        'name': name,
        'kind': kind,
        'mime': mime,
        'size': int(st.st_size),
        'mode': f'{stat.S_IMODE(st.st_mode):04o}',
        'perms': stat.filemode(st.st_mode)[1:],
        'owner': owner,
        'group': group,
        'mtime': int(st.st_mtime),
    }
    if is_link:
        result['link_target'] = link_target
        result['broken'] = broken
    if stat.S_ISDIR(st.st_mode) and not broken:
        dsize, dcount, trunc = recursive_dir_stats(target, max_entries=args.max_entries, timeout_s=args.timeout)
        result['dir_size'] = dsize
        result['dir_count'] = dcount
        result['truncated'] = trunc
    elif mime and mime.startswith('image/') and not broken:
        img = image_metadata(target, mime)
        if img:
            result['image'] = img
    return result


# ---- thumbnails ----

def generate_thumbnail(src_path, mime, dest_png, px):
    import shutil
    import subprocess
    import tempfile
    dest_png.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, tmp_path = tempfile.mkstemp(prefix='.thumb-', suffix='.png', dir=str(dest_png.parent))
    os.close(fd)
    try:
        cmds = []
        if mime.startswith('image/'):
            if shutil.which('vipsthumbnail'):
                cmds.append(['vipsthumbnail', src_path, '-s', str(px), '-o', tmp_path])
            if shutil.which('magick'):
                cmds.append(['magick', f'{src_path}[0]', '-auto-orient', '-thumbnail', f'{px}x{px}', f'PNG:{tmp_path}'])
            elif shutil.which('convert'):
                cmds.append(['convert', f'{src_path}[0]', '-auto-orient', '-thumbnail', f'{px}x{px}', f'PNG:{tmp_path}'])
            if shutil.which('ffmpeg'):
                cmds.append(['ffmpeg', '-y', '-v', 'error', '-i', src_path, '-vf', f"scale='min({px},iw)':-1", '-frames:v', '1', tmp_path])
        elif mime.startswith('video/'):
            if shutil.which('ffmpegthumbnailer'):
                cmds.append(['ffmpegthumbnailer', '-i', src_path, '-o', tmp_path, '-s', str(px)])
            if shutil.which('ffmpeg'):
                cmds.append(['ffmpeg', '-y', '-v', 'error', '-i', src_path, '-vf', f"scale='min({px},iw)':-1", '-frames:v', '1', tmp_path])
        elif mime == 'application/pdf':
            if shutil.which('vipsthumbnail'):
                cmds.append(['vipsthumbnail', f'{src_path}[page=0]', '-s', str(px), '-o', tmp_path])
            if shutil.which('magick'):
                cmds.append(['magick', f'{src_path}[0]', '-thumbnail', f'{px}x{px}', f'PNG:{tmp_path}'])
            elif shutil.which('convert'):
                cmds.append(['convert', f'{src_path}[0]', '-thumbnail', f'{px}x{px}', f'PNG:{tmp_path}'])
            if shutil.which('pdftoppm'):
                prefix = tmp_path[:-4]
                cmds.append(['pdftoppm', '-png', '-singlefile', '-f', '1', '-l', '1', '-scale-to', str(px), src_path, prefix])

        for cmd in cmds:
            try:
                r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10, check=False)
                if r.returncode == 0 and os.path.exists(tmp_path) and os.path.getsize(tmp_path) > 0:
                    os.chmod(tmp_path, 0o600)
                    os.replace(tmp_path, dest_png)
                    return str(dest_png)
            except (OSError, subprocess.SubprocessError):
                continue
        return None
    finally:
        if os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


def cmd_thumb(args):
    import hashlib
    target = os.path.abspath(os.path.expanduser(args.path))
    try:
        st = os.stat(target)
    except FileNotFoundError:
        raise ToolError('not_found', f'No existe «{args.path}»', 'Comprueba la ruta.') from None
    except OSError as exc:
        raise ToolError('io_error', f'No se pudo leer «{args.path}»: {exc.strerror or exc}') from None

    if not stat.S_ISREG(st.st_mode):
        return {'thumb': None}

    size_dir = 'large' if args.size == 'large' else 'normal'
    px = 256 if args.size == 'large' else 128
    uri = Path(target).resolve().as_uri()
    digest = hashlib.md5(uri.encode('utf-8')).hexdigest()
    cache_home = Path(os.environ.get('XDG_CACHE_HOME') or (Path.home() / '.cache'))
    thumb_path = cache_home / 'thumbnails' / size_dir / f'{digest}.png'

    try:
        tst = thumb_path.stat()
        if tst.st_size > 0 and int(tst.st_mtime) >= int(st.st_mtime):
            return {'thumb': str(thumb_path)}
    except OSError:
        pass

    mime = guess_mime(os.path.basename(target))
    if not (mime.startswith('image/') or mime.startswith('video/') or mime == 'application/pdf'):
        return {'thumb': None}

    created = generate_thumbnail(target, mime, thumb_path, px)
    return {'thumb': created}


# ---- open, open-with, terminal-here ----

def application_dirs():
    dirs = []
    data_home = Path(os.environ.get('XDG_DATA_HOME') or (Path.home() / '.local/share'))
    dirs.append(data_home / 'applications')
    data_dirs = os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share')
    for part in data_dirs.split(':'):
        if part.strip():
            dirs.append(Path(part.strip()) / 'applications')
    return dirs


def default_apps_for_mime(mime):
    defaults = []
    cfg_home = Path(os.environ.get('XDG_CONFIG_HOME') or (Path.home() / '.config'))
    data_home = Path(os.environ.get('XDG_DATA_HOME') or (Path.home() / '.local/share'))
    for mfile in (cfg_home / 'mimeapps.list', data_home / 'applications/mimeapps.list'):
        if not mfile.is_file():
            continue
        try:
            for raw in mfile.read_text(encoding='utf-8', errors='replace').splitlines():
                line = raw.strip()
                if '=' not in line or line.startswith('#'):
                    continue
                k, _, v = line.partition('=')
                if k.strip() == mime:
                    for app in v.split(';'):
                        if app.strip() and app.strip() not in defaults:
                            defaults.append(app.strip())
        except OSError:
            pass
    return defaults


def parse_desktop_file(path):
    in_entry = False
    fields = {}
    try:
        for raw in path.read_text(encoding='utf-8', errors='replace').splitlines():
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            if line.startswith('[') and line.endswith(']'):
                in_entry = line == '[Desktop Entry]'
                continue
            if in_entry and '=' in line:
                k, _, v = line.partition('=')
                fields[k.strip()] = v.strip()
    except OSError:
        return None
    if fields.get('Type', 'Application') != 'Application' or fields.get('NoDisplay', '').lower() == 'true':
        return None
    if not fields.get('Exec'):
        return None
    return fields


def find_apps_for_mime(mime):
    defaults = default_apps_for_mime(mime)
    apps = []
    seen = set()
    supertype = mime.split('/', 1)[0] + '/*' if '/' in mime else ''
    for folder in application_dirs():
        if not folder.is_dir():
            continue
        try:
            files = sorted(folder.glob('*.desktop'))
        except OSError:
            continue
        for dfile in files:
            app_id = dfile.name
            if app_id in seen:
                continue
            fields = parse_desktop_file(dfile)
            if not fields:
                continue
            mimes = [m.strip() for m in fields.get('MimeType', '').split(';') if m.strip()]
            if mime not in mimes and supertype not in mimes:
                continue
            seen.add(app_id)
            name = fields.get('Name[es]') or fields.get('Name') or dfile.stem
            apps.append({
                'id': app_id,
                'name': name,
                'default': app_id in defaults,
                '_exec': fields['Exec'],
                '_path': str(dfile),
            })
    if apps and not any(a['default'] for a in apps):
        apps[0]['default'] = True
    apps.sort(key=lambda a: (0 if a['default'] else 1, natural_key(a['name'])))
    return apps


def expand_desktop_exec(exec_line, target):
    import shlex
    tokens = shlex.split(exec_line)
    argv = []
    inserted = False
    for tok in tokens:
        if tok in ('%f', '%F', '%u', '%U'):
            argv.append(target)
            inserted = True
        elif tok.startswith('%') and len(tok) == 2:
            continue
        else:
            argv.append(tok)
    if not inserted:
        argv.append(target)
    return argv


def cmd_open(args):
    import shutil
    import subprocess
    raw_path = args.path
    if '://' in raw_path:
        target = raw_path
    else:
        target = os.path.abspath(os.path.expanduser(raw_path))
        if not os.path.exists(target):
            raise ToolError('not_found', f'No existe «{raw_path}»', 'Comprueba la ruta.')
    if shutil.which('xdg-open'):
        cmd = ['xdg-open', target]
    elif shutil.which('gio'):
        cmd = ['gio', 'open', target]
    else:
        raise ToolError('missing_opener', 'No se encontró xdg-open ni gio para abrir el archivo.', 'Instala xdg-utils o glib2.')
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return {'path': target}


def cmd_open_with(args):
    import shutil
    import subprocess
    target = os.path.abspath(os.path.expanduser(args.path))
    if not os.path.exists(target):
        raise ToolError('not_found', f'No existe «{args.path}»', 'Comprueba la ruta.')
    mime = 'inode/directory' if os.path.isdir(target) else guess_mime(os.path.basename(target))
    if args.list_apps:
        apps = [{'id': a['id'], 'name': a['name'], 'default': a['default']} for a in find_apps_for_mime(mime)]
        return {'apps': apps}
    if not args.app:
        raise ToolError('invalid_usage', 'Indica --list o --app <id>.')

    app_id = args.app
    want = app_id if app_id.endswith('.desktop') else f'{app_id}.desktop'
    for folder in application_dirs():
        candidate = folder / want
        if candidate.is_file():
            fields = parse_desktop_file(candidate)
            if fields and fields.get('Exec'):
                argv = expand_desktop_exec(fields['Exec'], target)
                try:
                    subprocess.Popen(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                except FileNotFoundError:
                    raise ToolError('app_not_found', f'El ejecutable de «{app_id}» no está disponible.') from None
                return {'app': app_id, 'path': target}
    if shutil.which(app_id):
        subprocess.Popen([app_id, target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return {'app': app_id, 'path': target}
    raise ToolError('app_not_found', f'No se encontró la aplicación «{app_id}».', 'Elige otra aplicación.')


def cmd_terminal_here(args):
    import shutil
    import subprocess
    target = os.path.abspath(os.path.expanduser(args.path))
    if not os.path.exists(target):
        raise ToolError('not_found', f'No existe «{args.path}»', 'Comprueba la ruta.')
    folder = target if os.path.isdir(target) else os.path.dirname(target)
    custom = os.environ.get('DRAGON_TERMINAL', '').strip()
    if custom and shutil.which(custom):
        cmd = [custom, folder]
    elif shutil.which('ghostty'):
        cmd = ['ghostty', f'--working-directory={folder}']
    elif shutil.which('kitty'):
        cmd = ['kitty', '--directory', folder]
    elif shutil.which('xdg-terminal-exec'):
        cmd = ['xdg-terminal-exec']
    else:
        raise ToolError('missing_terminal', 'No se encontró ninguna terminal (ghostty o kitty).', 'Instala ghostty o kitty.')
    subprocess.Popen(cmd, cwd=folder, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return {'path': folder}


# ---- file operations (d2: copy, move, rename, mkdir, link, trash, delete) ----

def split_stem_ext(name, is_dir=False):
    if is_dir:
        return name, ''
    ext = ext_of(name)
    if ext and len(name) > len(ext):
        return name[:-len(ext)], ext
    return name, ''


def unique_dest_path(dest_dir, name, is_dir=False):
    candidate = os.path.join(dest_dir, name)
    if not os.path.lexists(candidate):
        return candidate
    stem, ext = split_stem_ext(name, is_dir=is_dir)
    idx = 1
    while True:
        cand = os.path.join(dest_dir, f'{stem} ({idx}){ext}')
        if not os.path.lexists(cand):
            return cand
        idx += 1


def resolve_conflict(src_path, dest_path, policy, is_dir=False):
    if not os.path.lexists(dest_path):
        return dest_path, False
    mode = policy['mode']
    if mode == 'ask' and not policy['apply_all']:
        emit({'t': 'conflict', 'file': src_path, 'dest': dest_path})
        line = sys.stdin.readline()
        if not line:
            choice = 'skip'
        else:
            try:
                ans = json.loads(line.strip())
                choice = ans.get('answer', 'skip')
                if choice not in ('skip', 'overwrite', 'rename'):
                    choice = 'skip'
                if ans.get('all'):
                    policy['mode'] = choice
                    policy['apply_all'] = True
            except Exception:
                choice = 'skip'
    else:
        choice = mode

    if choice == 'skip':
        return None, False
    if choice == 'rename':
        return unique_dest_path(os.path.dirname(dest_path), os.path.basename(dest_path), is_dir=is_dir), False
    return dest_path, True


def remove_existing_target(target):
    import shutil
    if os.path.islink(target) or not os.path.isdir(target):
        os.unlink(target)
    else:
        shutil.rmtree(target)


def total_bytes_of(paths):
    total = 0
    for p in paths:
        try:
            st = os.lstat(p)
        except OSError:
            continue
        if stat.S_ISREG(st.st_mode):
            total += int(st.st_size)
        elif stat.S_ISDIR(st.st_mode):
            for root, _, files in os.walk(p, followlinks=False):
                for fname in files:
                    try:
                        fst = os.lstat(os.path.join(root, fname))
                        if stat.S_ISREG(fst.st_mode):
                            total += int(fst.st_size)
                    except OSError:
                        pass
    return total


def copy_single_file(src, dst, tracker, index, count, overwrite=False):
    import shutil
    import tempfile
    lstat = os.lstat(src)
    if stat.S_ISLNK(lstat.st_mode):
        if overwrite and os.path.lexists(dst):
            remove_existing_target(dst)
        link_to = os.readlink(src)
        os.symlink(link_to, dst)
        return

    dest_dir = os.path.dirname(dst)
    os.makedirs(dest_dir, exist_ok=True)
    fd, tmp_dst = tempfile.mkstemp(prefix=f'.dragon-part-{os.path.basename(dst)}-', dir=dest_dir)
    _CLEANUP_PATHS.add(tmp_dst)
    slow_ms = int(os.environ.get('DRAGON_FILES_SLOW_MS', '0') or '0')
    try:
        with open(src, 'rb') as fsrc, os.fdopen(fd, 'wb') as fdst:
            while True:
                buf = fsrc.read(262144)
                if not buf:
                    break
                fdst.write(buf)
                tracker['done_bytes'] += len(buf)
                elapsed = max(0.001, time.perf_counter() - tracker['start'])
                bps = int(tracker['done_bytes'] / elapsed)
                pct = min(99, int((tracker['done_bytes'] * 100) / max(1, tracker['total_bytes'])))
                now = time.perf_counter()
                if tracker.get('progress', True) and (now - tracker['last_emit'] >= 0.04 or slow_ms > 0):
                    tracker['last_emit'] = now
                    emit({'t': 'progress', 'pct': pct, 'file': os.path.basename(src), 'bps': bps, 'index': index, 'count': count})
                if slow_ms > 0:
                    time.sleep(slow_ms / 1000.0)
        shutil.copystat(src, tmp_dst, follow_symlinks=False)
        if overwrite and os.path.isdir(dst) and not os.path.islink(dst):
            shutil.rmtree(dst)
        os.replace(tmp_dst, dst)
    finally:
        _CLEANUP_PATHS.discard(tmp_dst)
        if os.path.lexists(tmp_dst):
            try:
                os.unlink(tmp_dst)
            except OSError:
                pass


def copy_tree_item(src, dst, tracker, index, count, overwrite=False):
    import shutil
    lstat = os.lstat(src)
    if not stat.S_ISDIR(lstat.st_mode) or stat.S_ISLNK(lstat.st_mode):
        copy_single_file(src, dst, tracker, index, count, overwrite=overwrite)
        return
    if overwrite and os.path.lexists(dst) and (os.path.islink(dst) or not os.path.isdir(dst)):
        remove_existing_target(dst)
    os.makedirs(dst, exist_ok=True)
    for entry in os.scandir(src):
        sub_src = entry.path
        sub_dst = os.path.join(dst, entry.name)
        if entry.is_dir(follow_symlinks=False):
            copy_tree_item(sub_src, sub_dst, tracker, index, count, overwrite=True)
        else:
            copy_single_file(sub_src, sub_dst, tracker, index, count, overwrite=True)
    try:
        shutil.copystat(src, dst, follow_symlinks=False)
    except OSError:
        pass


def trash_put_one(src_path):
    import datetime
    import shutil
    import urllib.parse
    troot = trash_root()
    files_dir = troot / 'files'
    info_dir = troot / 'info'
    files_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    info_dir.mkdir(parents=True, exist_ok=True, mode=0o700)

    base = os.path.basename(src_path)
    stem, ext = split_stem_ext(base, is_dir=os.path.isdir(src_path) and not os.path.islink(src_path))
    candidate = base
    idx = 1
    info_fd = None
    info_path = None
    while True:
        try_info = info_dir / f'{candidate}.trashinfo'
        if not (files_dir / candidate).exists() and not os.path.lexists(files_dir / candidate):
            try:
                info_fd = os.open(str(try_info), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
                info_path = try_info
                break
            except FileExistsError:
                pass
        candidate = f'{stem} ({idx}){ext}'
        idx += 1

    dest_file = files_dir / candidate
    now_iso = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
    quoted_path = urllib.parse.quote(src_path, safe='/')
    content = f'[Trash Info]\nPath={quoted_path}\nDeletionDate={now_iso}\n'
    try:
        with os.fdopen(info_fd, 'w', encoding='utf-8') as handle:
            handle.write(content)
        try:
            os.replace(src_path, str(dest_file))
        except OSError:
            shutil.move(src_path, str(dest_file))
    except Exception:
        if info_path and info_path.exists():
            try:
                info_path.unlink()
            except OSError:
                pass
        raise
    return 'trash:///' + urllib.parse.quote(candidate)


def validate_simple_name(name):
    if not name or name in ('.', '..') or '/' in name or '\0' in name:
        raise ToolError('invalid_name', f'Nombre no válido: «{name}».', 'Usa un nombre sin barras.')
    return name


def check_not_inside(src, dest_dir):
    real_src = os.path.abspath(src)
    real_dst = os.path.abspath(dest_dir)
    if real_dst == real_src or real_dst.startswith(real_src.rstrip('/') + '/'):
        raise ToolError('invalid_dest', 'No se puede copiar ni mover una carpeta dentro de sí misma.', 'Elige otra carpeta de destino.')


def cmd_op(args):
    import shutil
    kind = args.operation
    policy = {'mode': args.conflict, 'apply_all': args.conflict != 'ask'}
    moved = []
    want_progress = bool(args.json_progress)

    if kind == 'mkdir':
        if not args.paths:
            raise ToolError('invalid_usage', 'Falta la carpeta donde crear el directorio.')
        parent_dir = os.path.abspath(os.path.expanduser(args.paths[0]))
        name = validate_simple_name(args.name)
        target = os.path.join(parent_dir, name)
        if os.path.lexists(target):
            raise ToolError('already_exists', f'Ya existe «{name}» en la carpeta.', 'Elige otro nombre.')
        try:
            os.makedirs(target, exist_ok=False)
        except PermissionError:
            raise ToolError('permission_denied', f'Permiso denegado al crear «{name}».') from None
        if want_progress:
            emit({'t': 'progress', 'pct': 100, 'file': name, 'bps': 0, 'index': 1, 'count': 1})
        return {'t': 'done', 'path': target, 'moved': []}

    if kind == 'rename':
        if not args.paths:
            raise ToolError('invalid_usage', 'Falta la ruta a renombrar.')
        src = os.path.abspath(os.path.expanduser(args.paths[0]))
        if not os.path.lexists(src):
            raise ToolError('not_found', f'No existe «{args.paths[0]}».')
        name = validate_simple_name(args.name)
        dst = os.path.join(os.path.dirname(src), name)
        if dst != src and os.path.lexists(dst):
            raise ToolError('already_exists', f'Ya existe «{name}».', 'Elige otro nombre.')
        if dst != src:
            os.replace(src, dst)
        moved.append({'from': src, 'to': dst})
        if want_progress:
            emit({'t': 'progress', 'pct': 100, 'file': name, 'bps': 0, 'index': 1, 'count': 1})
        return {'t': 'done', 'moved': moved}

    if kind == 'trash':
        sources = [os.path.abspath(os.path.expanduser(p)) for p in args.paths]
        count = len(sources)
        for idx, src in enumerate(sources, 1):
            if not os.path.lexists(src):
                raise ToolError('not_found', f'No existe «{src}».')
            trash_put_one(src)
            pct = int((idx * 100) / max(1, count))
            if want_progress:
                emit({'t': 'progress', 'pct': pct, 'file': os.path.basename(src), 'bps': 0, 'index': idx, 'count': count})
        return {'t': 'done', 'moved': []}

    if kind == 'delete':
        if not args.confirm:
            raise ToolError('confirm_required', 'El borrado permanente exige --confirm.', 'Confirma la operación con --confirm.')
        count = len(args.paths)
        troot = trash_root()
        for idx, raw in enumerate(args.paths, 1):
            if raw.startswith('trash:'):
                import urllib.parse
                tname = urllib.parse.unquote(raw.split('trash:///', 1)[-1].lstrip('/'))
                tfile = troot / 'files' / tname
                tinfo = troot / 'info' / f'{tname}.trashinfo'
                if os.path.lexists(tfile):
                    remove_existing_target(str(tfile))
                if tinfo.exists():
                    tinfo.unlink()
                label = tname
            else:
                src = os.path.abspath(os.path.expanduser(raw))
                if not os.path.lexists(src):
                    raise ToolError('not_found', f'No existe «{raw}».')
                remove_existing_target(src)
                label = os.path.basename(src)
            pct = int((idx * 100) / max(1, count))
            if want_progress:
                emit({'t': 'progress', 'pct': pct, 'file': label, 'bps': 0, 'index': idx, 'count': count})
        return {'t': 'done', 'moved': []}

    if not args.dest:
        raise ToolError('invalid_usage', 'Falta la carpeta de destino (--dest).')
    dest_dir = os.path.abspath(os.path.expanduser(args.dest))
    if not os.path.isdir(dest_dir):
        raise ToolError('not_found', f'No existe la carpeta de destino «{args.dest}».')

    sources = [os.path.abspath(os.path.expanduser(p)) for p in args.paths]
    count = len(sources)
    for src in sources:
        if not os.path.lexists(src):
            raise ToolError('not_found', f'No existe «{src}».')
        if os.path.isdir(src) and not os.path.islink(src):
            check_not_inside(src, dest_dir)

    if kind == 'link':
        for idx, src in enumerate(sources, 1):
            is_dir = os.path.isdir(src) and not os.path.islink(src)
            raw_dst = os.path.join(dest_dir, os.path.basename(src))
            dst, overwrite = resolve_conflict(src, raw_dst, policy, is_dir=is_dir)
            if dst is None:
                continue
            if overwrite and os.path.lexists(dst):
                remove_existing_target(dst)
            os.symlink(src, dst)
            pct = int((idx * 100) / max(1, count))
            if want_progress:
                emit({'t': 'progress', 'pct': pct, 'file': os.path.basename(src), 'bps': 0, 'index': idx, 'count': count})
        return {'t': 'done', 'moved': []}

    total_bytes = total_bytes_of(sources)
    free_bytes, _, _ = filesystem_info(dest_dir)
    if kind == 'copy' and free_bytes > 0 and total_bytes > free_bytes:
        raise ToolError('no_space', 'No queda espacio suficiente en el destino.', 'Libera espacio e inténtalo de nuevo.')

    tracker = {'total_bytes': max(1, total_bytes), 'done_bytes': 0, 'start': time.perf_counter(), 'last_emit': 0.0, 'progress': want_progress}
    for idx, src in enumerate(sources, 1):
        is_dir = os.path.isdir(src) and not os.path.islink(src)
        raw_dst = os.path.join(dest_dir, os.path.basename(src))
        if kind == 'move' and os.path.abspath(src) == os.path.abspath(raw_dst):
            continue
        dst, overwrite = resolve_conflict(src, raw_dst, policy, is_dir=is_dir)
        if dst is None:
            continue
        if want_progress:
            emit({'t': 'progress', 'pct': int(((idx - 1) * 100) / max(1, count)), 'file': os.path.basename(src), 'bps': 0, 'index': idx, 'count': count})
        if kind == 'copy':
            copy_tree_item(src, dst, tracker, idx, count, overwrite=overwrite)
        elif kind == 'move':
            if overwrite and os.path.lexists(dst):
                remove_existing_target(dst)
            try:
                os.replace(src, dst)
            except OSError:
                if free_bytes > 0 and total_bytes > free_bytes:
                    raise ToolError('no_space', 'No queda espacio suficiente en el destino.', 'Libera espacio e inténtalo de nuevo.') from None
                copy_tree_item(src, dst, tracker, idx, count, overwrite=overwrite)
                remove_existing_target(src)
            moved.append({'from': src, 'to': dst})
        elapsed = max(0.001, time.perf_counter() - tracker['start'])
        bps = int(tracker['done_bytes'] / elapsed)
        if want_progress:
            emit({'t': 'progress', 'pct': int((idx * 100) / max(1, count)), 'file': os.path.basename(src), 'bps': bps, 'index': idx, 'count': count})

    return {'t': 'done', 'moved': moved}


def cmd_trash(args):
    import urllib.parse
    troot = trash_root()
    files_dir = troot / 'files'
    info_dir = troot / 'info'
    want_progress = bool(args.json_progress)

    if args.operation == 'empty':
        if not args.confirm:
            raise ToolError('confirm_required', 'Vaciar la papelera exige --confirm.', 'Confirma con --confirm.')
        items = list(files_dir.iterdir()) if files_dir.is_dir() else []
        count = max(1, len(items))
        for idx, item in enumerate(items, 1):
            remove_existing_target(str(item))
            info_file = info_dir / f'{item.name}.trashinfo'
            if info_file.exists():
                try:
                    info_file.unlink()
                except OSError:
                    pass
            if want_progress:
                emit({'t': 'progress', 'pct': int((idx * 100) / count), 'file': item.name, 'bps': 0, 'index': idx, 'count': count})
        if info_dir.is_dir():
            for leftover in info_dir.glob('*.trashinfo'):
                try:
                    leftover.unlink()
                except OSError:
                    pass
        return {'t': 'done', 'moved': []}

    if not args.uris:
        raise ToolError('invalid_usage', 'Indica los elementos de la papelera a restaurar.')
    policy = {'mode': args.conflict, 'apply_all': args.conflict != 'ask'}
    moved = []
    count = len(args.uris)
    for idx, raw_uri in enumerate(args.uris, 1):
        if raw_uri.startswith('trash:'):
            name = urllib.parse.unquote(raw_uri.split('trash:///', 1)[-1].lstrip('/'))
        else:
            name = os.path.basename(raw_uri)
        src_file = files_dir / name
        info_file = info_dir / f'{name}.trashinfo'
        if not os.path.lexists(src_file):
            raise ToolError('not_found', f'No está en la papelera: «{name}».')
        orig_path, _ = parse_trashinfo(info_file)
        if not orig_path:
            orig_path = str(Path(os.environ.get('HOME') or Path.home()) / name)
        os.makedirs(os.path.dirname(orig_path), exist_ok=True)
        is_dir = os.path.isdir(src_file) and not os.path.islink(src_file)
        dst, overwrite = resolve_conflict(str(src_file), orig_path, policy, is_dir=is_dir)
        if dst is None:
            continue
        if overwrite and os.path.lexists(dst):
            remove_existing_target(dst)
        try:
            os.replace(str(src_file), dst)
        except OSError:
            import shutil
            shutil.move(str(src_file), dst)
        if info_file.exists():
            try:
                info_file.unlink()
            except OSError:
                pass
        moved.append({'from': raw_uri, 'to': dst})
        if want_progress:
            emit({'t': 'progress', 'pct': int((idx * 100) / max(1, count)), 'file': name, 'bps': 0, 'index': idx, 'count': count})
    return {'t': 'done', 'moved': moved}


def build_parser():
    parser = Parser(description='Herramienta del explorador de archivos de dragon-island (JSON).')
    sub = parser.add_subparsers(dest='cmd', required=True)

    p = sub.add_parser('ls')
    p.add_argument('path', nargs='?', default='.')
    p.add_argument('--hidden', action='store_true')
    p.add_argument('--sort', choices=('name', 'size', 'mtime', 'type'), default='name')
    p.add_argument('--dirs-first', action='store_true')
    p.add_argument('--git', action='store_true')
    p.add_argument('--limit', type=int, default=None)
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('places')
    p.add_argument('action', nargs='?', choices=('add', 'rm'))
    p.add_argument('path', nargs='?')
    p.add_argument('--label', default='')
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('watch')
    p.add_argument('path')
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('props')
    p.add_argument('path')
    p.add_argument('--max-entries', type=int, default=10000)
    p.add_argument('--timeout', type=float, default=1.5)
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('thumb')
    p.add_argument('path')
    p.add_argument('--size', choices=('normal', 'large'), default='normal')
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('open')
    p.add_argument('path')
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('open-with')
    p.add_argument('path')
    p.add_argument('--list', dest='list_apps', action='store_true')
    p.add_argument('--app', default='')
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('terminal-here')
    p.add_argument('path')
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('op')
    p.add_argument('operation', choices=('copy', 'move', 'trash', 'delete', 'rename', 'mkdir', 'link'))
    p.add_argument('paths', nargs='+')
    p.add_argument('--dest', default='')
    p.add_argument('--name', default='')
    p.add_argument('--conflict', choices=('ask', 'skip', 'overwrite', 'rename'), default='ask')
    p.add_argument('--confirm', action='store_true')
    p.add_argument('--json-progress', dest='json_progress', action='store_true')
    p.add_argument('--json', action='store_true')

    p = sub.add_parser('trash')
    p.add_argument('operation', choices=('empty', 'restore'))
    p.add_argument('uris', nargs='*')
    p.add_argument('--conflict', choices=('ask', 'skip', 'overwrite', 'rename'), default='rename')
    p.add_argument('--confirm', action='store_true')
    p.add_argument('--json-progress', dest='json_progress', action='store_true')
    p.add_argument('--json', action='store_true')

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    if args.cmd == 'ls':
        result = cmd_ls(args)
    elif args.cmd == 'places':
        result = cmd_places(args)
    elif args.cmd == 'watch':
        cmd_watch(args)
        return 0
    elif args.cmd == 'props':
        result = cmd_props(args)
    elif args.cmd == 'thumb':
        result = cmd_thumb(args)
    elif args.cmd == 'open':
        result = cmd_open(args)
    elif args.cmd == 'open-with':
        result = cmd_open_with(args)
    elif args.cmd == 'terminal-here':
        result = cmd_terminal_here(args)
    elif args.cmd == 'op':
        result = cmd_op(args)
    elif args.cmd == 'trash':
        result = cmd_trash(args)
    else:
        raise ToolError('unsupported', f'Subcomando no soportado: {args.cmd}')
    emit({'ok': True, **result})
    return 0


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, _cleanup_on_signal)
    try:
        sys.exit(main() or 0)
    except ToolError as exc:
        err_payload = error(exc.code, exc.message, exc.hint)
        err_payload['t'] = 'error'
        emit(err_payload)
        sys.exit(1)
    except (KeyboardInterrupt, BrokenPipeError):
        _cleanup_on_signal()
    except OSError as exc:
        err_payload = error('io_error', f'Error de entrada/salida: {exc.strerror or exc}')
        err_payload['t'] = 'error'
        emit(err_payload)
        sys.exit(1)
