"""Private activity JSONL. Each line is a complete entry; the last line for an ID wins.

add/end append under a separate flock; compaction uses an atomic replacement under
that same lock. Readers persist expired open entries as unknown. No daemon or index.
"""
import fcntl
import json
import math
import os
import sys
import time


RETENTION = 30 * 86400
OPEN_TIMEOUT = 12 * 3600
COMPACT_BYTES = 1000000
KINDS = ('agent', 'command', 'focus')
STATUSES = ('ok', 'fail', 'blocked', 'unknown')
FIELDS = {'id', 'kind', 'name', 'start', 'end', 'status'}


def state_path(name):
    root = os.environ.get('XDG_STATE_HOME') or os.path.expanduser('~/.local/state')
    return os.path.join(root, 'dragon-island', name)


class ActivityLock:
    def __init__(self, path):
        self.path = path

    def __enter__(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True, mode=0o700)
        self.fd = os.open(self.path + '.lock', os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(self.fd, fcntl.LOCK_EX)
        except BaseException:
            os.close(self.fd)
            raise
        return self

    def __exit__(self, *_):
        os.close(self.fd)


def epoch(value):
    number = float(value)
    if not math.isfinite(number):
        raise ValueError('epoch must be finite')
    return int(number) if number.is_integer() else number


def safe_name(name):
    from engine_common import secret_spans
    # Check the full input BEFORE truncation: credentials may occur beyond char 80.
    text = ' '.join(name.split())
    if secret_spans(text):
        first = text.split(' ', 1)[0]
        # A leading assignment or bare credential must not survive as the first token.
        text = '[redacted]' if secret_spans(first) else first
    return text[:80]


def read_items(path):
    try:
        # Decode a JSONL batch with one C decoder invocation, keeping CLI polling fast.
        with open(path, encoding='utf-8') as handle:
            text = handle.read()
    except FileNotFoundError:
        return {}
    rows = json.loads('[' + ','.join(text.splitlines()) + ']')
    items = {}
    for item in rows:
        if not isinstance(item, dict) or item.keys() != FIELDS:
            raise ValueError('invalid activity entry')
        items[item['id']] = item
    return items


def expired(items, now):
    updates = []
    for item in items.values():
        if item['end'] is None and now - item['start'] > OPEN_TIMEOUT:
            item['end'] = item['start'] + OPEN_TIMEOUT
            item['status'] = 'unknown'
            updates.append(item)
    return updates


def encode(item):
    return json.dumps(item, ensure_ascii=False, allow_nan=False, separators=(',', ':')) + '\n'


def persist(path, items, updates, now):
    data = ''.join(map(encode, updates))
    size = os.path.getsize(path) if os.path.exists(path) else 0
    if size + len(data.encode('utf-8')) > COMPACT_BYTES:
        # Retain any interval overlapping the last 30 days, including active work.
        kept = [item for item in items.values()
                if item['end'] is None or item['end'] >= now - RETENTION]
        import tempfile
        fd, temporary = tempfile.mkstemp(prefix='.activity-', dir=os.path.dirname(path))
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as handle:
                for item in sorted(kept, key=lambda row: (row['start'], row['id'])):
                    handle.write(encode(item))
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    elif data:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())


def add(kind, name, start, end=None, status='ok'):
    path = state_path('activity.jsonl')
    with ActivityLock(path):
        items = read_items(path)
        now = time.time()
        updates = expired(items, now)
        identifier = os.urandom(6).hex()
        while identifier in items:
            identifier = os.urandom(6).hex()
        item = dict(id=identifier, kind=kind, name=safe_name(name), start=start, end=end, status=status)
        items[identifier] = item
        updates.append(item)
        persist(path, items, updates, now)
    return identifier


def end(identifier, status='ok'):
    path = state_path('activity.jsonl')
    if not os.path.exists(path):
        raise ValueError(f'unknown activity id: {identifier}')
    with ActivityLock(path):
        items = read_items(path)
        if identifier not in items:
            raise ValueError(f'unknown activity id: {identifier}')
        item = items[identifier]
        now = time.time()
        updates = expired(items, now)
        if item['end'] is None:
            item['end'] = max(now, item['start'])
            item['status'] = status
            updates.append(item)
        persist(path, items, updates, now)


def activity_range(start, stop):
    path = state_path('activity.jsonl')
    if not os.path.exists(path):
        return []
    with ActivityLock(path):
        items = read_items(path)
        now = time.time()
        updates = expired(items, now)
        if updates:
            persist(path, items, updates, now)
        rows = [item for item in items.values()
                if item['start'] <= stop and (item['end'] is None or item['end'] >= start)]
    return sorted(rows, key=lambda item: (item['start'], item['id']))


USAGE = """Usage:
dragon-activity add --kind agent|command|focus --name TEXT --start EPOCH [--end EPOCH] [--status ok|fail|blocked]
dragon-activity end ID [--status ok|fail]
dragon-activity range --from EPOCH --to EPOCH --json"""


def parse(argv):
    # This fixed CLI avoids argparse's startup cost on the frequently polled range path.
    if not argv or argv[0] not in ('add', 'end', 'range'):
        raise ValueError('expected add, end or range')
    command, *arguments = argv
    values = {'command': command}
    if command == 'end':
        if not arguments or arguments[0].startswith('--'):
            raise ValueError('end requires an id')
        values['id'] = arguments.pop(0)
    allowed = {'add': {'--kind', '--name', '--start', '--end', '--status'},
               'end': {'--status'}, 'range': {'--from', '--to', '--json'}}[command]
    seen = set()
    while arguments:
        option = arguments.pop(0)
        if option not in allowed or option in seen:
            raise ValueError(f'unknown or repeated option: {option}')
        seen.add(option)
        if option == '--json':
            continue
        if not arguments:
            raise ValueError(f'missing value for {option}')
        values[option[2:]] = arguments.pop(0)
    required = {'add': {'kind', 'name', 'start'}, 'end': {'id'}, 'range': {'from', 'to'}}[command]
    if not required <= values.keys():
        raise ValueError('missing required options')
    for key in ('start', 'end', 'from', 'to'):
        if key in values:
            values[key] = epoch(values[key])
    if command == 'add':
        values.setdefault('end', None)
        values.setdefault('status', 'ok')
        if values['kind'] not in KINDS or values['status'] not in STATUSES[:3]:
            raise ValueError('invalid kind or status')
        if values['end'] is not None and values['end'] < values['start']:
            raise ValueError('--end must be >= --start')
    elif command == 'end':
        values.setdefault('status', 'ok')
        if values['status'] not in ('ok', 'fail'):
            raise ValueError('invalid status')
    elif values['to'] < values['from']:
        raise ValueError('--to must be >= --from')
    return values


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv in (['--help'], ['-h']) or (len(argv) == 2 and argv[1] in ('--help', '-h')):
        print(USAGE)
        return 0
    try:
        args = parse(argv)
    except ValueError as error:
        print(f'dragon-activity: {error}\n{USAGE}', file=sys.stderr)
        return 2
    try:
        if args['command'] == 'add':
            print(add(args['kind'], args['name'], args['start'], args['end'], args['status']))
        elif args['command'] == 'end':
            end(args['id'], args['status'])
        else:
            print(json.dumps({'items': activity_range(args['from'], args['to'])}, ensure_ascii=False,
                             allow_nan=False, separators=(',', ':')))
    except (OSError, ValueError, TypeError) as error:
        print(f'dragon-activity: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
