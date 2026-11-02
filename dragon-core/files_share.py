"""Samba usershares: user-owned subdirectories, no configuration or firewall writes."""
import configparser
import os
from pathlib import Path
import pwd
import re
from taller_common import ToolError
from files_network import run


def allowed_path(raw):
    home = Path.home().resolve()
    path = Path(raw).expanduser().resolve(strict=True)
    sensitive = [home / x for x in ('.ssh','.gnupg','.config','.local/share/keyrings',
                                    '.local/share/dragon-island','.local/state/dragon-island')]
    if (path == home or home not in path.parents or not path.is_dir()
            or path.stat().st_uid != os.getuid()
            or any(p == path or p in path.parents or path in p.parents for p in sensitive)):
        raise ToolError('forbidden_path','Solo puedes compartir carpetas propias no sensibles dentro de tu HOME.',
                        'No se admite HOME entero, rutas de sistema, SSH, GnuPG, configuración ni llaveros.')
    # Hidden folders hold configuration and secrets the fixed list cannot enumerate (~/.password-store, ~/.mozilla,
    # ~/.aws, ~/.kube, ~/.var…): no component below HOME may be hidden (audit 5d).
    if any(part.startswith('.') for part in path.relative_to(home).parts):
        raise ToolError('forbidden_path','No se comparten carpetas ocultas ni lo que hay dentro de ellas.',
                        'Las carpetas que empiezan por punto guardan configuración y credenciales.')
    # Every component must belong to this user; do not publish another user's tree through a symlink.
    if any(p.stat().st_uid != os.getuid() for p in [path, *list(path.parents)[:len(path.parts)-len(home.parts)]]):
        raise ToolError('forbidden_path','La carpeta no pertenece al usuario de esta sesión.')
    if any(ord(c) < 32 or 127 <= ord(c) < 160 for c in str(path)):
        raise ToolError('forbidden_path','La ruta contiene caracteres de control.')
    return path


def share_name(name):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 _.-]{0,79}', name or '') or name.endswith(('.', ' ')):
        raise ToolError('invalid_name','Usa un nombre de recurso de hasta 80 caracteres sin barras ni controles.')
    return name


def inventory():
    result = run(['net','usershare','info','--long'],check=False)
    if result.returncode:
        raise ToolError('samba_not_ready','Samba usershare todavía no está preparado.',
                        'Sigue docs/FILES-SAMBA.md; esta herramienta no ejecuta sudo.')
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read_string(result.stdout)
    except configparser.Error:
        raise ToolError('samba_error','La respuesta de Samba no es válida.') from None
    rows = []
    host = os.uname().nodename
    for name in parser.sections():
        section = parser[name]
        path = section.get('path','')
        rows.append(dict(shared=True,path=path,name=name,
                         rw=any(x in section.get('usershare_acl','').upper() for x in (':F',':FULL',':CHANGE')),
                         guest=section.get('guest_ok','n').lower() in ('yes','y','true'),host=host,
                         addresses=dict(smb=f'smb://{host}/{name}',unc=f'\\\\{host}\\{name}')))
    return rows


def command(args, api):
    path = allowed_path(args.path) if args.path else None
    if args.action != 'status' and not path:
        raise ToolError('invalid_usage','Indica la carpeta con --path.')
    if args.name: share_name(args.name)
    rows = inventory()
    matches = [r for r in rows if path and Path(r['path']).resolve() == path]
    if args.action == 'status':
        if not path: return dict(shares=rows)
        return matches[0] if matches else dict(shared=False,path=str(path),guest=False)
    if args.action == 'disable':
        for row in matches:
            if not args.name or args.name == row['name']:
                run(['net','usershare','delete',row['name']])
        return dict(shared=False,path=str(path),guest=False)
    name = share_name(args.name)
    if any(row['name'].casefold() == name.casefold() and Path(row['path']).resolve() != path for row in rows):
        raise ToolError('share_exists','Ese nombre ya pertenece a otra carpeta.')
    user = pwd.getpwuid(os.getuid()).pw_name
    guest = bool(args.guest)
    # Guests require the explicit --guest request; default ACL grants only this user.
    acl = f'{user}:{"F" if args.rw else "R"}'
    if guest: acl += f',Everyone:{"F" if args.rw else "R"}'
    run(['net','usershare','add',name,str(path),'Compartido desde Archivos',acl,
         'guest_ok=y' if guest else 'guest_ok=n'])
    host = os.uname().nodename
    return dict(shared=True,path=str(path),name=name,rw=args.rw,guest=guest,host=host,
                addresses=dict(smb=f'smb://{host}/{name}',unc=f'\\\\{host}\\{name}'),
                firewall=dict(needed=None,command='sudo ufw allow from <SUBRED_LOCAL/CIDR> to any app Samba',
                              message='Si el cortafuegos bloquea Samba, sustituye la subred por tu LAN. No se ejecutó ningún cambio.'))


def configure(sub):
    p = sub.add_parser('share')
    p.add_argument('action',choices=('status','enable','disable'))
    p.add_argument('--path')
    p.add_argument('--name',default='')
    p.add_argument('--rw',action='store_true')
    p.add_argument('--guest',action='store_true')
    p.add_argument('--json',action='store_true')
