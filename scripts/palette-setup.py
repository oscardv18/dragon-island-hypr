#!/usr/bin/env python3
"""Plan/apply migration 030 edits. --backups prints changed targets as NUL paths.

The Bash caller uses backup_copy before --apply. No network, reload or Pillow.
Symlinked config directories are detached before writing so the repo stays clean.
"""
import argparse
import os
from pathlib import Path
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'dragon-core'))
from palette import DRAGON, atomic_write, config_home, state_home
from palette_apps import render, convert_starship


def plan():
    cfg = config_home()
    directory = cfg / 'dragon-island/palette'
    writes, links, detaches = {}, {}, set()
    # Generation alone never opts the user into external app colors. Preserve
    # the applied palette, including when a newer JSON is waiting for apply.
    colors = DRAGON
    marker = state_home() / 'palette.applied'
    digest = marker.read_text().strip() if marker.exists() else ''
    data = None
    if (state_home() / 'palette.json').exists():
        from palette_runtime import read_palette
        data = read_palette()
        if digest == data['sourceHash']:
            colors = data
    legacy = digest == 'legacy-v1'
    outputs = render(colors, legacy=legacy)
    if digest and not legacy and (data is None or digest != data['sourceHash']):
        outputs = {name: (directory / name).read_text() if (directory / name).exists() else text
                   for name, text in outputs.items()}
    for name, text in outputs.items():
        writes[directory / name] = text
    ghostty = cfg / 'ghostty'
    main = ghostty / ('config.ghostty' if (ghostty / 'config.ghostty').exists() else 'config')
    includes = {
        main: 'config-file = ' + str(directory / 'ghostty.conf'),
        cfg / 'kitty/kitty.conf': 'include ' + str(directory / 'dragon-dynamic.conf'),
    }
    for path, line in includes.items():
        old = path.read_text() if path.exists() else ''
        if line not in old.splitlines():
            writes[path] = old + ('' if not old or old.endswith('\n') else '\n') + line + '\n'
    links[ghostty / 'themes/dragon-dynamic'] = directory / 'dragon-dynamic'
    starship = Path(os.environ.get('STARSHIP_CONFIG', str(cfg / 'starship.toml'))).expanduser()
    if starship.exists():
        writes[starship] = convert_starship(starship.read_text(), outputs['starship.toml'])
    # Remove byte-identical operations before requesting backups.
    writes = {p: t for p, t in writes.items() if not p.exists() or p.read_text() != t}
    links = {p: t for p, t in links.items() if not p.is_symlink() or p.readlink() != t}
    for path in list(writes) + list(links):
        # Keep all unrelated files when detaching a symlinked directory.
        for parent in path.parents:
            if parent == cfg:
                break
            if parent.is_symlink():
                detaches.add(parent)
    # Detach outermost directories once; nested symlinks are handled after it.
    return writes, links, sorted(detaches, key=lambda p: len(p.parts))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backups', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    writes, links, detaches = plan()
    paths = list(dict.fromkeys(detaches + list(writes) + list(links)))
    if args.backups:
        # Back up edited files by their lexical user path. Backing up a parent
        # directory symlink first would make backup_copy follow it when copying
        # a child, potentially reaching the repository through the backup.
        for path in list(writes) + list(links):
            if path.exists() or path.is_symlink():
                sys.stdout.buffer.write(os.fsencode(path) + b'\0')
        return
    if args.dry_run:
        for path in paths:
            print(f'[dry-run] configurar paleta: {path}')
        return
    for directory in detaches:
        with tempfile.TemporaryDirectory(prefix='.palette-', dir=directory.parent) as temporary:
            clone = Path(temporary) / 'config'
            shutil.copytree(directory.resolve(), clone, symlinks=True)
            directory.unlink()
            os.replace(clone, directory)
    for path, text in writes.items():
        atomic_write(path, text)
    for path, target in links.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists() or path.is_symlink():
            path.unlink()
        path.symlink_to(target)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(f'palette-setup: {error}', file=sys.stderr)
        sys.exit(1)
