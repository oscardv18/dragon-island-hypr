"""Compositor determinista. Tokens estimados con ceil(bytes UTF-8 / 3.8), ±20 %.

Templates contain a list of {id,type,label,arg,enabled} blocks. No repository
file contents are read by paths blocks. Only send delivers text, explicitly.
"""
from contextlib import closing
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time

import dragon_mem as mem
from secret_filter import redact
from taller_common import Parser, ToolError, emit, error

LABELS = dict(card='Tarjeta', criteria='Criterios', paths='Rutas', diff='Cambios',
              log='Registro', note='Notas', decisions='Decisiones', commands='Comandos',
              comments='Comentarios de revisión', selection='Selección', text='Instrucciones')
MAX_INPUT = 1024 * 1024


def tokens(text):
    return math.ceil(len(text.encode('utf-8')) / 3.8)


def stdin_text():
    raw = sys.stdin.buffer.read(MAX_INPUT + 1)
    if len(raw) > MAX_INPUT:
        raise ToolError('input_too_large', 'El texto supera 1 MiB.')
    return raw.decode('utf-8', 'replace')


def tool(name, args, text=None):
    local = Path(__file__).resolve().parents[1] / 'bin' / name
    executable = shutil.which(name) or (str(local) if local.is_file() else None)
    if not executable:
        executable = str(Path.home() / '.local/bin' / name)
    result = subprocess.run([executable, *args], input=text, text=True, capture_output=True, timeout=15)
    if result.returncode:
        raise ToolError('delivery_failed' if text is not None else 'source_failed',
                        'La herramienta no pudo completar la operación.', 'Comprueba '+name+'.')
    return result.stdout


def template_dir():
    local = Path(__file__).resolve().parents[1] / 'config/dragon-prompt/templates'
    return local if local.is_dir() else Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config'))) / 'dragon-prompt/templates'


def templates(db, pid=None):
    result = []
    for path in sorted(template_dir().glob('*.json')):
        data = json.loads(path.read_text())
        result.append(dict(id=path.stem, name=data.get('name', path.stem), blocks=data['blocks'], source='builtin'))
    for row in mem.rows(db, 'SELECT * FROM prompt_template WHERE project_id IS NULL OR project_id=? ORDER BY project_id IS NOT NULL,id', (pid,)):
        result.append(dict(id=str(row['id']), name=row['name'], blocks=json.loads(row['blocks']), source='user'))
    return result


def validate_blocks(blocks):
    if not isinstance(blocks, list):
        raise ToolError('invalid_template', 'La plantilla debe contener una lista de bloques.')
    ids = set()
    result = []
    for n, raw in enumerate(blocks):
        if isinstance(raw, str):
            kind, _, arg = raw.partition(':'); raw = dict(type=kind, arg=arg)
        if not isinstance(raw, dict) or raw.get('type') not in LABELS:
            raise ToolError('invalid_template', 'La plantilla contiene un tipo de bloque desconocido.')
        b = dict(raw)
        b.setdefault('id', b['type']+'-'+str(n+1)); b.setdefault('label', LABELS[b['type']]); b.setdefault('arg', '')
        if not all(isinstance(b[k], str) for k in ('id', 'type', 'label', 'arg')) or b['id'] in ids:
            raise ToolError('invalid_template', 'Los bloques necesitan identificadores únicos y campos de texto.')
        ids.add(b['id']); result.append(b)
    return result


def cut_lines(text, maximum, start=0):
    lines = text.splitlines()
    selected = lines[start:start+maximum]
    truncated = len(lines) > len(selected)
    if truncated:
        selected.append('… recortadas '+str(len(lines)-len(selected))+' líneas')
    return '\n'.join(selected), truncated


