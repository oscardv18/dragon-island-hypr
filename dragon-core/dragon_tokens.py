"""Read-only local usage totals for the current local calendar day.

Claude assistant.message.usage is cumulative per message ID (deduplicate streaming
updates with maxima). cache = creation + read input tokens, separate from in.
Codex event_msg/token_count.info.total_token_usage is cumulative per session;
deltas are attributed to their event day, including a baseline before midnight.
Repeated counters add nothing; a reset starts a new counter segment. Input includes
cached input; reasoning is already included in output. Unknown usage yields null.
No conversation text, IDs, file paths or raw records are emitted or persisted.
"""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
from taller_common import Parser, emit


class UnknownUsage(Exception):
    pass


def timestamp(value):
    try:
        if not isinstance(value, str): raise ValueError
        parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if parsed.tzinfo is None: parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed
    except ValueError: raise UnknownUsage from None


def count(usage, key):
    value = usage.get(key)
    if not isinstance(value, int) or isinstance(value, bool) or value < 0: raise UnknownUsage
    return value


def records(root):
    if not root.is_dir(): raise UnknownUsage
    paths = sorted(root.rglob('*.jsonl'))
    if not paths: raise UnknownUsage
    for path in paths:
        with path.open(encoding='utf-8', errors='replace') as handle:
            for line in handle:
                try: row = json.loads(line)
                except ValueError: continue  # tolerate partial last lines during active writes
                if isinstance(row, dict): yield path, row


def claude(root, today):
    messages = {}; recognized = False
    for _, row in records(root):
        if row.get('type') != 'assistant': continue
        message = row.get('message')
        if not isinstance(message, dict) or 'usage' not in message: continue
        usage = message['usage']
        day = timestamp(row.get('timestamp')).astimezone().date()
        if not isinstance(usage, dict):
            if day == today: raise UnknownUsage
            continue
        try:
            values = (count(usage, 'input_tokens'), count(usage, 'output_tokens'),
                      count(usage, 'cache_creation_input_tokens')+count(usage, 'cache_read_input_tokens'))
        except UnknownUsage:
            if day == today: raise
            continue
        recognized = True
        if day != today: continue
        identity = message.get('id')
        if not isinstance(identity, str) or not identity: raise UnknownUsage
        previous = messages.get(identity, (0, 0, 0))
        messages[identity] = tuple(max(x, y) for x, y in zip(previous, values))
    if not recognized: raise UnknownUsage
    return dict(zip(('in', 'out', 'cache'), (sum(v[n] for v in messages.values()) for n in range(3))))


def codex(root, today):
    sessions = {}; identities = {}; recognized = False
    for path, row in records(root):
        payload = row.get('payload')
        if row.get('type') == 'session_meta' and isinstance(payload, dict):
            if isinstance(payload.get('id'), str): identities[path] = payload['id']
        if row.get('type') != 'event_msg' or not isinstance(payload, dict) or payload.get('type') != 'token_count': continue
        info = payload.get('info')
        # Native rate-limit-only token_count events have info:null, no usage.
        if info is None: continue
        stamp = timestamp(row.get('timestamp'))
        try:
            usage = info['total_token_usage']
            values = (count(usage, 'input_tokens'), count(usage, 'output_tokens'))
        except (UnknownUsage, TypeError, KeyError, AttributeError):
            if stamp.astimezone().date() == today: raise UnknownUsage from None
            continue
        recognized = True
        sessions.setdefault(identities.get(path, str(path)), []).append((stamp, values))
    if not recognized: raise UnknownUsage
    totals = [0, 0]
    for events in sessions.values():
        previous = (0, 0)
        for stamp, current in sorted(dict.fromkeys(events), key=lambda event: event[0]):
            delta = current if any(c < p for c, p in zip(current, previous)) else tuple(c-p for c, p in zip(current, previous))
            if stamp.astimezone().date() == today:
                totals = [v+d for v, d in zip(totals, delta)]
            previous = current
    return dict(zip(('in', 'out'), totals))


def today_usage():
    today = datetime.now().astimezone().date()
    roots = dict(claude=Path(os.environ.get('CLAUDE_CONFIG_DIR', str(Path.home()/'.claude')))/'projects',
                 codex=Path(os.environ.get('CODEX_HOME', str(Path.home()/'.codex')))/'sessions')
    result = dict(ok=True)
    for name, parser in (('claude', claude), ('codex', codex)):
        try: result[name] = parser(roots[name], today)
        except (UnknownUsage, OSError, ValueError, TypeError, AttributeError): result[name] = None
    return result


def main():
    root = Parser(description=__doc__); root.add_argument('command', choices=['today']); root.add_argument('--json', action='store_true')
    root.parse_args(sys.argv[1:]); emit(today_usage()); return 0


if __name__ == '__main__': raise SystemExit(main())
