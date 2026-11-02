#!/usr/bin/env python3
"""Override only Telegram's launcher; never inspect its account data."""
import argparse
import os
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'dragon-core'))
from palette import atomic_write


def plan():
    data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))
    target = data / 'applications/org.telegram.desktop.desktop'
    source = target if target.exists() else Path('/usr/share/applications/org.telegram.desktop.desktop')
    if not source.exists():
        return None
    text = source.read_text()
    sections = re.split(r'(?m)(?=^\[)', text)
    runner = str(Path.home() / '.local/bin/dragon-telegram')
    # Desktop Exec strings have their own escaping, independent of a shell.
    runner = runner.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
    for i, section in enumerate(sections):
        if not section.startswith('[Desktop Entry]\n'):
            continue
        for key, value in [('Exec', '"' + runner + '" -- %U'), ('DBusActivatable', 'false')]:
            pattern = re.compile(r'(?m)^' + key + r'=.*$')
            if pattern.search(section):
                section = pattern.sub(lambda _: key + '=' + value, section)
            else:
                section = section.rstrip('\n') + '\n' + key + '=' + value + '\n'
        sections[i] = section
    new = ''.join(sections)
    return target, new


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backups', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    result = plan()
    if result:
        target, new = result
        if not target.exists() or target.read_text() != new:
            if args.backups:
                if target.exists():
                    sys.stdout.buffer.write(os.fsencode(target) + b'\0')
            elif args.dry_run:
                print(f'[dry-run] Telegram por portal Qt: {target}')
            else:
                atomic_write(target, new)
