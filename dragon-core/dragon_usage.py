"""Application IDs only. Exact week counts and exponentially decayed frecency.

Disk format v1: last 2000 event seconds per app; overflow events become counters
per second for seven days, then a count plus an exponential sum at a fixed anchor.
This preserves the decay curve and exact rolling-week counts after compaction.
"""
import argparse
import json
import math
import re
import sys
import time
from engine_common import atomic_json, locked, read_json, state_path

WEEK = 7 * 86400
LIMIT = 2000


def identifier(value):
    if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.+\-]{0,254}', value):
        raise ValueError('desktop-id must be an ID, without paths or arguments')
    return value


def decay(value, elapsed):
    return value * math.exp2(-max(0, elapsed) / WEEK)


def load():
    data = read_json(state_path('usage.json'), {'version': 1, 'apps': {}})
    if not isinstance(data, dict) or data.get('version') != 1 or not isinstance(data.get('apps'), dict):
        raise ValueError('invalid usage state')
    return data


def compact(app, now):
    events = sorted(app['events'])
    overflow = events[:-LIMIT]
    app['events'] = events[-LIMIT:]
    buckets = app['buckets']
    for timestamp in overflow:
        key = str(timestamp)
        buckets[key] = buckets.get(key, 0) + 1
    past = app['past']
    expired = sorted(int(key) for key in buckets if int(key) <= now - WEEK)
    if expired:
        anchor = max(now, past['at'])
        weight = decay(past['weight'], anchor - past['at'])
        for timestamp in expired:
            count = buckets.pop(str(timestamp))
            past['count'] += count
            weight += decay(count, anchor - timestamp)
        past.update(at=anchor, weight=weight)


def record(desktop_id, now=None):
    identifier(desktop_id)
    now = int(time.time()) if now is None else int(now)
    path = state_path('usage.json')
    with locked(path):
        data = load()
        app = data['apps'].setdefault(desktop_id, dict(total=0, lastUsed=0, events=[], buckets={},
                                                      past=dict(count=0, weight=0.0, at=now)))
        app['events'].append(now)
        app['total'] += 1
        app['lastUsed'] = max(now, app['lastUsed'])
        compact(app, now)
        atomic_json(path, data)


def stats(now=None):
    now = int(time.time()) if now is None else int(now)
    data = load()
    anchor = max((app['lastUsed'] for app in data['apps'].values()), default=now)
    rows = []
    for desktop_id, app in sorted(data['apps'].items()):
        events, buckets, past = app['events'], app['buckets'], app['past']
        week = sum(now - WEEK < timestamp <= now for timestamp in events)
        week += sum(count for timestamp, count in buckets.items() if now - WEEK < int(timestamp) <= now)
        weight = math.fsum([decay(1, anchor - timestamp) for timestamp in events]
                           + [decay(count, anchor - int(timestamp)) for timestamp, count in sorted(buckets.items())]
                           + [decay(past['weight'], anchor - past['at'])])
        rows.append(dict(id=desktop_id, total=app['total'], week=week,
                         lastUsed=app['lastUsed'], frecency=weight))
    maximum = max((row['frecency'] for row in rows), default=0)
    for row in rows:
        row['frecency'] = round(row['frecency'] / maximum, 12) if maximum else 0.0
    rows.sort(key=lambda row: (-row['frecency'], row['id']))
    return {'apps': rows}


def forget(desktop_id=None):
    if desktop_id is not None:
        identifier(desktop_id)
    path = state_path('usage.json')
    with locked(path):
        data = load()
        if desktop_id is None:
            data['apps'].clear()
        else:
            data['apps'].pop(desktop_id, None)
        atomic_json(path, data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['record', 'stats', 'forget', 'reset'])
    parser.add_argument('id', nargs='?')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args(argv)
    if args.command in ('record', 'forget') and args.id is None:
        parser.error('desktop-id is required')
    if args.command in ('stats', 'reset') and args.id is not None:
        parser.error('this command takes no desktop-id')
    try:
        if args.command == 'record':
            record(args.id)
        elif args.command == 'forget':
            forget(args.id)
        elif args.command == 'reset':
            forget()
        print(json.dumps(stats() if args.command == 'stats' else {'ok': True}, ensure_ascii=False, allow_nan=False))
        return 0
    except Exception as error:
        print(json.dumps({'error': str(error)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
