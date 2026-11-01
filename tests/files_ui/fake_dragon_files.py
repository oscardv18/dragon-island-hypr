#!/usr/bin/env python3
"""Stand-in for dragon-files in the UI tests: answers from tests/qml/fixtures following PLAN-FASE-5 §5.7.
Every call is appended to $FAKE_FILES_LOG (one JSON array per line) so tests can check what the services asked for."""
import json, os, sys, time
from pathlib import Path
FIX = Path(os.environ['FAKE_FILES_FIXTURES'])
args = sys.argv[1:]
with open(os.environ['FAKE_FILES_LOG'], 'a') as log:
    log.write(json.dumps(args) + '\n')
def out(obj):
    print(json.dumps(obj, ensure_ascii=False), flush=True)
def fixture(name):
    return json.loads((FIX / name).read_text())
cmd = args[0] if args else ''
if cmd == 'ls':
    path = args[1]
    name = {'docs': 'files-ls-docs.json', 'Descargas': 'files-ls-descargas.json'}.get(os.path.basename(path))
    if not name:
        out({'ok': False, 'error': {'code': 'not_found', 'message': f'No existe «{path}»', 'hint': ''}}); sys.exit(1)
    r = fixture(name); r['path'] = path
    if '--git' not in args:
        for e in r['entries']: e['git'] = None
    out(r)
elif cmd == 'places':
    out(fixture('files-places.json'))
elif cmd == 'watch':
    # one change after a moment, then stay alive until SIGTERM
    time.sleep(0.3); out({'t': 'changed', 'path': args[1]})
    while True: time.sleep(1)
elif cmd == 'devices' and '--watch' in args:
    time.sleep(0.3); out({'t': 'changed', 'id': 'sda1'})
    while True: time.sleep(1)
elif cmd == 'devices':
    out(fixture('files-devices.json'))
elif cmd in ('mount', 'unmount', 'eject'):
    out({'ok': True, 'mountpoint': '/run/media/test/' + args[1]} if cmd == 'mount' else {'ok': True})
elif cmd == 'unlock':
    secret = sys.stdin.readline().rstrip('\n')
    with open(os.environ['FAKE_FILES_LOG'], 'a') as log:
        log.write(json.dumps(['stdin', len(secret)]) + '\n')
    if secret == 'correcta': out({'ok': True, 'mountpoint': '/run/media/test/cifrado'})
    else: out({'ok': False, 'error': {'code': 'bad_passphrase', 'message': 'Contraseña incorrecta', 'hint': ''}}); sys.exit(1)
elif cmd == 'archive' and args[1] == 'list':
    out(fixture('files-archive-backup.json'))
elif cmd == 'archive' and args[1] == 'extract':
    if '--password-stdin' in args:
        secret = sys.stdin.readline().rstrip('\n')
        with open(os.environ['FAKE_FILES_LOG'], 'a') as log:
            log.write(json.dumps(['stdin', len(secret)]) + '\n')
        if secret != 'clave':
            out({'t': 'error', 'error': {'code': 'bad_password', 'message': 'Contraseña incorrecta'}}); sys.exit(1)
    elif os.path.basename(args[2]).endswith('.7z'):
        out({'t': 'error', 'error': {'code': 'password_required', 'message': 'El archivo está cifrado'}}); sys.exit(1)
    out({'t': 'progress', 'pct': 50, 'file': 'src/a.ts', 'bps': 10}); out({'t': 'done'})
elif cmd == 'archive' and args[1] in ('create', 'test'):
    out({'t': 'done'} if args[1] == 'create' else {'ok': True})
elif cmd == 'net':
    sub = args[1]
    if sub == 'discover': out(fixture('files-net-discover.json'))
    elif sub == 'mounts': out(fixture('files-net-mounts.json'))
    elif sub == 'saved': out(fixture('files-net-saved.json'))
    elif sub == 'shares': out(fixture('files-net-shares-' + args[2] + '.json'))
    elif sub == 'connect':
        if '--password-stdin' not in args:
            out({'ok': False, 'error': {'code': 'auth_required', 'message': 'El servidor pide usuario y contraseña'}}); sys.exit(1)
        secret = sys.stdin.readline().rstrip('\n')
        with open(os.environ['FAKE_FILES_LOG'], 'a') as log:
            log.write(json.dumps(['stdin', len(secret)]) + '\n')
        out({'ok': True, 'mountpoint': '/run/user/1000/gvfs/sftp:host=x'})
    else: out({'ok': True})
elif cmd == 'thumb':
    out({'ok': True, 'thumb': None})
elif cmd in ('open', 'terminal-here'):
    out({'ok': True})
elif cmd == 'op':
    kind = args[1]
    srcs = [a for a in args[2:] if not a.startswith('--')]
    if '--dest' in args:
        dest = args[args.index('--dest') + 1]; srcs = [a for a in srcs if a != dest and a not in ('ask',)]
    if os.environ.get('FAKE_SLOW') and kind == 'copy':
        out({'t': 'progress', 'pct': 5, 'file': 'big.iso', 'bps': 1, 'index': 1, 'count': 1})
        time.sleep(30)
    if kind in ('copy', 'move') and os.environ.get('FAKE_CONFLICT'):
        out({'t': 'conflict', 'file': srcs[0], 'dest': dest + '/' + os.path.basename(srcs[0])})
        answer = sys.stdin.readline().strip()
        with open(os.environ['FAKE_FILES_LOG'], 'a') as log:
            log.write(json.dumps(['answer', json.loads(answer)]) + '\n')
    for i, pct in enumerate((10, 60, 100)):
        out({'t': 'progress', 'pct': pct, 'file': os.path.basename(srcs[0]) if srcs else '', 'bps': 1000, 'index': 1, 'count': len(srcs)}); time.sleep(0.05)
    moved = []
    if kind == 'move': moved = [{'from': s, 'to': dest + '/' + os.path.basename(s)} for s in srcs]
    if kind == 'rename': moved = [{'from': srcs[0], 'to': os.path.dirname(srcs[0]) + '/' + args[args.index('--name') + 1]}]
    if os.environ.get('FAKE_FAIL') == kind:
        out({'t': 'error', 'error': {'code': 'no_space', 'message': 'No queda espacio en el destino', 'hint': 'Libera espacio'}}); sys.exit(1)
    out({'t': 'done', 'moved': moved})
else:
    key = 'files-' + '-'.join(a for a in args if not a.startswith('-'))[:40] + '.json'
    if (FIX / key).exists(): out(fixture(key))
    else: out({'ok': False, 'error': {'code': 'unsupported', 'message': 'no simulado: ' + ' '.join(args)}}); sys.exit(1)
