"""Dragon Portal — pure logic (no D-Bus, no Gio): request building, private channel files, reply validation, URIs.

Channel (docs/handoff-fase-6-portal.md): `$XDG_RUNTIME_DIR/dragon-portal/` (0700) holds `req/<id>.json` (written by the service)
and `rep/<id>.json` (written by `dragon-portal reply`), both 0600 and replaced atomically. Ids are 32 hex characters made by the
service; nothing else is ever used as a file name. Paths travel only inside JSON, never on a command line.
"""
import json
import os
import re
import secrets
import stat
import time
from urllib.parse import quote

ID_RE = re.compile(r'^[0-9a-f]{32}$')
MAX_JSON = 1 << 20            # a request or reply bigger than this is refused
MAX_PATHS = 4096
KINDS = ('open', 'save', 'save_files')


class PortalError(Exception):
    def __init__(self, code, message, hint=''):
        self.code, self.message, self.hint = code, message, hint
        super().__init__(message)


def error(code, message, hint=''):
    return dict(ok=False, error=dict(code=code, message=message, hint=hint))


def new_id():
    return secrets.token_hex(16)


def check_id(value):
    if not isinstance(value, str) or not ID_RE.match(value):
        raise PortalError('invalid_id', 'Identificador de petición no válido', 'Lo genera dragon-portal; no lo escribas a mano.')
    return value


# ---------------------------------------------------------------- channel directory
def runtime_dir():
    base = os.environ.get('XDG_RUNTIME_DIR')
    if not base:
        raise PortalError('no_runtime_dir', 'No hay XDG_RUNTIME_DIR', 'Inicia sesión con systemd/logind.')
    return os.path.join(base, 'dragon-portal')


def _private_dir(path):
    """Create `path` (0700) or verify it: ours, a real directory (not a link), no access for others."""
    try:
        os.mkdir(path, 0o700)
    except FileExistsError:
        pass
    st = os.lstat(path)
    if not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid():
        raise PortalError('unsafe_channel', 'La carpeta del canal no es del usuario o no es una carpeta', path)
    if st.st_mode & 0o077:
        os.chmod(path, 0o700)
    return path


def channel(kind):
    """`req` or `rep` directory, created private on demand."""
    root = _private_dir(runtime_dir())
    return _private_dir(os.path.join(root, kind))


