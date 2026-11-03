#!/usr/bin/env python3
"""Turn the read-only preflight JSON into tab-separated plan lines for install.sh. No side effects.

Usage: installer_plan.py <preflight.json> [--engine base,keyring,...]
Lines (tab separated):
  pkg    <name> <state> <detail> <source> <engine 0|1>   state: installed | install | aur | conflict
  check  <level> <id> <message> <remedy>                  only 'aviso' and 'bloqueante'
  meta   <key> <value>                                    size_bytes, blocked, to_install, total
"""
import json
import re
import sys

path = sys.argv[1]
engine = set()
if '--engine' in sys.argv:
    engine = set(sys.argv[sys.argv.index('--engine') + 1].split(','))

data = json.load(open(path))
packages = data.get('packages', [])
checks = data.get('checks', [])


def clean(text):
    return ' '.join(str(text).split())


# packages involved in a blocking Conflicts With (id: conflicts:<context>:<a>:<b>)
conflicting = set()
for check in checks:
    if check['id'].startswith('conflicts:') and check['level'] == 'bloqueante':
        conflicting.update(check['id'].split(':')[2:])

size = 0
for check in checks:
    if check['id'] == 'transaction':
        for line in check.get('evidence', '').splitlines():
            fields = line.split()
            if len(fields) == 4 and fields[3].isdigit():
                size += int(fields[3])

to_install = 0
for p in packages:
    state = p.get('state', 'install')
    if p['name'] in conflicting:
        shown = 'conflict'
    elif state in ('installed', 'satisfied'):
        shown = 'installed'
    elif p.get('source') == 'aur':
        shown = 'aur'
    else:
        shown = 'install'
    if shown in ('install', 'aur'):
        to_install += 1
    detail = p.get('version', '')
    if state == 'satisfied':
        detail = 'ya satisfecho (lo provee %s)' % p['provider']
    if state == 'change' and p.get('installed_version'):
        detail = '%s→%s' % (p['installed_version'], p.get('version', ''))
    in_engine = int(bool(set(p.get('profiles', [])) & engine))
    print('\t'.join(['pkg', p['name'], shown, clean(detail), p.get('source', 'pacman'), str(in_engine)]))

# one line per (level, message): repeated findings (a dozen plasma-* packages) are grouped with their ids
groups = {}
for check in checks:
    if check['level'] in ('aviso', 'bloqueante'):
        key = (check['level'], re.sub(r'^[\w.+-]+: ', '', clean(check['message'])), clean(check.get('remedy', '')))
        groups.setdefault(key, []).append(check['id'] + (': ' + clean(check.get('evidence', ''))[:90] if check['level'] == 'bloqueante' else ''))
for (level, message, remedy), ids in groups.items():
    shown = ', '.join(ids[:3]) + (' … (+%d)' % (len(ids) - 3) if len(ids) > 3 else '')
    print('\t'.join(['check', level, shown, message, remedy]))

print('meta\tsize_bytes\t%d' % size)
print('meta\tblocked\t%d' % int(bool(data.get('blocked'))))
print('meta\tto_install\t%d' % to_install)
print('meta\ttotal\t%d' % len(packages))
