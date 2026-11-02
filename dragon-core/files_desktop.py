"""Desktop integration without opening folders via xdg-open (avoids recursion)."""
import json
import os
from pathlib import Path
import shutil
import subprocess
from urllib.parse import unquote, urlsplit
from taller_common import ToolError

DESKTOP = 'dragon-files.desktop'


def execute(argv):
    if not shutil.which(argv[0]):
        raise ToolError('missing_tool', f'Falta {argv[0]}.', 'Instala xdg-utils y comprueba Quickshell.')
    result = subprocess.run(argv, capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise ToolError('desktop_error','La integración con el escritorio no respondió.',
                        'Comprueba que Quickshell está activo y tiene el servicio files.')
    return result.stdout.strip()


def folder_for(raw, show_item=False):
    if raw.startswith('file:'):
        uri = urlsplit(raw)
        if uri.netloc not in ('','localhost') or uri.query or uri.fragment:
            raise ToolError('invalid_uri','Se esperaba una dirección local file:///.')
        raw = unquote(uri.path)
    elif '://' in raw:
        raise ToolError('unsupported_uri','Conecta primero el servidor desde la vista Red.')
    path = Path(raw).expanduser().absolute()
    if not path.exists():
        raise ToolError('not_found','La ruta solicitada ya no existe.')
    return path.parent if show_item or not path.is_dir() else path


def browse(paths, show_items=False):
    folders = list(dict.fromkeys(str(folder_for(p, show_items)) for p in (paths or [str(Path.home())])))
    for path in folders:
        execute(['qs','ipc','call','files','open',path])
    return dict(opened=folders)


def state_path():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'dragon-island/files/default.json'


def default(restore=False):
    path = state_path()
    if restore:
        try:
            data = json.loads(path.read_text())
            previous = data['previous']
        except (OSError,ValueError,KeyError):
            raise ToolError('no_previous_default','No hay un gestor anterior guardado.') from None
        if not previous or previous == DESKTOP or not previous.endswith('.desktop') or '/' in previous or '\n' in previous:
            raise ToolError('no_previous_default','No había asociación anterior explícita.',
                            'Selecciona un gestor con xdg-mime default org.kde.dolphin.desktop inode/directory.')
        execute(['xdg-mime','default',previous,'inode/directory'])
        return dict(default=previous,restored=True)
    previous = execute(['xdg-mime','query','default','inode/directory'])
    if previous == DESKTOP:
        return dict(default=DESKTOP)
    if previous and (not previous.endswith('.desktop') or '/' in previous or '\n' in previous):
        raise ToolError('invalid_default','La asociación anterior no tiene un identificador de escritorio válido.')
    path.parent.mkdir(parents=True,exist_ok=True)
    # O_EXCL preserves the original association across repeat installs.
    try:
        fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w') as f: json.dump(dict(previous=previous),f)
    except FileExistsError: pass
    execute(['xdg-mime','default',DESKTOP,'inode/directory'])
    return dict(default=DESKTOP,previous=previous)
