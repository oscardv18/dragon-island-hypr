"""Small offline engine helpers. State is private, locked and atomically replaced."""
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import re
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


SECRET = re.compile(
    r'(?i)(?:\b[A-Z_][A-Z0-9_]*(?:_KEY|_TOKEN|PASSWORD[A-Z0-9_]*)\s*=\s*\S+'
    r'|\b(?:PASSWORD|TOKEN|API_KEY)\s*[=:]\s*\S+|\bBearer\s+\S+'
    r'|[a-z][a-z0-9+.-]*://[^\s/@]+:[^\s/@]*@[^\s]+'
    r'|\bsk-[A-Za-z0-9_-]{8,}|\bgh[pousr]_[A-Za-z0-9_]{8,}|\bAKIA[A-Z0-9]{12,})')
TOKEN = re.compile(r'[^\s\'"<>]{24,}')


def secret_spans(text):
    spans = [m.span() for m in SECRET.finditer(text)]
    for match in TOKEN.finditer(text):
        token = match.group()
        # URLs/paths and readable identifiers are not opaque credential tokens.
        if '://' in token or token.startswith(('/', '~/')):
            continue
        classes = sum((bool(re.search(r'[a-z]', token)), bool(re.search(r'[A-Z]', token)),
                       bool(re.search(r'\d', token)), bool(re.search(r'[^A-Za-z0-9]', token))))
        if classes >= 3 or (len(token) >= 32 and classes >= 2):
            spans.append(match.span())
    return spans


def masked(text):
    spans = []
    for start, end in sorted(secret_spans(text)):
        if spans and start <= spans[-1][1]:
            spans[-1] = (spans[-1][0], max(end, spans[-1][1]))
        else:
            spans.append((start, end))
    for start, end in reversed(spans):
        text = text[:start] + '••••••••' + text[end:]
    return text, bool(spans)


def result(identifier, title, sub, icon, kind, action, score):
    return dict(id=identifier, title=title, sub=sub, icon=icon, kind=kind, action=action, score=score)
