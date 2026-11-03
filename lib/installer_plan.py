#!/usr/bin/env python3
"""Turn the read-only preflight JSON into tab-separated plan lines for install.sh. No side effects.

Usage: installer_plan.py <preflight.json> [--engine base,keyring,...]
Lines (tab separated):
  pkg    <name> <state> <detail> <source> <engine 0|1>   state: installed | install | aur | conflict   (only the packages of the profiles)
  issue  <action> <subject> <why> <what the installer does>
                                                         action: bloquear | omitir | sustituir | conservar | aviso | compilar | nota
  check  <level> <id> <message> <remedy>                 kept for the JSON/tests: 'aviso' and 'bloqueante', grouped
  meta   <key> <value>                                   size_bytes, blocked, to_install, total, deps, deps_names
Every package that is not a plain «install»/«installed» gets an `issue` line saying WHICH package, WHY and WHAT the installer will do:
the plan screen never shows a bare counter of problems.
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

# Dependencies whose presence in the plan deserves a sentence of its own: package -> what it is for.
NOTABLE_DEPENDENCIES = {
    'xorg-server': 'el servidor X lo exige sddm como dependencia fija (también para su pantalla de acceso en Wayland); '
                   'Hyprland no lo usa, solo Xwayland',
}


def clean(text):
    return ' '.join(str(text).split())


def base(name):
    return re.split(r'[<>=]', name, maxsplit=1)[0]


# packages involved in a blocking Conflicts With (id: conflicts:<context>:<a>:<b>)
conflicting = {}
for check in checks:
    if check['id'].startswith('conflicts:') and check['level'] == 'bloqueante':
        _, context, a, b = (check['id'].split(':') + ['', '', '', ''])[:4]
        why = clean(check.get('evidence', ''))
        conflicting.setdefault(a, why)
        conflicting.setdefault(b, why)

size = 0
for check in checks:
    if check['id'] == 'transaction':
        for line in check.get('evidence', '').splitlines():
            fields = line.split()
            if len(fields) == 4 and fields[3].isdigit():
                size += int(fields[3])

by_name = {p['name']: p for p in packages}
top = [p for p in packages if 'dependency' not in p.get('profiles', [])]
deps = [p for p in packages if 'dependency' in p.get('profiles', [])]
to_install = 0
for p in top:
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
        detail = ('ya satisfecho (lo provee %s)' if p.get('provider_origin') == 'installed'
                  else 'lo proveerá %s (incluido en el plan)') % p['provider']
    if state == 'change' and p.get('installed_version'):
        detail = '%s→%s' % (p['installed_version'], p.get('version', ''))
    if shown == 'conflict':
        detail = 'conflicto: ' + conflicting[p['name']]
    in_engine = int(bool((set(p.get('profiles', [])) | set(p.get('required_profiles', []))) & engine))
    print('\t'.join(['pkg', p['name'], shown, clean(detail), p.get('source', 'pacman'), str(in_engine)]))

    if state == 'satisfied':
        if p.get('provider_origin') == 'installed':
            print('\t'.join(['issue', 'omitir', p['name'], 'ya está cubierto por %s (instalado)' % p['provider'],
                             'no se instala %s: se conserva %s' % (p['name'], p['provider'])]))
        else:
            print('\t'.join(['issue', 'omitir', p['name'], 'lo ofrece %s, que va en el mismo plan' % p['provider'],
                             'se instala solo %s' % p['provider']]))
    elif shown == 'conflict':
        print('\t'.join(['issue', 'bloquear', p['name'], clean(conflicting[p['name']]),
                         'se detiene antes de cambiar nada; resuelve la selección y repite']))

for check in checks:
    cid, level = check['id'], check['level']
    if cid.startswith('conflicts:'):
        continue
    if level == 'bloqueante' and not cid.startswith(('package:', 'desktop:')):
        print('\t'.join(['issue', 'bloquear', cid, clean(check['message']) + ' ' + clean(check.get('evidence', ''))[:120],
                         clean(check.get('remedy', '')) or 'se detiene antes de cambiar nada']))
    elif level == 'bloqueante' and cid.startswith('package:'):
        print('\t'.join(['issue', 'bloquear', cid.split(':', 1)[1], clean(check['message']),
                         'se detiene antes de cambiar nada: ' + (clean(check.get('remedy', '')) or 'revisa el nombre')]))
    elif level == 'bloqueante' and cid.startswith('desktop:'):
        print('\t'.join(['issue', 'bloquear', cid.split(':', 1)[1], clean(check['message']), clean(check.get('remedy', ''))]))
    elif cid.startswith('replaces:'):
        a, b = cid.split(':')[2:4]
        print('\t'.join(['issue', 'sustituir', f'{a} / {b}', clean(check.get('evidence', '')),
                         'pacman sustituye uno por el otro durante la instalación (sin preguntar)']))
    elif cid.startswith('provides:'):
        a, b = cid.split(':')[1:3]
        extra = ''
        if 'org.freedesktop.secrets' in check.get('evidence', ''):
            extra = '; el módulo keyring deja a gnome-keyring como único dueño del llavero'
        print('\t'.join(['issue', 'aviso', f'{a} / {b}', 'ofrecen la misma capacidad (' + clean(check.get('evidence', '')) + ')',
                         'se instalan los dos; no declaran conflicto' + extra]))
    elif cid.startswith('desktop:'):
        pass  # grouped below
    elif cid.startswith('leftover:'):
        print('\t'.join(['issue', 'conservar', cid.split(':', 1)[1], 'paquete opcional de CachyOS',
                         'no se quita; puedes desinstalarlo tú cuando quieras']))
    elif cid == 'kwallet' and level == 'aviso':
        print('\t'.join(['issue', 'conservar', clean(check.get('evidence', '')), 'KWallet de Plasma',
                         'no se quita; solo un servicio de secretos debe arrancar en Hyprland (módulo keyring)']))

desktop = [c['id'].split(':', 1)[1] for c in checks if c['id'].startswith('desktop:') and c['level'] == 'aviso']
if desktop:
    print('\t'.join(['issue', 'conservar', f'{len(desktop)} paquetes de Plasma/GNOME', ', '.join(desktop[:4]) + (' …' if len(desktop) > 4 else ''),
                     'no se tocan: Hyprland se instala como sesión adicional']))

# AUR: ONE note for the whole list (the PKGBUILD advice used to be repeated once per package)
aur = [json.loads(c['evidence']) for c in checks if c['id'].startswith('aur-build:')]
if aur:
    outside = sorted({d for item in aur for d in item.get('unresolved_dependencies', [])})
    names = ', '.join(item['package'] for item in aur)
    why = f'se compilan en esta máquina ({len(aur)}): {names}'
    if outside:
        why += '; dependencias de compilación fuera del plan: ' + ', '.join(outside)
    print('\t'.join(['issue', 'compilar', 'AUR', why,
                     'el ayudante AUR los construye uno a uno; revisa sus PKGBUILD si no los conoces']))

# dependencies that pacman adds: summary + the notable ones with their reason
requesters = {}
for p in packages:
    for dep in p.get('depends', []):
        requesters.setdefault(base(dep), []).append(p['name'])
for name, reason in NOTABLE_DEPENDENCIES.items():
    if name in by_name and 'dependency' in by_name[name].get('profiles', []):
        who = sorted(set(requesters.get(name, [])) & {p['name'] for p in packages})
        print('\t'.join(['issue', 'nota', name, 'lo trae ' + (', '.join(who) or 'otro paquete del plan') + ': ' + reason, 'se instala como dependencia']))

# remaining aviso/bloqueante checks, grouped by (level, message, remedy): kept for consumers that want the raw list
groups = {}
for check in checks:
    if check['level'] in ('aviso', 'bloqueante') and not check['id'].startswith(('aur-build:', 'desktop:', 'leftover:', 'provides:', 'replaces:')):
        key = (check['level'], re.sub(r'^[\w.+-]+: ', '', clean(check['message'])), clean(check.get('remedy', '')))
        groups.setdefault(key, []).append(check['id'] + (': ' + clean(check.get('evidence', ''))[:90] if check['level'] == 'bloqueante' else ''))
for (level, message, remedy), ids in groups.items():
    shown = ', '.join(ids[:3]) + (' … (+%d)' % (len(ids) - 3) if len(ids) > 3 else '')
    print('\t'.join(['check', level, shown, message, remedy]))
    if not any(i.startswith(('package:', 'conflicts:')) for i in ids) and level == 'aviso':
        print('\t'.join(['issue', 'aviso', ids[0].split(':')[0], message, remedy or 'solo informativo; no cambia el plan']))

print('meta\tsize_bytes\t%d' % size)
print('meta\tblocked\t%d' % int(bool(data.get('blocked'))))
print('meta\tto_install\t%d' % to_install)
print('meta\ttotal\t%d' % len(top))
print('meta\tdeps\t%d' % len(deps))
