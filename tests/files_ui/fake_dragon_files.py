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
