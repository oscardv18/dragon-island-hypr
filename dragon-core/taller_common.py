"""Stable JSON CLI errors and redaction shared by the engineering tools."""
import argparse
import json
from pathlib import Path
from secret_filter import redact


class ToolError(Exception):
    def __init__(self, code, message, hint='Revisa los argumentos y vuelve a intentarlo.'):
        self.code, self.message, self.hint = code, message, hint
        super().__init__(message)


class Parser(argparse.ArgumentParser):
    def error(self, message):
        emit(error('invalid_usage', 'Argumentos no válidos: ' + message, 'Consulta --help.'))
        raise SystemExit(2)


def safe(value):
    if isinstance(value, str):
        return redact(value)[0]
    if isinstance(value, dict):
        return {k: safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [safe(v) for v in value]
    return value


def error(code, message, hint='Revisa los argumentos y vuelve a intentarlo.'):
    return dict(ok=False, error=dict(code=code, message=message, hint=hint))


def emit(value):
    print(json.dumps(safe(value), ensure_ascii=False, allow_nan=False, separators=(',', ':')), flush=True)

def git_branch(path):
    if not path:return ''
    try:
        p=Path(path)
        for folder in (p,*p.parents):
            git=folder/'.git'
            if git.is_file():
                value=git.read_text().strip()
                if not value.startswith('gitdir: '):return ''
                git=folder/value[8:]
            if git.is_dir():
                head=(git/'HEAD').read_text().strip()
                return head.removeprefix('ref: refs/heads/') if head.startswith('ref: refs/heads/') else head[:8]
    except OSError:pass
    return ''
