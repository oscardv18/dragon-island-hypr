#!/usr/bin/env python3
"""Plan GTK dark settings and palette imports, preserving unrelated user settings."""
import argparse
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'dragon-core'))
from palette import DRAGON, atomic_write, config_home, state_home
from palette_apps import render

BEGIN = '/* >>> dragon-palette */'
END = '/* <<< dragon-palette */'


def plan():
    cfg = config_home()
    colors = DRAGON
    marker = state_home() / 'palette.applied'
    if marker.exists() and (state_home() / 'palette.json').exists() and marker.read_text().strip() != 'legacy-v1':
        from palette_runtime import read_palette
        data = read_palette()
        if marker.read_text().strip() == data['sourceHash']:
            colors = data
    palette = cfg / 'dragon-island/palette/gtk.css'
    # Preserve an already applied CSS if generation has advanced since apply.
    writes = {palette: palette.read_text() if palette.exists() else render(colors)['gtk.css']}
    for version in (3, 4):
        settings = cfg / f'gtk-{version}.0/settings.ini'
        old = settings.read_text() if settings.exists() else ''
        lines = old.splitlines()
        if '[Settings]' not in lines:
            lines += ['[Settings]']
        start = lines.index('[Settings]') + 1
        end = next((i for i in range(start, len(lines)) if lines[i].startswith('[')), len(lines))
        section = lines[start:end]
        for key, value in [('gtk-theme-name', 'adw-gtk3-dark'), ('gtk-application-prefer-dark-theme', 'true')]:
            pattern = re.compile(r'\s*' + re.escape(key) + r'\s*=')
            matches = [i for i, line in enumerate(section) if pattern.match(line)]
            if len(matches) == 1 and section[matches[0]].strip() == key + '=' + value:
                continue
            if matches:
                first = matches[0]
                section = [key + '=' + value if i == first else line
                           for i, line in enumerate(section) if i == first or i not in matches]
            else:
                section.append(key + '=' + value)
        writes[settings] = '\n'.join(lines[:start] + section + lines[end:]) + '\n'
        css = cfg / f'gtk-{version}.0/gtk.css'
        old = css.read_text() if css.exists() else ''
        if old.count(BEGIN) != old.count(END) or old.count(BEGIN) > 1:
            raise ValueError(f'{css}: bloque de paleta inválido')
        block = BEGIN + '\n@import url("' + palette.as_uri() + '");\n' + END
        old = re.sub(re.escape(BEGIN) + r'.*?' + re.escape(END) + r'\n?', '', old, flags=re.S)
        # GTK accepts top-level imports here; load after KDE's colors.css and
        # named-color definitions so the palette governs the chooser.
        new = old.rstrip('\n') + ('\n' if old else '') + block + '\n'
        writes[css] = new
    return {p: text for p, text in writes.items() if not p.exists() or p.read_text() != text}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backups', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    writes = plan()
    if args.backups:
        for path in writes:
            if path.exists() or path.is_symlink():
                sys.stdout.buffer.write(os.fsencode(path) + b'\0')
        return
    if args.dry_run:
        for path in writes:
            print(f'[dry-run] GTK oscuro: {path}')
        return
    # Detach linked directories, never edit repository files through them.
    parents = sorted({p for path in writes for p in path.parents
                      if p != config_home() and p.is_relative_to(config_home()) and p.is_symlink()},
                     key=lambda p: len(p.parts))
    for parent in parents:
        if not parent.is_symlink():
            continue
        with tempfile.TemporaryDirectory(dir=parent.parent) as temporary:
            clone = Path(temporary) / 'config'
            shutil.copytree(parent.resolve(), clone, symlinks=True)
            parent.unlink()
            os.replace(clone, parent)
    for path, content in writes.items():
        atomic_write(path, content)


if __name__ == '__main__':
    main()
