#!/usr/bin/python3
"""Executable fixtures: reject every non-read-only command; never invoke a host service."""
import json
import os
from pathlib import Path
import sys
from urllib.parse import parse_qs, urlparse

command = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['PREFLIGHT_FAKE_LOG'], 'a') as log:
    log.write(json.dumps([command, *args]) + '\n')


STATE = os.environ.get('FAKE_STATE')          # stateful mode (tests/installer_ux): a directory holding the fake system
SYSTEM = Path(os.environ.get('DRAGON_PREFLIGHT_ROOT', '/'))


def state_read(name, default=''):
    path = Path(STATE) / name
    return path.read_text() if path.exists() else default


def installed_set():
    return {line for line in state_read('installed').splitlines() if line}


def state_install(names):
    have = installed_set() | set(names)
    (Path(STATE) / 'installed').write_text('\n'.join(sorted(have)) + '\n')


def maybe_fail(names):
    failing = set(filter(None, os.environ.get('FAKE_FAIL_INSTALL', '').split(',')))
    bad = [n for n in names if n in failing]
    if bad:
        print(f'error: failed to commit transaction (could not satisfy dependencies for {bad[0]}) password=hunter2 Bearer abcdefghijklmnop')
        sys.exit(1)


def stateful(command, args):
    """Commands whose result depends on what was "installed" so far. Returns True when handled."""
    if command == 'systemd-detect-virt':
        virt = os.environ.get('FAKE_VIRT', 'none')
        print(virt)
        sys.exit(0 if virt != 'none' else 1)
    if command == 'uname' and args == ['-r']:
        print(state_read('uname', '6.test').strip()); return True
    if command == 'sudo':
        if args[:1] in (['-v'], ['-n']):
            return True
        os.execvp(args[0], args)
    if command == 'pacman':
        flags = [a for a in args if a.startswith('-')]
        names = [a for a in args if not a.startswith('-')]
        if args[0] == '-T':
            if os.environ.get('PREFLIGHT_FAKE_DEPTEST_ERROR'):
                print('database unavailable', file=sys.stderr); sys.exit(1)
            have = installed_set()
            missing = [n for n in args[2:] if n not in have]
            if missing:
                print('\n'.join(missing)); sys.exit(127)
            return True
        if args[0].startswith('-S') and args[0] not in ('-Si', '-Sp') and not args[0].startswith('-Ss'):
            if 'y' in args[0][2:] and 'u' not in args[0][2:] and args[0] != '-Syu':
                print('error: partial upgrade refused by the fake (-Sy)'); sys.exit(98)
            maybe_fail(names)
            state_install(names)
            if args[0] == '-Syu' and os.environ.get('FAKE_UPDATE_REPLACES_KERNEL') and (SYSTEM / 'usr/lib/modules/6.test').exists():
                import shutil
                shutil.rmtree(SYSTEM / 'usr/lib/modules/6.test')
                new = SYSTEM / 'usr/lib/modules/7.new'; new.mkdir(parents=True)
                (new / 'pkgbase').write_text('linux-cachyos\n')
            for n in names:
                print(f'(1/1) installing {n}')
            return True
        if args[0] == '-Qq' and len(args) > 1:
            sys.exit(0 if args[1] in installed_set() else 1)
        if args[0] == '-Qqe':
            print('\n'.join(sorted(installed_set()))); return True
        if args[0] == '-Qi':
            sys.stdout.write(record('linux-cachyos') + ''.join(record(n) for n in sorted(installed_set())))
            return True
        if args[0] == '-Ql':
            for d in sorted((SYSTEM / 'usr/lib/modules').glob('*')):
                print(f'{args[1]} /usr/lib/modules/{d.name}/pkgbase')
            return True
        if args[0] == '-Si' and args[1] == 'paru' and os.environ.get('FAKE_NO_PARU_REPO'):
            sys.exit(1)
        if args[0] == '-Sp':
            for n in args[5:]:
                if n not in installed_set():
                    print(n, '1.0 cachyos-v4 100')
            return True
        return False
    if command in ('paru', 'yay'):
        names = [a for a in args if not a.startswith('-')]
        maybe_fail(names)
        state_install(names); return True
    if command == 'git' and args[:1] == ['clone']:
        target = Path(args[-1]); target.mkdir(parents=True); (target / 'PKGBUILD').write_text('pkgname=stub\n'); return True
    if command == 'makepkg':
        state_install(['paru-bin', 'paru'])
        link = Path(os.environ['FAKE_BIN']) / 'paru'
        if not link.exists():
            link.symlink_to(Path(os.environ['FAKE_BIN']) / 'fixture')
        return True
    return False


