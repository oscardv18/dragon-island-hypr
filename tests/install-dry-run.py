#!/usr/bin/env python3
"""Verify install.sh --dry-run using a private HOME and every writable XDG root.

Compare the entire sandbox (contents, links, modes and mtime), without an activity
or log allowlist. Also retain the original repository status check.
"""
import argparse
import os
from pathlib import Path
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def snapshot(root):
    result = {}
    for path in sorted(root.rglob('*')):
        meta = path.lstat()
        content = os.readlink(path) if path.is_symlink() else path.read_bytes() if stat.S_ISREG(meta.st_mode) else None
        result[str(path.relative_to(root))] = (meta.st_mode, meta.st_mtime_ns, content)
    return result


def check(installer=None):
    installer = Path(installer or ROOT/'install.sh').resolve()
    before_git = subprocess.check_output(['git', 'status', '--porcelain', '-z'], cwd=ROOT)
    errors = []
    with tempfile.TemporaryDirectory(prefix='dragon-install-dry-') as folder:
        sandbox = Path(folder)
        home = sandbox/'home'; home.mkdir()
        env = dict(os.environ, HOME=str(home), PYTHONDONTWRITEBYTECODE='1')
        for kind in ('CONFIG', 'STATE', 'DATA', 'CACHE', 'RUNTIME'):
            path = sandbox/kind.lower(); path.mkdir(mode=0o700)
            env['XDG_'+kind+('_DIR' if kind == 'RUNTIME' else '_HOME')] = str(path)
        (home/'.zshrc').write_text('# configuración propia\n')
        state = sandbox/'state/dragon-island'; state.mkdir()
        (state/'activity.jsonl').write_text('{"fixture":true}\n')
        (state/'components').write_text('core\nshell\ntheme\n')
        before = snapshot(sandbox)
        result = subprocess.run([str(installer), '--dry-run', '--yes', '--modules',
                                 'core,shell,theme,plugins,keyboard,extras,keyring,login',
                                 '--extras', 'brave,protonvpn,herdr'], cwd=ROOT, env=env,
                                capture_output=True, text=True, timeout=120)
        if result.returncode:
            errors.append('El instalador en simulación falló (salida '+str(result.returncode)+').\n'+result.stdout+result.stderr)
        after = snapshot(sandbox)
        changed = sorted(key for key in before.keys() | after.keys() if before.get(key) != after.get(key))
        if changed: errors.append('El dry-run cambió el HOME/XDG temporal: '+', '.join(changed))
    if before_git != subprocess.check_output(['git', 'status', '--porcelain', '-z'], cwd=ROOT):
        errors.append('El dry-run cambió el estado del repositorio.')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--installer', type=Path, default=ROOT/'install.sh')
    args = parser.parse_args()
    try:
        errors = check(args.installer)
    except (OSError, subprocess.SubprocessError) as exc:
        errors = ['No se pudo comprobar el dry-run: '+str(exc)]
    if errors:
        for message in errors: print('✘ '+message)
        return 1
    print('✔ dry-run completo: HOME/XDG temporales intactos y git status idéntico')
    return 0


if __name__ == '__main__': raise SystemExit(main())
