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


def record(name):
    version = {'hyprland': '0.56.2', 'quickshell': '0.3.1', 'neovim': '0.12.6'}.get(name, '1.0')
    return f'Name : {name}\nVersion : {version}\nRepository : cachyos-v4\nProvides : None\nConflicts With : None\nReplaces : None\nDepends On : None\nRequired By : None\n\n'


if command == 'pacman':
    if args[0] == '-Qi':
        print(record('linux-cachyos') + record('linux-cachyos-headers'), end='')
    elif args[0] == '-T':
        print('\n'.join(args[2:]))
        sys.exit(127)
    elif args[0] == '-Si':
        if args[1] in ('grimblast-git', 'mpvpaper') or args[1] in os.environ.get('PREFLIGHT_FAKE_MISSING', '').split(','):
            sys.exit(1)
        print(record(args[1]), end='')
    elif args[0] == '-Ql':
        print('linux-cachyos /usr/lib/modules/6.test/pkgbase')
    elif args[0] == '-Sp':
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
        print('enabled' if args[-1] == 'sddm.service' else 'disabled')
        sys.exit(0 if args[-1] == 'sddm.service' else 1)
    elif 'is-active' in args:
        print('inactive'); sys.exit(3)
    else:
        print('Id=sddm.service\nActiveState=active')
elif command == 'timedatectl':
    print('yes')
elif command == 'lspci':
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
