"""Read the package manifest without state, caches or duplicate package requests."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_profiles(names=None, modules=None):
    profiles = json.loads((ROOT / 'packages/profiles.json').read_text())['profiles']
    if names is None:
        if modules is None:
            names = [name for name, spec in profiles.items() if spec['default']]
        else:
            selected = set(modules) | {'core'}
            names = [name for name, spec in profiles.items()
                     if selected.intersection(spec['modules']) and name != 'mis-apps']
    unknown = set(names) - profiles.keys()
    if unknown:
        raise ValueError('Perfiles desconocidos: ' + ', '.join(sorted(unknown)))
    packages = {}
    for name in names:
        for source in ('pacman', 'aur'):
            for file in profiles[name].get(source, []):
                for line in (ROOT / 'packages' / file).read_text().splitlines():
                    package = line.split('#')[0].strip()
                    if not package:
                        continue
                    item = packages.setdefault(package, {'name': package, 'source': source, 'profiles': []})
                    if name not in item['profiles']:
                        item['profiles'].append(name)
    return list(names), list(packages.values())


def package_table():
    """One row per package, retaining all owning profiles."""
    _, packages = load_profiles(list(json.loads((ROOT / 'packages/profiles.json').read_text())['profiles']))
    print('| Paquete | Módulo | Origen |')
    print('|---|---|---|')
    for item in packages:
        print(f"| `{item['name']}` | {', '.join(item['profiles'])} | {'oficial' if item['source'] == 'pacman' else 'AUR'} |")
    print('| `herdr` | taller (opt-in) | instalador oficial, confirmación pendiente en I3/I4 |')
    print('| `hyprfocus`, `hyprglass` | plugins | hyprpm |')
    print('| `zsh-autosuggestions`, `zsh-syntax-highlighting`, `fzf-tab` | shell | git clone |')


if __name__ == '__main__':
    package_table()
