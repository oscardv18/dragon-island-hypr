"""Read-only, machine-specific manual prerequisites shared by doctor and preflight."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

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
    return {'release': release, 'pkgbase': base, 'headers': base + '-headers' if base else None,
            'installed_releases': installed, 'reboot': bool(installed and release not in installed)}


def prerequisites():
    spec = json.loads((ROOT/'packages/profiles.json').read_text())['prereq']
    kernel = kernel_info()
    helper = next((name for name in ('paru', 'yay') if shutil.which(name)), None)
    preferred = spec['aur_helper'].get(distro().get('ID'), spec['aur_helper']['default'])
    packages = [line.split('#')[0].strip() for line in (ROOT/'packages'/spec['pacman_file']).read_text().splitlines()
                if line.split('#')[0].strip()]
    if kernel['headers'] and not kernel['reboot']:
        packages.append(kernel['headers'])
    helper_repo = False
    if not helper:
        helper_repo = run('pacman', '-Si', preferred)[0] == 0
        if helper_repo:
            packages.append(preferred)
    return {'packages': packages, 'kernel': kernel, 'helper': helper or preferred,
            'helper_present': bool(helper), 'helper_repo': helper_repo}


def main():
    data = prerequisites()
    print('Lista EXACTA de prerrequisitos manuales para esta máquina (no los instala el instalador):')
    print('sudo pacman -S --needed ' + ' '.join(data['packages']))
    k = data['kernel']
    if k['reboot']:
        print(f"AVISO: kernel en uso {k['release']} distinto del instalado ({', '.join(k['installed_releases'])}).")
        print('Reinicia ANTES de instalar cabeceras y vuelve a ejecutar ./doctor.sh --pre.')
    elif not k['headers']:
        print(f"AVISO: no se puede leer /usr/lib/modules/{k['release']}/pkgbase; no se adivinan las cabeceras.")
        print('Comprueba el kernel instalado, reinicia y repite ./doctor.sh --pre.')
    else:
        print(f"Cabeceras del kernel en uso: {k['headers']} (pkgbase: {k['pkgbase']}).")
    if data['helper_present']:
        print(f"Ayudante AUR existente: {data['helper']} (se conserva).")
    elif not data['helper_repo']:
        print(f"Instala a mano {data['helper']} desde AUR antes de continuar; no existe en tus repositorios pacman.")
    return int(k['reboot'] or not k['headers'])


if __name__ == '__main__':
    raise SystemExit(main())
