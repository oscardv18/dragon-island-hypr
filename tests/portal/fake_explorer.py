#!/usr/bin/env python3
"""Simulated explorer (tests only): what `qs ipc call picker open|has|cancel <id>` would do, driven by $FAKE_EXPLORER_DIR/plan.json.

plan.json maps a request title to {action, delay, paths, filter, choices}. Actions:
  accept      take the request, answer `accept` with `paths` after `delay` s       cancel   answer `cancel`
  hang        take it and never answer (the user keeps the dialog open)            die      take it, then stop answering `has`
  no_take     `open` succeeds but nothing ever takes the request                   opener_fail   `open` exits 1
  garbage     answer with paths the portal must refuse (relative, wrong count)
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dragon-core'))
import portal_core as core  # noqa: E402

D = Path(os.environ['FAKE_EXPLORER_DIR'])
BIN = str(ROOT / 'bin/dragon-portal')


def log(name, entry):
    with open(D / name, 'a') as handle:
        handle.write(json.dumps(entry) + '\n')


def request_of(rid):
    return core.read_private_json(core.channel('req'), rid + '.json')


def main():
    command, rid = sys.argv[1], sys.argv[2]
    alive = D / ('alive-' + rid)
    if command == 'has':
        print('true' if alive.exists() else 'false')
        return 0
    if command == 'cancel':
        log('cancels.log', rid)
        alive.unlink(missing_ok=True)
        return 0
    if command == '_work':
        spec = json.loads(sys.argv[3])
        time.sleep(float(spec.get('delay', 0)))
        if spec['action'] == 'die':
            alive.unlink(missing_ok=True)
            return 0
        if spec['action'] == 'hang' or not alive.exists():
            return 0
        reply = dict(response='cancel') if spec['action'] == 'cancel' else dict(
            response='accept', paths=spec.get('paths', []), filter=spec.get('filter'), choices=spec.get('choices', {}))
        subprocess.run([BIN, 'reply', rid], input=json.dumps(reply).encode(), capture_output=True)
        alive.unlink(missing_ok=True)
        return 0
    request = request_of(rid)
    plan = json.loads((D / 'plan.json').read_text())
    spec = plan.get(request['title'], dict(action='cancel'))
    log('opens.log', dict(id=rid, title=request['title'], action=spec['action']))
    if spec['action'] == 'opener_fail':
        return 1
    if spec['action'] == 'no_take':
        return 0
    taken = json.loads(subprocess.run([BIN, 'take', rid], capture_output=True, text=True).stdout)
    log('seen.log', taken['request'])
    alive.write_text('1')
    subprocess.Popen([sys.executable, __file__, '_work', rid, json.dumps(spec)], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
