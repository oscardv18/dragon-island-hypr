"""Bounded Git adapter. Index-only credential checks; never changes git config.

watch uses inotifywait with a 300 ms debounce, otherwise a two-second poll.
Every emitted file includes a content hash, so edits with unchanged status are
visible. Git receives argv arrays, literal pathspecs and no force flags.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import select
import shutil
import signal
import subprocess
import sys
import time
from secret_filter import detections, redact
from taller_common import Parser, ToolError, emit, error


def run(repo, *args, timeout=5, check=True):
    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GIT_OPTIONAL_LOCKS='0', GIT_LITERAL_PATHSPECS='1', LC_ALL='C')
    try:
        p = subprocess.Popen(['git', '-C', str(repo), *args], stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, env=env, start_new_session=True)
    except FileNotFoundError:
        raise ToolError('git_missing', 'Git no está instalado.', 'Instala git.') from None
    try:
        out, err = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        raise ToolError('git_timeout', 'Git ha superado el tiempo máximo.', 'Comprueba el repositorio y la conexión.') from None
    finally:
        if p.poll() is None:
            os.killpg(p.pid, signal.SIGKILL); p.communicate()
    if check and p.returncode:
        raise ToolError('git_failed', err.decode(errors='replace').strip() or 'La operación Git falló.',
                        'Revisa el estado del repositorio; los conflictos se resuelven manualmente.')
    return out


def text(repo, *args, **kwargs):
    return run(repo, *args, **kwargs).decode('utf-8', errors='replace')


def path_arg(repo, value):
    # Do not resolve symlinks: Git paths refer to directory entries, not their targets.
    root = Path(repo).absolute()
    value = os.path.abspath(root / value)
    try:
        result = str(Path(value).relative_to(root))
    except ValueError:
        raise ToolError('invalid_path', 'La ruta está fuera del repositorio.') from None
    if result == '.':
        raise ToolError('invalid_path', 'Selecciona archivos concretos.')
    return result


def numstat(repo, staged=False):
    args = ['diff', '--numstat', '-z', '--no-ext-diff', '--no-textconv']
    if staged: args.append('--cached')
    chunks = run(repo, *args, '--').split(b'\0')
    result, i = {}, 0
    while i < len(chunks):
        item = chunks[i]; i += 1
        if not item: continue
        add, delete, name = item.split(b'\t', 2)
        if not name:
            i += 1  # old rename path
            name = chunks[i]; i += 1
        result[os.fsdecode(name)] = dict(add=int(add) if add != b'-' else 0,
                                        **{'del': int(delete) if delete != b'-' else 0})
    return result


def status(repo):
    parts = run(repo, 'status', '--porcelain=v2', '-z', '--branch', '--untracked-files=all').split(b'\0')
    result = dict(branch='', upstream='', ahead=0, behind=0, staged=[], changes=[], untracked=[], conflicts=[])
    staged, changes = numstat(repo, True), numstat(repo)
    i = 0
    while i < len(parts):
        record = os.fsdecode(parts[i]); i += 1
        if record.startswith('# branch.head '): result['branch'] = record[14:]
        elif record.startswith('# branch.upstream '): result['upstream'] = record[18:]
        elif record.startswith('# branch.ab '):
            a, b = record[12:].split(); result['ahead'], result['behind'] = int(a), abs(int(b))
        elif record.startswith('? '): result['untracked'].append(dict(path=record[2:], status='?', add=0, **{'del': 0}))
        elif record.startswith(('1 ', '2 ', 'u ')):
            fields = record.split(' ', 10 if record[0] == 'u' else 9 if record[0] == '2' else 8)
            xy, path = fields[1], fields[-1]
            old = None
            if record[0] == '2': old = os.fsdecode(parts[i]); i += 1
            if record[0] == 'u':
                result['conflicts'].append(path)
                result['changes'].append(dict(path=path, status='U', add=0, **{'del': 0})); continue
            for slot, code, counts in (('staged', xy[0], staged), ('changes', xy[1], changes)):
                if code != '.':
                    result[slot].append(dict(path=path, status=code, old_path=old, **counts.get(path, dict(add=0, **{'del': 0}))))
    return result


def blob_hash(repo, path):
    p = Path(repo)/path_arg(repo, path)
    if p.is_symlink(): data = os.fsencode(os.readlink(p))
    elif p.is_file(): data = p.read_bytes()
    else: return None
    return hashlib.sha1(b'blob ' + str(len(data)).encode()+b'\0'+data).hexdigest()


def diff(repo, path, staged=False):
    path = path_arg(repo, path)
    args = ['diff', '--no-ext-diff', '--no-textconv', '--no-color', '--unified=3']
    if staged: args.append('--cached')
    raw = text(repo, *args, '--', path)
    # Untracked files have no git diff; present an addition without staging them.
    if not raw and not staged and any(r['path'] == path for r in status(repo)['untracked']):
        data = (Path(repo)/path).read_bytes()
        raw = 'Binary files differ' if b'\0' in data else '@@ -0,0 +1,' + str(len(data.splitlines())) + ' @@\n' + ''.join('+'+s+'\n' for s in data.decode(errors='replace').splitlines())
    hunks, current, old, new, count = [], None, 0, 0, 0
    added = deleted = 0
    truncated = False
    pem = False
    for line in raw.splitlines():
        if line.startswith('@@'):
            match = re.match(r'@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@', line)
            if not match: continue
            old, new = int(match[1]), int(match[2])
            current = dict(header=line, lines=[]); hunks.append(current)
        elif current is not None and line[:1] in (' ', '+', '-'):
            kind = {' ': 'ctx', '+': 'add', '-': 'del'}[line[0]]
            content = line[1:]
            if re.search(r'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----', content): pem = True
            clean = '[oculto:pem]' if pem else redact(content)[0]
            if re.search(r'-----END (?:[A-Z0-9]+ )*PRIVATE KEY-----', content): pem = False
            added += kind == 'add'; deleted += kind == 'del'
            if count < 2000:
                current['lines'].append(dict(o=old if kind != 'add' else None,
                    n=new if kind != 'del' else None, t=kind, text=clean))
            else: truncated = True
            count += 1; old += kind != 'add'; new += kind != 'del'
    return dict(path=path, add=added, **{'del': deleted}, binary='Binary files ' in raw or 'GIT binary patch' in raw,
                truncated=truncated, hunks=[h for h in hunks if h['lines']])


def check_secrets(repo):
    # Inspect actual staged blobs (not working copies, and not deleted lines).
    result = []
    names = run(repo, 'diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z', '--').split(b'\0')
    for name in names:
        if not name: continue
        path = os.fsdecode(name)
        if Path(path).name == '.env' or Path(path).name.startswith('.env.'):
            result.append(dict(path=path, line=1, type='env_file')); continue
        raw = run(repo, 'show', ':'+path)
        if b'\0' in raw: continue
        content = raw.decode(errors='replace')
        for start, _, kind in detections(content, opaque=False):
            result.append(dict(path=path, line=content.count('\n', 0, start)+1, type=kind))
    return result


def branch_arg(value):
    if value.startswith('-') or not value:
        raise ToolError('invalid_branch', 'Nombre de rama no válido.')
    return value


def log(repo, n):
    if not run(repo, 'rev-parse', '--verify', 'HEAD', check=False): return []
    raw = text(repo, 'log', f'-{min(1000, max(1,n))}', '--format=%H%x00%s%x00%an%x00%at%x00%D%x00%P%x00')
    fields, rows = raw.split('\0'), []
    for i in range(0, len(fields)-1, 6):
        rows.append(dict(hash=fields[i].strip(), subject=fields[i+1], author=fields[i+2], ts=int(fields[i+3]),
                         refs=fields[i+4], parents=fields[i+5].split()))
    return rows


def worktrees(repo):
    records = run(repo, 'worktree', 'list', '--porcelain', '-z').split(b'\0\0')
    rows = []
    for record in records:
        item = {}
        for field in record.split(b'\0'):
            k, _, v = os.fsdecode(field).partition(' ')
            if k: item[k] = v if v else True
        if item: rows.append(item)
    return rows


def watch(repo):
    proc = None
    previous = None
    try:
        if shutil.which('inotifywait'):
            gitdir = text(repo, 'rev-parse', '--absolute-git-dir').strip()
            proc = subprocess.Popen(['inotifywait', '-m', '-q', '-r', '-e', 'close_write,create,delete,moved_to,moved_from',
                '--exclude', r'(/objects/|/index.lock$)', repo, gitdir], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                start_new_session=True)
        while True:
            data = status(repo)
            files = []
            for group in ('staged', 'changes', 'untracked'):
                for row in data[group]: files.append(dict(row, staged=group == 'staged', hash=blob_hash(repo, row['path'])))
            snapshot = dict(files=files, branch=data['branch'], upstream=data['upstream'], ahead=data['ahead'], behind=data['behind'])
            if snapshot != previous: emit(dict(ok=True, t='changed', **snapshot)); previous = snapshot
            if proc and proc.poll() is None:
                # Bound wait also covers watcher death and directories added after startup.
                ready, _, _ = select.select([proc.stdout], [], [], 2)
                if ready:
                    os.read(proc.stdout.fileno(), 65536)
                    while select.select([proc.stdout], [], [], .3)[0]:
                        if not os.read(proc.stdout.fileno(), 65536): break
            else: time.sleep(2)
    finally:
        if proc and proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM); proc.communicate(timeout=3)


def main():
    parser = Parser(description='Git local para el Taller (JSON).')
    sub = parser.add_subparsers(dest='cmd', required=True)
    def command(name, parent=sub):
        p = parent.add_parser(name); p.add_argument('--repo', required=True); p.add_argument('--json', action='store_true'); return p
    command('status')
    p = command('diff'); p.add_argument('--path', required=True); p.add_argument('--staged', action='store_true')
    for name in ('stage', 'unstage'):
        command(name).add_argument('--paths', nargs='+', required=True)
    p = command('commit'); p.add_argument('-m', required=True); p.add_argument('--push', action='store_true')
    p = command('pull'); p.add_argument('--ff-only', action='store_true')
    command('push')
    command('checkout').add_argument('branch')
    command('branches'); command('log').add_argument('-n', type=int, default=30)
    command('watch'); command('blob-hash').add_argument('--path', required=True)
    command('check-secrets')
    p = sub.add_parser('stash'); nested = p.add_subparsers(dest='operation', required=True)
    for name in ('push', 'pop', 'list'): command(name, nested)
    p = sub.add_parser('worktree'); nested = p.add_subparsers(dest='operation', required=True)
    p = command('add', nested); p.add_argument('--branch', required=True); p.add_argument('--path', required=True); p.add_argument('--from', dest='base')
    command('list', nested)
    command('remove', nested).add_argument('--path', required=True)
    args = parser.parse_args(); repo = text(args.repo, 'rev-parse', '--show-toplevel').strip()
    result = {}
    if args.cmd == 'status': result = status(repo)
    elif args.cmd == 'diff': result = diff(repo, args.path, args.staged)
    elif args.cmd == 'check-secrets': result = dict(secrets=check_secrets(repo))
    elif args.cmd == 'blob-hash': result = dict(hash=blob_hash(repo, args.path))
    elif args.cmd in ('stage', 'unstage'):
        paths = [path_arg(repo, path) for path in args.paths]
        if args.cmd == 'stage': run(repo, 'add', '--', *paths)
        elif run(repo, 'rev-parse', '--verify', 'HEAD', check=False): run(repo, 'restore', '--staged', '--', *paths)
        else: run(repo, 'rm', '--cached', '--', *paths)
    elif args.cmd == 'commit':
        secrets = check_secrets(repo)
        if secrets:
            emit(dict(ok=False, error=dict(code='secrets_found', message='Hay secretos en lo preparado. Retíralos antes de commitear.',
                hint='Revisa los archivos indicados.', files=secrets))); return 1
        warnings = [] if re.match(r'^[a-z]+\([^)]+\): .+', args.m) else ['Formato recomendado: tipo(ámbito): texto']
        result = dict(output=text(repo, 'commit', '-m', args.m), warnings=warnings)
        if args.push:
            try: result['push'] = text(repo, 'push', timeout=120)
            except ToolError as exc:
                emit(dict(ok=False, committed=True, warnings=warnings, error=dict(code=exc.code, message=exc.message, hint='El commit ya existe. Reintenta solo Push.'))); return 1
    elif args.cmd == 'pull': result = dict(output=text(repo, 'pull', '--ff-only', timeout=120))
    elif args.cmd == 'push': result = dict(output=text(repo, 'push', timeout=120))
    elif args.cmd == 'checkout': result = dict(output=text(repo, 'checkout', branch_arg(args.branch), '--'))
    elif args.cmd == 'stash': result = dict(output=text(repo, 'stash', args.operation))
    elif args.cmd == 'branches':
        result = dict(branches=[dict(name=r[0], current=r[1]=='*', upstream=r[2]) for row in text(repo, 'for-each-ref', '--format=%(refname:short)%00%(HEAD)%00%(upstream:short)', 'refs/heads/').splitlines() if len(r := row.split('\0')) == 3])
    elif args.cmd == 'log': result = dict(log=log(repo, args.n))
    elif args.cmd == 'worktree':
        if args.operation == 'list': result = dict(worktrees=worktrees(repo))
        elif args.operation == 'add':
            argv = ['worktree', 'add', '-b', branch_arg(args.branch), '--', args.path]
            if args.base: argv.append(branch_arg(args.base))
            result = dict(output=text(repo, *argv))
        else:
            target = str(Path(args.path).absolute())
            if not any(str(Path(row['worktree']).absolute()) == target for row in worktrees(repo)):
                raise ToolError('unknown_worktree', 'El directorio no es un worktree registrado.')
            if run(target, 'status', '--porcelain', '--untracked-files=all').strip():
                raise ToolError('dirty_worktree', 'El worktree tiene cambios sin guardar.')
            result = dict(output=text(repo, 'worktree', 'remove', '--', target))
    elif args.cmd == 'watch': watch(repo); return 0
    emit(dict(ok=True, **result)); return 0


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try: sys.exit(main() or 0)
    except ToolError as exc: emit(error(exc.code, exc.message, exc.hint)); sys.exit(1)
    except (KeyboardInterrupt, BrokenPipeError): sys.exit(0)
    except OSError: emit(error('git_io', 'No se puede leer el archivo o repositorio.')); sys.exit(1)
