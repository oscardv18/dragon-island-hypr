"""wl-paste watcher. Only cliphist owns the content; our file stores hashes.

Store first, annotate second. Failed/timed-out MIME/class/metadata helpers cannot
consume the copy. No resident process; all child commands have bounded waits.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from engine_common import atomic_json, read_json, state_path

HINT = 'x-kde-passwordManagerHint'


def helper(argv, timeout=.25):
    try:
        process = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout)
        return process.stdout if process.returncode == 0 else b''
    except (OSError, subprocess.TimeoutExpired):
        return b''


def is_secret():
    if os.environ.get('CLIPBOARD_STATE') == 'sensitive':
        return True
    types = helper(['wl-paste', '--list-types']).decode('utf-8', errors='replace').splitlines()
    if HINT not in types:
        return False
    value = helper(['wl-paste', '--type', HINT, '--no-newline']).strip().lower()
    # An advertised password hint that cannot be read must not expose a password.
    return not value or value == b'secret'


def annotate(data, now):
    metadata = {'time': now}
    try:
        window = json.loads(helper(['hyprctl', 'activewindow', '-j']))
        if isinstance(window.get('class'), str) and window['class']:
            metadata['app'] = window['class'][:256]
    except (ValueError, TypeError, AttributeError):
        pass
    path = state_path('clip-meta.json')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(str(path) + '.lock', os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(fd, 'a') as handle:
        # Concurrent clipboard bursts may skip optional metadata, never wait for a lock.
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        state = read_json(path, {'version': 1, 'items': {}})
        entries = state['items']
        entries[hashlib.sha256(data).hexdigest()] = metadata
        state['items'] = dict(sorted(entries.items(), key=lambda pair: (-pair[1]['time'], pair[0]))[:5000])
        atomic_json(path, state)


def main():
    flag = Path(os.environ.get('XDG_RUNTIME_DIR') or '/tmp') / 'dragon-island/clipboard-paused'
    if flag.exists() or is_secret():
        while sys.stdin.buffer.read(65536):
            pass
        return 0
    data = sys.stdin.buffer.read()
    try:
        process = subprocess.run(['cliphist', 'store'], input=data, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, timeout=2)
        if process.returncode:
            print('dragon-clip-store: cliphist store failed', file=sys.stderr)
            return process.returncode if process.returncode > 0 else 1
    except (OSError, subprocess.TimeoutExpired):
        print('dragon-clip-store: cliphist store unavailable or timed out', file=sys.stderr)
        return 1
    try:
        annotate(data, int(time.time()))
    except (OSError, ValueError, KeyError, TypeError):
        # Metadata is optional. The normal copy has already reached cliphist.
        pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