def content(db, p, c, b, selection):
    kind, arg = b['type'], b['arg']
    if kind == 'text': return arg, False
    if kind == 'selection':
        return (tool('wl-paste', ['--no-newline']) if arg == 'clipboard' else selection), False
    if kind == 'paths': return '\n'.join(arg.splitlines() or []), False
    if kind == 'commands':
        return '\n'.join(f'{key}: {p[key]}' for key in ('test_cmd', 'build_cmd') if p[key]), False
    if kind in ('note', 'decisions'):
        try: count = int(arg or 10)
        except ValueError: raise ToolError('invalid_block', 'El número de notas no es válido.') from None
        if not 0 <= count <= 100: raise ToolError('invalid_block', 'Usa entre 0 y 100 notas.')
        note_kind = 'decision' if kind == 'decisions' else 'note'
        notes = mem.rows(db, 'SELECT title,body FROM note WHERE (project_id=? OR project_id IS NULL) AND kind=? ORDER BY created_at DESC,id DESC LIMIT ?', (p['id'], note_kind, count))
        return '\n'.join('- '+n['title']+': '+n['body'] for n in notes), False
    if kind in ('card', 'criteria', 'comments'):
        if not c: return '', False
        if kind == 'card': return c['key']+' · '+c['title']+'\n'+c['body'], False
        if kind == 'criteria':
            return '\n'.join('- ['+('x' if r['done'] else ' ')+'] '+r['text'] for r in mem.rows(db, 'SELECT * FROM criterion WHERE card_id=? ORDER BY pos,id', (c['id'],))), False
        return '\n'.join(f"{r['path']}:{r['line']}: {r['text']}" for r in mem.rows(db, 'SELECT * FROM review_comment WHERE card_id=? ORDER BY path,line,id', (c['id'],))), False
    if kind == 'diff':
        if not arg: return '', False
        data = json.loads(tool('dragon-git', ['diff', '--repo', c['worktree'] if c and c['worktree'] else p['path'], '--path', arg, '--json']))
        lines = []
        for h in data.get('hunks', []):
            lines.append(h['header'])
            lines.extend({'add': '+', 'del': '-', 'ctx': ' '}[r['t']]+r['text'] for r in h['lines'])
        text, truncated = cut_lines('\n'.join(lines), 120)
        if data.get('truncated'): text += '\n… fuente recortada a 2000 líneas'; truncated = True
        return text, truncated
    if kind == 'log':
        if not arg: return '', False
        output = tool('dragon-docker', ['logs', arg, '--tail', '200'])
        records = [json.loads(line) for line in output.splitlines() if line.strip()]
        records = [r for r in records if 'msg' in r]
        collapsed = []
        for r in records:
            if collapsed and collapsed[-1]['msg'] == r['msg']:
                collapsed[-1]['count'] += r.get('count', 1)
            else: collapsed.append(dict(r, count=r.get('count', 1)))
        first = next((i for i, r in enumerate(collapsed) if r.get('level') == 'error'), 0)
        start = max(0, min(first-10, len(collapsed)-40))
        lines = [r['msg']+(f" (×{r['count']})" if r['count'] > 1 else '') for r in collapsed]
        return cut_lines('\n'.join(lines), 40, start)
    raise ToolError('invalid_block', 'Tipo de bloque desconocido.')


def build(db, a):
    p = mem.project(db, a.project); c = mem.card(db, a.card, a.project) if a.card else None
    available = templates(db, p['id'])
    found = [t for t in available if str(t['id']) == a.template or t['name'] == a.template]
    if not found: raise ToolError('template_not_found', 'No se encontró la plantilla.', 'Consulta dragon-prompt templates.')
    blocks = validate_blocks(found[-1]['blocks'])
    for value in a.block:
        kind, _, arg = value.partition(':')
        blocks.append(dict(id='extra-'+str(len(blocks)+1), type=kind, label=LABELS.get(kind, kind), arg=arg))
    blocks = validate_blocks(blocks)
    off = set(','.join(a.off).split(',')); parts = []; metadata = []
    selection = stdin_text() if a.stdin else ''
    for b in blocks:
        enabled = b.get('enabled', True) is not False and b['id'] not in off
        # Disabled blocks never access external sources or the clipboard.
        raw, truncated = content(db, p, c, b, selection) if enabled else ('', False)
        clean, redactions = redact(raw); label, label_redactions = redact(b['label'])
        if b['type'] in ('diff', 'log'):
            redactions += sum(raw.count('[oculto:'+kind+']') for kind in ('pem', 'variable', 'bearer', 'url', 'token'))
        text = '## '+label+'\n'+clean if clean else ''
        if enabled and text: parts.append(text)
        metadata.append(dict(id=b['id'], type=b['type'], label=label, tokens=tokens(text),
                             enabled=enabled, truncated=truncated, redactions=redactions+label_redactions))
    text = '\n\n'.join(parts)
    return dict(text=text, tokens=tokens(text), blocks=metadata, warnings=[],
                estimate='ceil(bytes_utf8 / 3.8), ±20 %')


