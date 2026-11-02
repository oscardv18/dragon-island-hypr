#!/usr/bin/env python3
"""Fail closed before publishing/deploying Neovim config. Print paths/types, never matched values."""
import argparse
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'dragon-core'))
from secret_filter import detections

PUBLIC_HOSTS = {'github.com', 'raw.githubusercontent.com', 'www.apache.org', 'apache.org',
                'lazyvim.org', 'www.lazyvim.org', 'lazy.folke.io', 'neovim.io'}
ROOT_FILES = {'init.lua', 'lazy-lock.json', 'lazyvim.json', '.neoconf.json', 'stylua.toml', 'LICENSE'}
CONFIG_DIRS = {'lua', 'after', 'ftplugin', 'snippets', 'spell'}


def audit(root, names=None):
    root = Path(root)
    paths = [root / name for name in names] if names else sorted(root.rglob('*'))
    errors, count = [], 0
    for path in paths:
        relative = path.relative_to(root)
        if path.is_symlink():
            errors.append((str(relative), 'symlink')); continue
        if path.is_dir():
            continue
        if not path.is_file():
            errors.append((str(relative), 'not_regular')); continue
        if relative.parts[0] not in CONFIG_DIRS and str(relative) not in ROOT_FILES:
            errors.append((str(relative), 'not_config')); continue
        try:
            text = path.read_text(encoding='utf-8')
        except (UnicodeError, OSError):
            errors.append((str(relative), 'unreadable_or_binary')); continue
        count += 1
        # Typed mode deliberately preserves public git hashes and plugin identifiers.
        for _, _, kind in detections(text, opaque=False):
            errors.append((str(relative), 'secret:' + kind))
        if re.search(r'/home/[^/\s"\x27]+|[A-Z]:\\Users\\', text):
            errors.append((str(relative), 'personal_path'))
        if re.search(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', text):
            errors.append((str(relative), 'personal_email'))
        for url in re.findall(r'https?://[^\s"\x27<>]+', text):
            try:
                host = urlsplit(url).hostname
            except ValueError:
                host = None
            if host not in PUBLIC_HOSTS:
                errors.append((str(relative), 'unreviewed_url'))
    return count, sorted(set(errors))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('paths', nargs='*')
    args = parser.parse_args()
    if not args.root.is_dir():
        parser.error('config root must be a directory')
    count, errors = audit(args.root, args.paths)
    for path, kind in errors:
        print(f'NVIM PUBLIC: {path}: {kind}', file=sys.stderr)
    if errors:
        return 1
    print(f'NVIM PUBLIC: {count} archivos revisados; sin credenciales ni destinos privados detectados.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
