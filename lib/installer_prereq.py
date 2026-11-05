"""Read-only, machine-specific manual prerequisites shared by doctor and preflight."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=20,
                                env={**os.environ, 'LC_ALL': 'C', 'PYTHONDONTWRITEBYTECODE': '1'})
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, '', str(exc)


def system_path(path):
    # A fixture root only redirects filesystem reads, never writes.
    return Path(os.environ.get('DRAGON_PREFLIGHT_ROOT', '/')) / path.lstrip('/')


def distro():
    try:
        return dict(line.split('=', 1) for line in system_path('/etc/os-release').read_text().replace('"', '').splitlines()
                    if '=' in line and not line.startswith('#'))
    except OSError:
        return {}


def kernel_info():
    _, release, _ = run('uname', '-r')
    try:
        base = system_path(f'/usr/lib/modules/{release}/pkgbase').read_text().strip()
    except OSError:
        base = ''
    if not re.fullmatch(r'[a-zA-Z0-9@._+-]+', base):
        base = ''
    installed = []
    if base:
        rc, files, _ = run('pacman', '-Ql', base)
        if rc == 0:
            installed = sorted(set(re.findall(r'/usr/lib/modules/([^/\s]+)/pkgbase', files)))
    reboot = bool(installed and release not in installed)
    if not reboot and not base:
        # An update removes the modules directory of the kernel that is still running: no pkgbase can be read,
        # but the directories that remain are the installed kernels. Running one that is not there = reboot pending.
        try:
            present = sorted(entry.name for entry in system_path('/usr/lib/modules').iterdir() if entry.is_dir())
        except OSError:
            present = []
        if present and release not in present:
            reboot, installed = True, present
    return {'release': release, 'pkgbase': base, 'headers': base + '-headers' if base else None,
            'installed_releases': installed, 'reboot': reboot}


def missing(names):
    """Packages of `names` that pacman -T says are still needed (providers count as satisfied)."""
    if not names:
        return []
    rc, out, _ = run('pacman', '-T', '--', *names)
    if rc == 0:
        return []
    return [line for line in out.splitlines() if line in names]


def prerequisites():
    spec = json.loads((ROOT/'packages/profiles.json').read_text())['prereq']
    kernel = kernel_info()
    helper = next((name for name in os.environ.get('DRAGON_AUR_HELPERS', 'paru yay').split() if shutil.which(name)), None)
    preferred = spec['aur_helper'].get(distro().get('ID'), spec['aur_helper']['default'])
    base = [line.split('#')[0].strip() for line in (ROOT/'packages'/spec['pacman_file']).read_text().splitlines()
            if line.split('#')[0].strip()]
    packages = list(base)
    if kernel['headers'] and not kernel['reboot']:
        packages.append(kernel['headers'])
    helper_repo = False
    if not helper:
        helper_repo = run('pacman', '-Si', preferred)[0] == 0
        if helper_repo:
            packages.append(preferred)
    helper_action = 'present' if helper else 'repo' if helper_repo else 'aur'
    return {'packages': packages, 'kernel': kernel, 'helper': helper or preferred,
            'helper_present': bool(helper), 'helper_repo': helper_repo, 'helper_action': helper_action,
            'helper_aur_build': spec.get('aur_build', {}).get(preferred, preferred),
            'base': base,
            # what the installer installs BEFORE the system update finishes (never kernel headers: they wait for the reboot check)
            'missing_base': missing(base + ([preferred] if helper_repo else [])),
            'headers_missing': bool(kernel['headers'] and not kernel['reboot'] and missing([kernel['headers']]))}


def main():
    args = sys.argv[1:]
    data = prerequisites()
    k = data['kernel']
    if args[:1] == ['--query']:
        # machine-readable answers for install.sh (one value per line, no decoration)
        query = args[1] if len(args) > 1 else ''
        if query == 'missing-base':
            print(' '.join(data['missing_base']))
        elif query == 'reboot':
            print('yes' if k['reboot'] else 'no')
        elif query == 'headers':
            print(k['headers'] or '')
        elif query == 'headers-missing':
            print('yes' if data['headers_missing'] else 'no')
        elif query == 'helper-action':
            print(data['helper_action'])
        elif query == 'helper':
            print(data['helper'])
        elif query == 'helper-aur-build':
            print(data['helper_aur_build'])
        elif query == 'kernel':
            print(f"{k['release']} (instalado: {', '.join(k['installed_releases']) or '?'})")
        else:
            print('consulta desconocida: ' + query, file=sys.stderr)
            return 2
        return 0
    print('Prerrequisitos de esta máquina (el instalador los instala por ti tras una confirmación):')
    print('sudo pacman -S --needed ' + ' '.join(data['packages']))
    if data['missing_base']:
        print('Faltan ahora: ' + ' '.join(data['missing_base']))
    if k['reboot']:
        print(f"AVISO: kernel en uso {k['release']} distinto del instalado ({', '.join(k['installed_releases'])}).")
        print('Reinicia y vuelve a ejecutar ./install.sh: las cabeceras se instalan después, nunca para un kernel que ya no está.')
    elif not k['headers']:
        print(f"AVISO: no se puede leer /usr/lib/modules/{k['release']}/pkgbase; no se adivinan las cabeceras.")
        print('Comprueba el kernel instalado, reinicia y repite ./doctor.sh --pre.')
    else:
        print(f"Cabeceras del kernel en uso: {k['headers']} (pkgbase: {k['pkgbase']}).")
    if data['helper_present']:
        print(f"Ayudante AUR existente: {data['helper']} (se conserva).")
    elif data['helper_repo']:
        print(f"Sin ayudante AUR: se instalará {data['helper']} desde tus repositorios.")
    else:
        print(f"Sin ayudante AUR y {data['helper']} no está en tus repositorios: el instalador lo construye desde AUR ({data['helper_aur_build']}).")
    return int(k['reboot'] or not k['headers'])


if __name__ == '__main__':
    raise SystemExit(main())