def history_enabled():
    path = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config'))) / 'dragon-island/settings.json'
    try: return json.loads(path.read_text()).get('promptHistory') is True
    except (OSError, ValueError, AttributeError): return False


def send(db, a):
    text, redactions = redact(stdin_text())
    p = mem.project(db, a.project) if a.project else None
    c = mem.card(db, a.card, a.project) if a.card else None
    if c and not p: p = dict(db.execute('SELECT * FROM project WHERE id=?', (c['project_id'],)).fetchone())
    if a.target.startswith('herdr:') and a.target[6:]:
        tool('dragon-herdr', ['prompt', a.target[6:], '--stdin']+(['--no-enter'] if a.no_enter else []), text)
    elif a.target == 'clipboard': tool('wl-copy', [], text)
    elif a.target.startswith('file:') and a.target[5:]:
        dest = Path(a.target[5:]).expanduser()
        fd, temp = tempfile.mkstemp(prefix='.prompt-', dir=dest.parent)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as handle: handle.write(text)
            os.replace(temp, dest)
        finally:
            if os.path.exists(temp): os.unlink(temp)
    else: raise ToolError('invalid_target', 'Destino no válido.', 'Usa herdr:<id>, clipboard o file:<ruta>.')
    digest = hashlib.sha256(text.encode()).hexdigest()
    with db:
        db.execute('INSERT INTO prompt_run(project_id,card_id,template,target,tokens_est,sent_at,body_hash,body) VALUES(?,?,?,?,?,?,?,?)',
                   (p['id'] if p else None, c['id'] if c else None, redact(a.template)[0] if a.template else None, redact(a.target)[0], tokens(text), int(time.time()), digest, text if history_enabled() else None))
    return dict(tokens=tokens(text), body_hash=digest, redactions=redactions)


def parser():
    root = Parser(description=__doc__); sub = root.add_subparsers(dest='command', required=True)
    p = sub.add_parser('templates'); p.add_argument('--project')
    p = sub.add_parser('build'); p.add_argument('--template', required=True); p.add_argument('--project', required=True)
    p.add_argument('--card'); p.add_argument('--block', action='append', default=[]); p.add_argument('--off', action='append', default=[]); p.add_argument('--stdin', action='store_true')
    p = sub.add_parser('send'); p.add_argument('--target', required=True); p.add_argument('--stdin', action='store_true', required=True)
    p.add_argument('--no-enter', action='store_true'); p.add_argument('--project'); p.add_argument('--card'); p.add_argument('--template')
    return root


def main():
    os.umask(0o077)
    a = parser().parse_args([v for v in sys.argv[1:] if v != '--json'])
    try:
        with closing(mem.connect()) as db:
            if a.command == 'templates': result = dict(templates=templates(db, mem.project(db, a.project)['id'] if a.project else None))
            elif a.command == 'build': result = build(db, a)
            else: result = send(db, a)
        emit(dict(ok=True, **result)); return 0
    except ToolError as e: emit(error(e.code, e.message, e.hint)); return 1
    except (OSError, ValueError, TypeError, KeyError, sqlite3.Error, subprocess.SubprocessError):
        emit(error('prompt_failed', 'No se pudo componer o entregar el prompt.', 'Comprueba la plantilla, las herramientas y el destino.')); return 1


if __name__ == '__main__': raise SystemExit(main())
