"""Run only the user-defined project.test_cmd, as bounded JSONL progress.

1 MiB output, 16 KiB per line, default 600 s. SIGTERM/timeout/output overflow
terminate the entire process group; no output is persisted in the card event.
"""
from collections import deque
from contextlib import closing
import os
from pathlib import Path
import re
import selectors
import signal
import sqlite3
import subprocess
import sys
import time

import dragon_mem as mem
from secret_filter import redact
from taller_common import Parser, ToolError, emit, error

OUTPUT_LIMIT = 1024 * 1024
LINE_LIMIT = 16 * 1024


def resolve_card(db, p, cwd, key):
    if key: return mem.card(db, key, p['slug'])
    candidates = mem.rows(db, "SELECT * FROM card WHERE project_id=? AND col IN ('doing','review') ORDER BY id", (p['id'],))
    exact = [c for c in candidates if c['worktree'] and Path(c['worktree']).resolve() == cwd]
    if not exact and cwd == Path(p['path']).resolve(): exact = [c for c in candidates if not c['worktree']]
    if len(exact) > 1:
        raise ToolError('ambiguous_card', 'Hay varias tarjetas activas en ese directorio.', 'Indica --card <clave>.')
    return exact[0] if exact else None


def kill_group(proc):
    try: os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError: return
    # Also kill surviving descendants when bash exited before its children.
    time.sleep(.15)
    try: os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError: pass


def run(a):
    if not 0 < a.timeout <= 86400:
        raise ToolError('invalid_timeout', 'El límite de tiempo debe estar entre 0 y 86400 segundos.')
    cwd = Path(a.cwd).expanduser().resolve()
    if not cwd.is_dir(): raise ToolError('invalid_path', 'El directorio de pruebas no existe.')
    with closing(mem.connect()) as db:
        p = mem.project(db, a.project)
        if not p['test_cmd'] or not p['test_cmd'].strip():
            raise ToolError('no_test_cmd', 'El proyecto no tiene comando de pruebas.', 'Define project set <slug> --test-cmd <comando>.')
        c = resolve_card(db, p, cwd, a.card)
    cancelled = False
    def stop(_signum, _frame):
        nonlocal cancelled
        cancelled = True
    old = {s: signal.signal(s, stop) for s in (signal.SIGTERM, signal.SIGINT)}
    tail = deque(maxlen=30); pending = b''; total = 0; pem = False; reason = None; proc = None
    started = time.monotonic()
    def line(raw):
        nonlocal pem
        text = raw.decode('utf-8', 'replace').rstrip('\r')
        text = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', text)
        begins = bool(re.search(r'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----', text))
        ends = bool(re.search(r'-----END (?:[A-Z0-9]+ )*PRIVATE KEY-----', text))
        hidden = pem or begins
        pem = hidden and not ends
        if hidden: text = '[oculto:pem]'
        elif len(raw) > LINE_LIMIT: text = '… línea recortada por superar 16 KiB'
        else: text = redact(text)[0]
        tail.append(text); emit(dict(ok=True, t='progress', line=text))
    try:
        proc = subprocess.Popen(['bash', '-lc', p['test_cmd']], cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True)
        with selectors.DefaultSelector() as selector:
            selector.register(proc.stdout, selectors.EVENT_READ)
            while selector.get_map():
                if cancelled: reason = 'cancelled'; break
                if time.monotonic()-started >= a.timeout: reason = 'timeout'; break
                for key, _ in selector.select(min(.1, max(0, a.timeout-(time.monotonic()-started)))):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        if pending: line(pending); pending = b''
                        continue
                    total += len(chunk)
                    if total > OUTPUT_LIMIT: reason = 'output_limit'; break
                    pending += chunk
                    while b'\n' in pending:
                        raw, pending = pending.split(b'\n', 1); line(raw)
                if reason: break
            # A command can close stdout and continue running: keep enforcing time/cancel.
            while not reason and proc.poll() is None:
                if cancelled: reason = 'cancelled'; break
                if time.monotonic()-started >= a.timeout: reason = 'timeout'; break
                time.sleep(.02)
    finally:
        if proc:
            kill_group(proc); proc.wait(); proc.stdout.close()
        for sig, handler in old.items(): signal.signal(sig, handler)
    result = dict(ok=not reason and proc.returncode == 0, t='done', exit=proc.returncode,
                  seconds=round(time.monotonic()-started, 3), tail=list(tail),
                  card=c['key'] if c else None, truncated=reason == 'output_limit')
    if not result['ok']:
        messages = dict(timeout='Las pruebas excedieron el tiempo límite.', output_limit='Las pruebas excedieron 1 MiB de salida.',
                        cancelled='Pruebas canceladas.', test_failed='El comando de pruebas terminó con error.')
        code = reason or 'test_failed'
        result['error'] = error(code, messages[code], 'Revisa el comando y la salida de las pruebas.')['error']
    if c:
        with closing(mem.connect()) as db, db:
            mem.event(db, c['id'], 'gate', {k: result[k] for k in ('ok', 'exit', 'seconds', 'truncated')})
    return result


def main():
    os.umask(0o077)
    root = Parser(description=__doc__); sub = root.add_subparsers(dest='command', required=True)
    p = sub.add_parser('run'); p.add_argument('--project', required=True); p.add_argument('--cwd', required=True)
    p.add_argument('--timeout', type=float, default=600); p.add_argument('--card')
    a = root.parse_args([v for v in sys.argv[1:] if v != '--json'])
    try:
        result = run(a); emit(result); return 0 if result['ok'] else 1
    except ToolError as e: emit(error(e.code, e.message, e.hint)); return 1
    except (OSError, ValueError, sqlite3.Error, subprocess.SubprocessError):
        emit(error('gate_failed', 'No se pudieron ejecutar o registrar las pruebas.')); return 1


if __name__ == '__main__': raise SystemExit(main())
