"""Local app application: atomic files, bounded reloads and no resident process."""
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys

from palette import DRAGON, atomic_write, config_home, state_home
from palette_apps import render, update_starship


def warn(message, quiet=False):
    if not quiet:
        print(f"dragon-palette: aviso: {message}", file=sys.stderr)


def read_palette():
    data = json.loads((state_home() / 'palette.json').read_text())
    if (not isinstance(data, dict) or type(data.get('version')) is not int or data['version'] != 1
            or not isinstance(data.get('source'), str)
            or not re.fullmatch(r'[0-9a-f]{40}', str(data.get('sourceHash', '')))
            or type(data.get('fallback')) is not bool):
        raise ValueError('palette.json: metadatos de versión 1 inválidos')
    for key in DRAGON:
        colors = data.get(key) if key == 'swatches' else [data.get(key)]
        if not isinstance(colors, list) or len(colors) != (5 if key == 'swatches' else 1):
            raise ValueError(f'palette.json: {key} inválido')
        if any(not isinstance(c, str) or not re.fullmatch(r'#[0-9A-F]{6}', c) for c in colors):
            raise ValueError(f'palette.json: color inválido en {key}')
    return data


def write_changed(path, content, dry_run=False, backup=False):
    old = path.read_text() if path.exists() else None
    if old == content:
        return False
    if dry_run:
        return True
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    if backup and old is not None:
        digest = hashlib.sha256(old.encode()).hexdigest()
        target = state_home() / 'backups/palette' / f'{path.name}.{digest}'
        if not target.exists():
            atomic_write(target, old)
    atomic_write(path, content)
    path.chmod(mode)
    return True


@contextmanager
def application_lock(dry_run=False):
    if dry_run:
        yield
        return
    state_home().mkdir(parents=True, exist_ok=True)
    with (state_home() / 'palette.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def signal_app(name, sig, quiet=False):
    """Signal only this user's real binaries with an installed signal handler.

    Match the process's config root too: temporary HOME tests must never
    signal terminals belonging to the real desktop. Checking SigCgt avoids killing old app versions where USR1/USR2 still has
    its default (terminate) disposition. Never use pkill or touch child shells.
    """
    count = 0
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid() or Path(os.readlink(entry / 'exe')).name != name:
                continue
            environment = dict(part.split(b'=', 1) for part in (entry / 'environ').read_bytes().split(b'\0') if b'=' in part)
            process_home = os.fsdecode(environment.get(b'HOME', b''))
            process_config = os.fsdecode(environment.get(b'XDG_CONFIG_HOME', b'')) or str(Path(process_home) / '.config')
            if not process_home or Path(process_config) != config_home():
                continue
            status = dict(line.split(':', 1) for line in (entry / 'status').read_text().splitlines() if ':' in line)
            if not int(status['SigCgt'].strip(), 16) & (1 << (sig - 1)):
                warn(f'{name} PID {entry.name}: no admite la señal de recarga; se omite', quiet)
                continue
            os.kill(int(entry.name), sig)
            count += 1
        except (FileNotFoundError, ProcessLookupError):
            continue
        except (PermissionError, OSError, KeyError, ValueError) as error:
            warn(f'{name}: no se pudo recargar: {error}', quiet)
    return count


def reload_apps(directory, quiet=False):
    for name, sig in (('ghostty', signal.SIGUSR2), ('kitty', signal.SIGUSR1)):
        if not shutil.which(name):
            warn(f'{name} no está instalado; el archivo queda preparado', quiet)
            continue
        count = signal_app(name, sig, quiet)
        remote_ok = False
        if name == 'kitty' and count and os.environ.get('KITTY_LISTEN_ON'):
            try:
                result = subprocess.run([name, '@', '--to', os.environ['KITTY_LISTEN_ON'],
                                         'set-colors', '--all', '--configured',
                                         str(directory / 'dragon-dynamic.conf')],
                                        capture_output=True, timeout=2, check=False)
                remote_ok = result.returncode == 0
            except (OSError, subprocess.TimeoutExpired):
                pass
        if not count and not remote_ok:
            warn(f'{name}: no hay una instancia con recarga disponible', quiet)
    if not shutil.which('starship'):
        warn('Starship no está instalado; los colores quedan preparados', quiet)
    if not shutil.which('fastfetch'):
        warn('fastfetch no está instalado', quiet)
    # Starship and fastfetch read colors on their next invocation.
    warn('herdr: sin inclusión de colores externos; se conserva su configuración', quiet)


def apply_palette(data, dry_run=False, quiet=False, legacy=False):
    directory = config_home() / 'dragon-island/palette'
    applied = state_home() / 'palette.applied'
    digest = data['sourceHash']
    if applied.exists() and applied.read_text().strip() == digest:
        if not quiet:
            print('dragon-palette: la paleta ya está aplicada')
        return False
    for name, content in render(data, legacy=legacy).items():
        write_changed(directory / name, content, dry_run)
    starship = Path(os.environ.get('STARSHIP_CONFIG', str(config_home() / 'starship.toml'))).expanduser()
    try:
        if starship.exists():
            text = update_starship(starship.read_text(), render(data, legacy=legacy)['starship.toml'])
            write_changed(starship, text, dry_run, backup=True)
        else:
            warn('Starship: falta la configuración; ejecuta la migración 030', quiet)
    except (ValueError, OSError) as error:
        warn(str(error), quiet)
    if not dry_run:
        reload_apps(directory, quiet)
        write_changed(applied, digest + '\n')
    if not quiet:
        print(f"dragon-palette: {'[dry-run] ' if dry_run else ''}apps preparadas en {directory}")
    return True


def reset_palette(dry_run=False, quiet=False):
    # User decision: external apps return to their pre-phase-3 colors, while
    # Quickshell returns to its fixed Dragon palette when palette.json vanishes.
    apply_palette(dict(DRAGON, sourceHash='legacy-v1'), dry_run, quiet, legacy=True)
    if not dry_run:
        (state_home() / 'palette.json').unlink(missing_ok=True)