def write_private_json(directory, name, data):
    """Atomic 0600 write: temporary file created O_EXCL, fsynced, then renamed over `name`."""
    raw = json.dumps(data, ensure_ascii=False, allow_nan=False, separators=(',', ':')).encode('utf-8', 'surrogateescape')
    if len(raw) > MAX_JSON:
        raise PortalError('too_large', 'El mensaje es demasiado grande')
    tmp = os.path.join(directory, '.' + name + '.' + secrets.token_hex(4))
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(raw + b'\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, os.path.join(directory, name))
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
    return os.path.join(directory, name)


def read_private_json(directory, name):
    """Read a channel file only if it is a regular file of ours with mode 0600 (no links, nothing readable by others)."""
    path = os.path.join(directory, name)
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise PortalError('unsafe_channel', 'No se puede abrir el archivo del canal: ' + exc.strerror, path)
    with os.fdopen(fd, 'rb') as handle:
        st = os.fstat(handle.fileno())
        if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid() or st.st_mode & 0o077:
            raise PortalError('unsafe_channel', 'El archivo del canal no es privado (se exige 0600 y del usuario)', path)
        raw = handle.read(MAX_JSON + 1)
    if len(raw) > MAX_JSON:
        raise PortalError('too_large', 'El mensaje es demasiado grande')
    try:
        return json.loads(raw.decode('utf-8', 'surrogateescape'))
    except ValueError:
        raise PortalError('invalid_json', 'El archivo del canal no es JSON válido')


def remove_quiet(directory, name):
    try:
        os.unlink(os.path.join(directory, name))
    except FileNotFoundError:
        pass


def sweep(max_age=3600):
    """Delete channel files older than `max_age` seconds (left by a crashed service)."""
    now = time.time()
    for kind in ('req', 'rep'):
        directory = channel(kind)
        for name in os.listdir(directory):
            full = os.path.join(directory, name)
            try:
                if now - os.lstat(full).st_mtime > max_age:
                    os.unlink(full)
            except OSError:
                pass


# ---------------------------------------------------------------- D-Bus option helpers (already unpacked to python)
def clean_text(value, limit=200):
    """Text shown in the UI: control characters (newlines included) become spaces; length bounded."""
    text = ''.join(' ' if (ord(c) < 32 or ord(c) == 127) else c for c in str(value))
    return ' '.join(text.split())[:limit]


def bytes_to_path(value):
    """`ay` option (NUL-terminated file-system encoded path) → str path or ''. Relative paths are refused."""
    if isinstance(value, str):
        raw = os.fsencode(value)
    else:
        raw = bytes(value or b'')
    raw = raw.split(b'\0', 1)[0]
    if not raw:
        return ''
    path = os.fsdecode(raw)
    return os.path.normpath(path) if path.startswith('/') else ''


def parse_filter(value):
    """`(sa(us))` → {name, patterns:[{type:'glob'|'mime', value}]}; invalid pieces are dropped."""
    name, rules = value
    patterns = []
    for kind, text in rules:
        if kind in (0, 1) and isinstance(text, str) and text and '\0' not in text:
            patterns.append(dict(type='glob' if kind == 0 else 'mime', value=text))
    return dict(name=clean_text(name) or 'Filtro', patterns=patterns)


def _same_filter(a, b):
    return a['patterns'] == b['patterns'] and a['name'] == b['name']


def parse_choices(value):
    out = []
    for cid, label, options, initial in value:
        if not cid:
            continue
        opts = [dict(id=oid, label=clean_text(olabel)) for oid, olabel in options if oid]
        sel = initial if any(o['id'] == initial for o in opts) else (opts[0]['id'] if opts else initial)
        out.append(dict(id=cid, label=clean_text(label), options=opts, selected=sel))
    return out


def file_names(value):
    """`files` of SaveFiles (`aay`): each one NUL-terminated; only plain names are kept (no `/`, not `.`/`..`, no empty)."""
    names = []
    for raw in value or ():
        name = os.fsdecode(bytes(raw).split(b'\0', 1)[0])
        name = name.replace('/', '_')
        if name in ('', '.', '..'):
            continue
        names.append(name[:255])
    return names


def build_request(kind, app_id, title, options, home, now=None):
    """Turn the unpacked D-Bus call into the JSON the explorer receives. `options` is a plain dict (variants unpacked)."""
    if kind not in KINDS:
        raise PortalError('invalid_kind', 'Tipo de petición desconocido')
    opts = options or {}
    filters = [parse_filter(f) for f in opts.get('filters', ())] if kind != 'save_files' else []
    current = None
    if kind != 'save_files' and opts.get('current_filter'):
        cf = parse_filter(opts['current_filter'])
        for index, candidate in enumerate(filters):
            if _same_filter(candidate, cf):
                current = index
                break
        else:
            if not filters:                     # «may be specified when the list is empty to apply the filter unconditionally»
                filters, current = [cf], 0
    folder = bytes_to_path(opts.get('current_folder'))
    current_file = bytes_to_path(opts.get('current_file')) if kind == 'save' else ''
    name = ''
    if kind == 'save':
        raw_name = str(opts.get('current_name', '')).replace('\0', '')
        name = raw_name.replace('/', '_')[:255]
        if not name and current_file:
            name = os.path.basename(current_file)
        if not folder and current_file:
            folder = os.path.dirname(current_file)
    request = dict(
        id=new_id(), kind=kind, app_id=clean_text(app_id, 120), title=clean_text(title) or ('Abrir' if kind == 'open' else 'Guardar'),
        accept_label=clean_text(str(opts.get('accept_label', '')).replace('_', ''), 40),
        multiple=bool(opts.get('multiple', False)) and kind == 'open',
        directory=bool(opts.get('directory', False)) and kind == 'open',
        save_folder=(kind == 'save_files'),
        filters=filters, current_filter=current if current is not None else (0 if filters else -1),
        choices=parse_choices(opts.get('choices', ())),
        current_folder=folder or home, current_name=name,
        files=file_names(opts.get('files')) if kind == 'save_files' else [],
        created=int(now if now is not None else time.time()),
    )
    return request


# ---------------------------------------------------------------- reply validation and URIs
def uri_for_path(path):
    """RFC 8089 `file://` URI of an absolute path, byte-exact: every byte outside the unreserved set and `/` is %-escaped
    (newlines, spaces, `#`, `?`, `%`, non-UTF-8 bytes). A leading `-` is harmless in a URI."""
    if not isinstance(path, str) or not path.startswith('/') or '\0' in path:
        raise PortalError('invalid_path', 'Ruta no válida')
    return 'file://' + quote(os.fsencode(os.path.normpath(path)), safe='/')


def unique_path(directory, name, taken=()):
    """`name`, or `stem (1).ext`, `stem (2).ext`… when it already exists in `directory` or is in `taken`."""
    candidate = os.path.join(directory, name)
    if not os.path.lexists(candidate) and candidate not in taken:
        return candidate
    stem, ext = os.path.splitext(name)
    if name.startswith('.') and stem == name:
        stem, ext = name, ''
    for n in range(1, 10000):
        candidate = os.path.join(directory, '%s (%d)%s' % (stem, n, ext))
        if not os.path.lexists(candidate) and candidate not in taken:
            return candidate
    raise PortalError('no_unique_name', 'No se encontró un nombre libre')


def _abs(path):
    if not isinstance(path, str) or not path.startswith('/') or '\0' in path:
        raise PortalError('invalid_path', 'El explorador devolvió una ruta no válida')
    return os.path.normpath(path)


def reply_to_results(request, reply):
    """Validate the explorer's reply against its request and build the portal answer.

    Returns (response, results) where `response` is 0 (accepted), 1 (cancelled) and `results` is a plain dict:
    uris[list of str], filter_index[int|None], choices[list of (id, selected)]. Raises PortalError when the reply breaks the rules
    (more paths than allowed, a file where a folder is required, a relative path…): the service answers «2» for those.
    """
    if not isinstance(reply, dict) or reply.get('id') != request['id']:
        raise PortalError('mismatch', 'La respuesta no corresponde a la petición')
    if reply.get('response') == 'cancel':
        return 1, {}
    if reply.get('response') != 'accept':
        raise PortalError('invalid_reply', 'Respuesta desconocida')
    raw = reply.get('paths')
    if not isinstance(raw, list) or len(raw) > MAX_PATHS:
        raise PortalError('invalid_reply', 'Faltan las rutas elegidas')
    kind = request['kind']
    paths = [_abs(p) for p in raw]
    if kind == 'open':
        if not paths or (len(paths) > 1 and not request['multiple']):
            raise PortalError('invalid_reply', 'Cantidad de elementos no permitida')
        for p in paths:
            if request['directory'] and not os.path.isdir(p):
                raise PortalError('invalid_reply', 'Se pidió una carpeta')
            if not request['directory'] and os.path.isdir(p):
                raise PortalError('invalid_reply', 'Se pidió un archivo, no una carpeta')
            if not os.path.lexists(p):
                raise PortalError('invalid_reply', 'El elemento elegido no existe')
    elif kind == 'save':
        if len(paths) != 1 or paths[0] == '/' or os.path.basename(paths[0]) in ('', '.', '..'):
            raise PortalError('invalid_reply', 'Hace falta exactamente un nombre de archivo')
        if not os.path.isdir(os.path.dirname(paths[0])) or os.path.isdir(paths[0]):
            raise PortalError('invalid_reply', 'La carpeta de destino no existe o el nombre es una carpeta')
    else:                                           # save_files: the explorer picks the destination folder
        if len(paths) != 1 or not os.path.isdir(paths[0]):
            raise PortalError('invalid_reply', 'Hace falta una carpeta de destino')
        final = []
        for n in request['files']:
            final.append(unique_path(paths[0], n, final))   # two equal names in one call stay different too
        paths = final
        if not paths:
            raise PortalError('invalid_reply', 'No hay nombres que guardar')
    index = reply.get('filter')
    if not isinstance(index, int) or isinstance(index, bool) or not (0 <= index < len(request['filters'])):
        index = None
    wanted = {c['id']: c for c in request['choices']}
    chosen = reply.get('choices') if isinstance(reply.get('choices'), dict) else {}
    picked = []
    for cid, choice in wanted.items():
        value = chosen.get(cid, choice['selected'])
        if choice['options'] and not any(o['id'] == value for o in choice['options']):
            value = choice['selected']
        picked.append((cid, value))
    return 0, dict(uris=[uri_for_path(p) for p in paths], filter_index=index, choices=picked)
