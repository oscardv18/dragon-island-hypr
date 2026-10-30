"""Curated bilingual symbols with opt-in, locked recency writes."""
import json
from pathlib import Path
import time
from engine_common import atomic_json, folded, locked, read_json, result, state_path


def dataset():
    return read_json(Path(__file__).with_name('search-data') / 'emoji.json', [])


def recents():
    try:
        data = read_json(state_path('emoji-recent.json'), {})
        if not isinstance(data, dict):
            return {}
        return {key: value for key, value in data.items() if isinstance(value, (int, float))}
    except (OSError, ValueError):
        return {}


def use(identifier):
    if not any(row['id'] == identifier for row in dataset()):
        raise ValueError('unknown emoji id')
    path = state_path('emoji-recent.json')
    with locked(path):
        recent = recents()
        recent[identifier] = time.time()
        atomic_json(path, dict(sorted(recent.items(), key=lambda pair: (-pair[1], pair[0]))[:100]))


def search(query, language):
    terms = folded(query).split()
    recent = recents()
    now = time.time()
    output = []
    for row in dataset():
        haystack = folded(' '.join(row['name'].values()) + ' ' + ' '.join(sum(row['keywords'].values(), [])) + ' ' + row['char'])
        if not all(term in haystack for term in terms):
            continue
        recency = .19 * 2 ** (-max(0, now - recent[row['id']]) / 604800) if row['id'] in recent else 0
        score = .6 + (.2 if folded(query) == folded(row['name'][language]) else 0) + recency
        output.append(result(row['id'], row['char'], row['name'][language], 'emoji', 'emoji',
                             dict(type='copy', value=row['char']), round(score, 6)))
    return sorted(output, key=lambda row: (-row['score'], row['id']))