def record(name):
    version = {'hyprland': '0.56.2', 'quickshell': '0.3.1', 'neovim': '0.12.6'}.get(name, '1.0')
    if name in json.loads(os.environ.get('PREFLIGHT_FAKE_PACKAGES', '{}')):
        return json.loads(os.environ['PREFLIGHT_FAKE_PACKAGES'])[name]
    return f'Name : {name}\nVersion : {version}\nRepository : cachyos-v4\nProvides : None\nConflicts With : None\nReplaces : None\nDepends On : None\nRequired By : None\n\n'


if STATE and stateful(command, args):
    sys.exit(0)
if command == 'pacman':
    if args[0] == '-Qi':
        print(record('linux-cachyos') + record('linux-cachyos-headers') +
              ''.join(record(n) for n in os.environ.get('PREFLIGHT_FAKE_INSTALLED', '').split(',') if n), end='')
    elif args[0] == '-T':
        if os.environ.get('PREFLIGHT_FAKE_DEPTEST_ERROR'):
            print('database unavailable', file=sys.stderr)
            sys.exit(1)
        capabilities = {'linux-cachyos', 'linux-cachyos-headers'}
        for name in filter(None, os.environ.get('PREFLIGHT_FAKE_INSTALLED', '').split(',')):
            capabilities.add(name)
            for line in record(name).splitlines():
                if line.startswith('Provides :'):
                    capabilities.update(value.split('=')[0] for value in line.split(':', 1)[1].split() if value != 'None')
        missing = [name for name in args[2:] if name not in capabilities]
        if missing:
            print('\n'.join(missing))
            sys.exit(127)
    elif args[0] == '-Si':
        if args[1] in ('grimblast-git', 'mpvpaper') or args[1] in os.environ.get('PREFLIGHT_FAKE_MISSING', '').split(','):
            sys.exit(1)
        print(record(args[1]), end='')
    elif args[0] == '-Ql':
        print('linux-cachyos /usr/lib/modules/6.test/pkgbase')
    elif args[0] == '-Sp':
        if os.environ.get('PREFLIGHT_FAKE_PACKAGES'):
            for name in args[5:]:
                print(name, '1.0 cachyos-v4 100')
        else:
            print('docker 1.0 cachyos-v4 100')
    elif args[0] in ('-Qqe', '-Qq'):
        print('linux-cachyos')
    elif args[0] == '-Q':
        print(args[1], '0.56.2' if args[1] == 'hyprland' else '0.3.1')
    else:
        sys.exit(99)
elif command == 'curl':
    if 'aur.archlinux' in args[-1]:
        names = parse_qs(urlparse(args[-1]).query)['arg[]']
        print(json.dumps({'results': [{'Name': n, 'Version': '1.0'} for n in names]}))
elif command == 'uname':
    print('6.test' if args == ['-r'] else 'Linux')
elif command == 'busctl':
    if args[-1] != 'list':
        sys.exit(99)
    print('org.freedesktop.secrets 123 gnome-keyring user :1.2 - - -')
elif command == 'systemctl':
    if any(a in args for a in ('enable', 'disable', 'start', 'stop', 'restart', 'mask', 'unmask', 'daemon-reload')):
        sys.exit(99)
    if 'is-enabled' in args:
        on = args[-1] == 'sddm.service' and not os.environ.get('FAKE_NO_DM')
        print('enabled' if on else 'disabled')
        sys.exit(0 if on else 1)
    elif 'is-active' in args:
        print('inactive'); sys.exit(3)
    elif os.environ.get('FAKE_NO_DM'):
        print('Id=display-manager.service\nActiveState=inactive')
    else:
        print('Id=sddm.service\nActiveState=active')
elif command == 'timedatectl':
    print('yes')
elif command == 'lspci':
    if not os.environ.get('FAKE_NO_GPU'):
        print('VGA: AMD\n Kernel driver in use: amdgpu')
elif command == 'getent':
    print('user:x:1000:1000::/home/user:/usr/bin/zsh')
elif command == 'id':
    print('user wheel' if args == ['-nG'] else '1000')
elif command in ('sudo', 'paru', 'yay', 'chsh', 'hyprctl', 'hyprpm', 'qs', 'snapper', 'timeshift'):
    sys.exit(99)
elif command == 'gsettings':
    if not args or args[0] != 'get':
        sys.exit(99)
elif command != 'gum':
    sys.exit(99)
