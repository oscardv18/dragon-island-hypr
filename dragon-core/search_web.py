"""Offline URL construction. Config schema is documented in the phase handoff."""
import json
from urllib.parse import quote, urlsplit
from engine_common import config_path, read_json, result

DEFAULTS = [
    dict(id='ddg', name='DuckDuckGo', prefix='ddg', url='https://duckduckgo.com/?q={query}'),
    dict(id='google', name='Google', prefix='g', url='https://www.google.com/search?q={query}'),
    dict(id='github', name='GitHub', prefix='gh', url='https://github.com/search?q={query}'),
    dict(id='youtube', name='YouTube', prefix='yt', url='https://www.youtube.com/results?search_query={query}'),
    dict(id='archwiki', name='ArchWiki', prefix='aw', url='https://wiki.archlinux.org/index.php?search={query}'),
    dict(id='mdn', name='MDN', prefix='mdn', url='https://developer.mozilla.org/en-US/search?q={query}'),
    dict(id='wikipedia-es', name='Wikipedia (ES)', prefix='wiki', lang='es', url='https://es.wikipedia.org/w/index.php?search={query}'),
    dict(id='wikipedia-en', name='Wikipedia (EN)', prefix='wiki', lang='en', url='https://en.wikipedia.org/w/index.php?search={query}'),
    dict(id='stackoverflow', name='Stack Overflow', prefix='so', url='https://stackoverflow.com/search?q={query}')]


def engines():
    try:
        data = read_json(config_path('search-engines.json'), None)
        if data is None:
            return DEFAULTS, 'ddg'
        rows = data['engines']
        if not isinstance(rows, list) or not rows or len(rows) > 50:
            raise ValueError('engines')
        ids = set()
        for row in rows:
            if not all(isinstance(row.get(key), str) and row[key] for key in ('id', 'name', 'url')):
                raise ValueError('engine fields')
            url = urlsplit(row['url'])
            if url.scheme not in ('http', 'https') or not url.hostname or url.username or '{query}' not in row['url']:
                raise ValueError('URL template')
            if row['id'] in ids or not isinstance(row.get('prefix', ''), str):
                raise ValueError('engine id/prefix')
            if row.get('lang', 'es') not in ('es', 'en'):
                raise ValueError('language')
            ids.add(row['id'])
        default = data.get('default', rows[0]['id'])
        if default not in ids:
            raise ValueError('default')
        return rows, default
    except (OSError, ValueError, KeyError, TypeError, AttributeError, json.JSONDecodeError):
        return DEFAULTS, 'ddg'


def search(query, language):
    rows, selected = engines()
    query = query.strip()
    if not query:
        return []
    parts = query.split(None, 1)
    prefix, rest = parts[0], parts[1] if len(parts) == 2 else ''
    prefixed = [row for row in rows if row.get('prefix') == prefix.lower()]
    if prefixed:
        preferred = next((row for row in prefixed if row.get('lang') == language), prefixed[0])
        selected, query = preferred['id'], rest.strip()
    if not query:
        return []
    ordered = sorted(rows, key=lambda row: row['id'] != selected)
    return [result('web:' + row['id'], row['name'], query, 'web', 'web',
                   dict(type='open-url', value=row['url'].replace('{query}', quote(query, safe=''))),
                   round(.99 - index * .01, 6)) for index, row in enumerate(ordered)]
