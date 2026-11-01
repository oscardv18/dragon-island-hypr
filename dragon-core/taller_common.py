"""Stable JSON CLI errors and redaction shared by the engineering tools."""
import argparse
import json
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
