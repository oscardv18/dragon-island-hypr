#!/usr/bin/env python3
"""Package manifest reader for the linear installer: prints the packages of the profiles that a module selection needs.

  manifest.py --source pacman|aur --modules core,shell,... [--profiles base,keyring,...]

Output: one package name per line, no duplicates, in manifest order. Read-only; it never calls pacman."""
import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
# profiles whose packages the installer installs itself in the package phases (login/boot/mis-apps have their own modules)
ENGINE_PROFILES = ['base', 'keyring', 'taller', 'archivos', 'editor', 'login']


def names(path):
    out = []
    if not path.exists():
        return out
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith(('#', '@')):
            continue
        out.append(line.split()[0])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', choices=('pacman', 'aur', 'profiles'), required=True)
    ap.add_argument('--modules', default='')
    ap.add_argument('--profiles', default=','.join(ENGINE_PROFILES))
    args = ap.parse_args()
    manifest = json.loads((ROOT / 'packages' / 'profiles.json').read_text())
    profiles = manifest['profiles']
    chosen = set(filter(None, args.modules.split(',')))
    wanted = [p for p in args.profiles.split(',') if p in profiles and (not chosen or chosen & set(profiles[p].get('modules', [])))]
    if args.source == 'profiles':
        print(','.join(wanted))
        return 0
    files = []
    if args.source == 'pacman':
        # the common prerequisites (git, base-devel, curl…) travel with the base profile
        if 'base' in wanted:
            files.append(manifest['prereq']['pacman_file'])
    for profile in wanted:
        files += profiles[profile].get(args.source, [])
    seen, result = set(), []
    for f in files:
        for n in names(ROOT / 'packages' / f):
            if n not in seen:
                seen.add(n); result.append(n)
    print('\n'.join(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
