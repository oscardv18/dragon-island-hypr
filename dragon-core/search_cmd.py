"""Executable names and a bounded tail of zsh history; candidates are never run."""
import hashlib
import heapq
import math
import os
from pathlib import Path
import re
import time
from engine_common import folded, secret_spans, result


def matching(text, query):
    if not query:
        return .2
    text, query = folded(text), folded(query)
    if text == query:
        return .85
    if text.startswith(query):
        return .75
    if any(word.startswith(query) for word in text.split()):
        return .6
    if query in text:
        return .45
    return 0


def history():
    path = Path(os.environ.get('HISTFILE') or Path.home() / '.zsh_history').expanduser()
    try:
        with path.open('rb') as handle:
            handle.seek(0, 2)
            size = handle.tell()
            handle.seek(max(0, size - 524288))
            if size > 524288:
                handle.readline()  # discard an incomplete first record
            text = handle.read().decode('utf-8', errors='replace')
    except OSError:
        return []
    records = []
    pending = ''
    timestamp = 0
    for line in text.splitlines():
        if not pending:
            match = re.match(r'^: (\d+):\d+;(.*)$', line)
            timestamp = int(match[1]) if match else 0
            line = match[2] if match else line
        if line.endswith('\\'):
            pending += line[:-1] + '\n'
            continue
        records.append((pending + line, timestamp))
        pending = ''
    return records[-4000:]


def search(query, limit=100):
    candidates = {}
    for directory in dict.fromkeys(os.environ.get('PATH', '').split(os.pathsep)):
        try:
            with os.scandir(directory or '.') as entries:
                for entry in entries:
                    score = matching(entry.name, query)
                    if entry.name in candidates or not score:
                        continue
                    if entry.is_file() and os.access(entry.path, os.X_OK):
                        candidates[entry.name] = dict(terminal=False, frequency=0.0, match=score)
        except OSError:
            continue
    now = time.time()
    frequencies = {}
    for index, (line, timestamp) in enumerate(history()):
        line = line.strip()
        if not line or len(line) > 4096:
            continue
        weight = math.exp2(-max(0, now - timestamp) / 604800) if timestamp else (index + 1) / 4000
        frequencies[line] = frequencies.get(line, 0) + weight
    for line, weight in frequencies.items():
        score = matching(line, query)
        if not score or secret_spans(line):
            continue
        candidate = candidates.setdefault(line, dict(terminal=True, frequency=0.0, match=score))
        candidate['frequency'] += weight
    maximum = max((x['frequency'] for x in candidates.values()), default=1) or 1
    ranked = ((-round(data['match'] + .14 * data['frequency'] / maximum, 6), line, data)
              for line, data in candidates.items())
    output = []
    for negative_score, line, data in heapq.nsmallest(limit, ranked):
        score = -negative_score
        argv = ['sh', '-c', line] if data['terminal'] else [line]
        output.append(result('cmd:' + hashlib.sha256(line.encode()).hexdigest()[:20], line,
                             'Historial de zsh' if data['terminal'] else 'Ejecutable del PATH', 'terminal', 'cmd',
                             dict(type='exec', argv=argv, terminal=data['terminal']), score))
    return sorted(output, key=lambda row: (-row['score'], row['title']))
