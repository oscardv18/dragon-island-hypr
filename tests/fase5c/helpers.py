"""Run real Quickshell services against fake 5c tools, real dragon-mem/dragon-git and an isolated HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FAKE = Path(__file__).resolve().parent / 'fake'
QMLDIR = '''ToolRequest 1.0 ToolRequest.qml
StdinRequest 1.0 StdinRequest.qml
singleton Mem 1.0 Mem.qml
singleton Herdr 1.0 Herdr.qml
singleton Activity 1.0 Activity.qml
singleton Prompts 1.0 Prompts.qml
singleton Gate 1.0 Gate.qml
singleton Review 1.0 Review.qml
singleton Tokens 1.0 Tokens.qml
'''
BAD = ('ReferenceError', 'TypeError', 'Error loading configuration', 'is not a function', 'SyntaxError', 'Unable to assign', 'Cannot assign', 'is not defined')


def run_shell(body, extra_qmldir='', fakes=('dragon-prompt', 'dragon-gate', 'dragon-tokens'), setup=None, timeout=40, env_extra=None):
    """body: QML ShellRoot source. Returns (output, home path contents dict). setup(home, env) prepares files first."""
    with tempfile.TemporaryDirectory(prefix='d5c-') as tmp:
        home = Path(tmp); runtime = home / 'runtime'; runtime.mkdir(mode=0o700)
        cfg = home / 'shell'; shutil.copytree(ROOT / 'config/quickshell', cfg)
        (cfg / 'services/qmldir').write_text(QMLDIR + extra_qmldir)
        bindir = home / '.local/bin'; bindir.mkdir(parents=True)
        for name in ('dragon-mem', 'dragon-git'): (bindir / name).symlink_to(ROOT / 'bin' / name)
        for name in fakes: (bindir / name).symlink_to(FAKE / name)
        env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen',
                   HERDR_SOCKET_PATH=str(home / 'none.sock'), PYTHONDONTWRITEBYTECODE='1',
                   GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.org',
                   GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.org', GIT_CONFIG_GLOBAL='/dev/null')
        for key in ('CONFIG', 'DATA', 'STATE', 'CACHE'): env[f'XDG_{key}_HOME'] = str(home / key.lower())
        env.update(env_extra or {})
        if setup: setup(home, env)
        (cfg / 'shell.qml').write_text(body)
        p = subprocess.run([shutil.which('qs'), '-p', str(cfg)], env=env, capture_output=True, text=True, timeout=timeout)
        sent = (home / 'prompt-sent.jsonl').read_text() if (home / 'prompt-sent.jsonl').exists() else ''
        herdr = (home / 'herdr-calls.jsonl').read_text() if (home / 'herdr-calls.jsonl').exists() else ''
        import json
        return p.stdout + p.stderr, {'sent': sent, 'herdr': [json.loads(l) for l in herdr.splitlines()], 'home': tmp}


def git_repo(home, env, name='repo'):
    repo = home / name; repo.mkdir()
    subprocess.run(['git', 'init', '-q', '-b', 'main', str(repo)], env=env, check=True)
    (repo / 'README.md').write_text('base\n')
    subprocess.run(['git', '-C', str(repo), 'add', '.'], env=env, check=True)
    subprocess.run(['git', '-C', str(repo), 'commit', '-qm', 'base'], env=env, check=True)
    (repo / 'nuevo.txt').write_text('cambio del agente\n')
    return repo
