"""Small offline engine helpers. State is private, locked and atomically replaced."""
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import tempfile
import unicodedata


def state_path(name):
    return Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'dragon-island' / name


def config_path(name):
    return Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'dragon-island' / name


def read_json(path, default):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except FileNotFoundError:
        return default


@contextmanager
def locked(path):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(str(path) + '.lock', os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(fd, 'a') as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def atomic_json(path, data):
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            json.dump(data, handle, ensure_ascii=False, allow_nan=False, sort_keys=True, separators=(',', ':'))
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def folded(text):
    if text.isascii():
        return text.casefold()
    return ''.join(c for c in unicodedata.normalize('NFKD', text.casefold()) if not unicodedata.combining(c))


# Compatibility exports for existing engine consumers.
from secret_filter import secret_spans, masked


def result(identifier, title, sub, icon, kind, action, score):
    return dict(id=identifier, title=title, sub=sub, icon=icon, kind=kind, action=action, score=score)
