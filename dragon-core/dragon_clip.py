"""Clipboard descriptions, pinned IDs and metadata; never copies or runs a result."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
from urllib.parse import urlsplit
from engine_common import atomic_json, locked, masked, read_json, state_path

LABELS = dict(command='Comando', link='Enlace', path='Ruta', color='Color', image='Imagen', text='Texto')


def color(text):
    if re.fullmatch(r'#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?', text):
        return True
    match = re.fullmatch(r'(rgb|hsl)\(\s*([^()]+)\s*\)', text, re.I)
    if not match:
        return False
    parts = [part.strip() for part in match[2].split(',')]
    if len(parts) != 3:
        return False
    try:
        if match[1].lower() == 'rgb':
            return all(math.isfinite(float(p)) and 0 <= float(p) <= 255 for p in parts)
        return (math.isfinite(float(parts[0])) and all(p.endswith('%') and 0 <= float(p[:-1]) <= 100 for p in parts[1:]))
    except ValueError:
        return False


def kind(text):
    stripped = text.strip()
    if not stripped:
        return 'text'
    if color(stripped):
        return 'color'
    try:
        url = urlsplit(stripped)
        if url.scheme in ('http', 'https', 'ftp') and url.hostname and not re.search(r'\s', stripped):
            return 'link'
        if Path(stripped).expanduser().exists():
            return 'path'
    except (OSError, ValueError):
        pass
    try:
        tokens = shlex.split(stripped.removeprefix('$ '))
        if tokens and (tokens[0] in ('cd', 'export', 'source', 'alias', 'unset', 'set') or shutil.which(tokens[0])):
            return 'command'
    except (ValueError, OSError):
        pass
    return 'text'


def classify(entries):
    if not isinstance(entries, list):
        raise ValueError('expected an array of clipboard entries')
    output = []
    for entry in entries:
        if not isinstance(entry, dict) or 'id' not in entry:
            raise ValueError('each clipboard entry needs an id')
        text = entry.get('text', '')
        if not isinstance(text, str):
            raise ValueError('clipboard text must be a string')
        preview, secret = masked(text)
        category = 'image' if entry.get('isImage', False) else kind(text)
        row = dict(id=entry['id'], kind=category, label=LABELS[category], preview=preview[:120])
        if secret:
            row['secret'] = True
        output.append(row)
    return output


def identifier(value):
    if not re.fullmatch(r'[A-Za-z0-9_.:\-]{1,128}', value):
        raise ValueError('invalid clipboard id')
    return value


def pins(command='list', entry_id=None):
    if command != 'list':
        identifier(entry_id)
    path = state_path('clip-pins.json')

    def load():
        data = read_json(path, [])
        if not isinstance(data, list) or not all(isinstance(value, str) for value in data):
            raise ValueError('invalid pins state')
        return list(dict.fromkeys(data))

    if command == 'list':
        return {'pins': load()}
    with locked(path):
        data = load()
        if command == 'add' and entry_id not in data:
            data.append(entry_id)
        elif command == 'remove':
            data = [value for value in data if value != entry_id]
        atomic_json(path, data)
    return {'pins': data}


def meta(entry_id):
    identifier(entry_id)
    # cliphist IDs are not hashes. Decode to memory to join with our SHA256 map;
    # this avoids persisting any clipboard content or racing a 'cliphist list'.
    try:
        stored = read_json(state_path('clip-meta.json'), {'items': {}})['items']
        if not stored:
            return {}
        process = subprocess.run(['cliphist', 'decode'], input=(entry_id + '\t\n').encode(),
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=.75)
        if process.returncode:
            return {}
        digest = hashlib.sha256(process.stdout).hexdigest()
        row = stored.get(digest, {})
        return {key: row[key] for key in ('app', 'time') if key in row}
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired):
        return {}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    classify_parser = sub.add_parser('classify')
    classify_parser.add_argument('--json', action='store_true')
    pin_parser = sub.add_parser('pins')
    pin_parser.add_argument('operation', choices=['list', 'add', 'remove'])
    pin_parser.add_argument('id', nargs='?')
    pin_parser.add_argument('--json', action='store_true')
    meta_parser = sub.add_parser('meta')
    meta_parser.add_argument('id')
    meta_parser.add_argument('--json', action='store_true')
    args = parser.parse_args(argv)
    if args.command == 'pins' and ((args.operation == 'list') != (args.id is None)):
        parser.error('pins add/remove require an id; list takes no id')
    try:
        if args.command == 'classify':
            output = classify(json.load(sys.stdin))
        elif args.command == 'pins':
            output = pins(args.operation, args.id)
        else:
            output = meta(args.id)
        print(json.dumps(output, ensure_ascii=False, allow_nan=False))
        return 0
    except Exception as error:
        print(json.dumps({'error': str(error)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
