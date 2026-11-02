#!/usr/bin/env python3
"""Configure only the public launch flags, never Claude data or keyring files."""
import argparse
import os
from pathlib import Path
import re


def plan():
    path = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'claude-desktop-flags.conf'
    old = path.read_text() if path.exists() else ''
    lines = []
    for line in old.splitlines():
        flags, sep, comment = line.partition('#')
        flags = re.sub(r'(?<!\S)--password-store(?:=\S+|\s+\S+)', '', flags).rstrip()
        if flags or sep:
            lines.append(flags + ((' #' if flags else '#') + comment if sep else ''))
    return path, old, '\n'.join(lines + ['--password-store=gnome-libsecret']) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backups', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    path, old, new = plan()
    if old != new:
        if args.backups:
            if path.exists():
                print(path)
        elif args.dry_run:
            print(f'[dry-run] {path}: --password-store=gnome-libsecret')
        else:
            import sys
            sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'dragon-core'))
            from palette import atomic_write
            atomic_write(path, new)
