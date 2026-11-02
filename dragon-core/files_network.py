"""Network adapter. Secrets only enter child stdin; bookmarks contain public URIs.

All commands are argv arrays, with bounded capture and generic errors so helpers
cannot echo a password into JSON. Discovery/mount commands run only on request.
"""
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import time
from urllib.parse import quote, unquote, urlsplit, urlunsplit
from taller_common import ToolError

SCHEMES = {'smb', 'sftp', 'nfs', 'ftp', 'dav', 'davs'}
SERVICES = {'_smb._tcp':'smb', '_sftp-ssh._tcp':'sftp', '_ssh._tcp':'sftp',
            '_nfs._tcp':'nfs', '_ipp._tcp':'ipp'}


def run(argv, *, input=None, timeout=20, check=True):
    if not shutil.which(argv[0]):
        raise ToolError('missing_tool', f'Falta {argv[0]}.', 'Instala la herramienta opcional indicada en §5.7.')
    try:
        result = subprocess.run(argv, input=input, text=True, capture_output=True,
                                timeout=timeout, env=dict(os.environ, LC_ALL='C'))
    except subprocess.TimeoutExpired:
        raise ToolError('timeout', 'El servicio no respondió a tiempo.') from None
    if check and result.returncode:
        raise ToolError('network_error', 'La operación de red no pudo completarse.',
                        'Comprueba el servidor, GVFS y los permisos de la sesión.')
    return result


def clean_text(text):
    return bool(text) and not any(ord(c) < 32 or 127 <= ord(c) < 160 for c in text)


def uri_parts(uri, user=None):
    if not clean_text(uri):
        raise ToolError('invalid_uri', 'La dirección contiene caracteres de control.')
    try:
        parsed = urlsplit(uri)
        if (parsed.scheme not in SCHEMES or not parsed.hostname or parsed.password is not None
                or parsed.query or parsed.fragment or not clean_text(unquote(uri))):
            raise ValueError()
        parsed.port
        if parsed.username is not None and ':' in unquote(parsed.username):
            raise ValueError()
        if user is not None:
            if not clean_text(user) or ':' in user:
                raise ValueError()
            hostname = ('[' + parsed.hostname + ']') if ':' in parsed.hostname else parsed.hostname
            netloc = quote(user, safe='') + '@' + hostname + (':' + str(parsed.port) if parsed.port else '')
            parsed = parsed._replace(netloc=netloc)
    except ValueError:
        raise ToolError('invalid_uri', 'Usa SMB, SFTP, NFS, FTP o WebDAV sin contraseña en la dirección.') from None
    return parsed


def public_server(uri, name='', user=None):
    parsed = uri_parts(uri, user)
    return dict(uri=urlunsplit(parsed), name=name or parsed.hostname,
                protocol=parsed.scheme, user=unquote(parsed.username or ''))


def saved_path():
    return Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'dragon-island/files/servers.json'


def saved():
    try:
        data = json.loads(saved_path().read_text())
        return [public_server(row['uri'], row.get('name','')) for row in data if isinstance(row, dict)]
    except (OSError, ValueError, KeyError, ToolError):
        return []


def save_servers(rows):
    import tempfile
    path = saved_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.servers-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(rows, f, ensure_ascii=False)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)


def avahi_unescape(value):
    return re.sub(r'\\(\d{3})', lambda m: chr(int(m[1])), value)


def discover():
    # -p escapes delimiters; only resolved (=) records contain address/port.
    result = run(['avahi-browse', '-artp'], timeout=15)
    hosts = {}
    for line in result.stdout.splitlines():
        parts = line.split(';')
        if len(parts) < 9 or parts[0] != '=' or parts[4] not in SERVICES:
            continue
        _, interface, family, name, service, domain, host, address, port, *_ = parts
        try:
            port = int(port)
        except ValueError:
            continue
        if not 0 < port <= 65535 or not clean_text(address):
            continue
        protocol = SERVICES[service]
        hostname = '[' + address + ']' if ':' in address else address
        uri = f'{protocol}://{hostname}:{port}/'
        hosts[(address,protocol,port)] = dict(name=avahi_unescape(name), address=address,
                                             protocol=protocol, uri=uri, port=port,
                                             kind='printer' if protocol == 'ipp' else 'server')
    return dict(hosts=list(hosts.values()))


def mounts():
    result = run(['gio','mount','-li'])
    rows = []
    current = None
    for line in result.stdout.splitlines():
        match = re.search(r'Mount\(\d+\):\s*(.*?)\s*->\s*(\S+)', line)
        if match:
            try:
                row = public_server(match[2], match[1])
            except ToolError:
                current = None
                continue
            parsed = uri_parts(row['uri'])
            row.update(host=parsed.hostname, address=parsed.hostname, path=None, free=None, total=None, version=None)
            rows.append(row)
            current = row
        elif current and line.strip().startswith('default_location='):
            location = line.strip().split('=',1)[1]
            if location.startswith('file://'):
                current['path'] = unquote(urlsplit(location).path)
    for row in rows:
        if not row['path']:
            info = run(['gio', 'info', '-a', 'standard::type', row['uri']], check=False)
            match = re.search(r'^local path:\s*(.+)$', info.stdout, re.M)
            if match: row['path'] = match[1]
        if row['path']:
            try:
                usage = shutil.disk_usage(row['path'])
                row['free'], row['total'] = usage.free, usage.total
            except OSError: pass
    return dict(mounts=rows)


def mount_dialog(uri, user, password, api, timeout=30):
    """Answer gio's C-locale prompts incrementally; never echo the captured stream."""
    if not shutil.which('gio'):
        raise ToolError('missing_tool', 'Falta gio.', 'Instala glib2 y los backends GVFS correspondientes.')
    proc = subprocess.Popen(['gio','mount',uri], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, env=dict(os.environ,LC_ALL='C'), start_new_session=True)
    api._CLEANUP_PROCS.add(proc)
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    output = bytearray()
    pending = ''
    deadline = time.monotonic() + timeout
    password_sent = False
    try:
        while True:
            if time.monotonic() >= deadline:
                raise ToolError('timeout', 'La conexión no respondió a tiempo.')
            for key, _ in selector.select(.1):
                block = os.read(key.fileobj.fileno(), 4096)
                if not block:
                    selector.unregister(key.fileobj)
                    continue
                output.extend(block)
                if len(output) > 128 * 1024:
                    raise ToolError('network_error', 'Respuesta excesiva del servicio.')
                pending += block.decode(errors='replace')
                if re.search(r'Password\s*:\s*$', pending, re.I):
                    if password is None:
                        raise ToolError('auth_required', 'El servidor requiere una contraseña por stdin.')
                    if password_sent:
                        raise ToolError('bad_password', 'El servidor rechazó la contraseña.')
                    answer = password
                    password_sent = True
                elif re.search(r'User(?:name)?\s*(\[[^\]]*\])?\s*:\s*$', pending, re.I):
                    answer = user or ''
                elif re.search(r'Domain\s*(\[[^\]]*\])?\s*:\s*$', pending, re.I):
                    answer = ''
                elif re.search(r'\(yes/no[^)]*\)\s*\??\s*$', pending, re.I):
                    raise ToolError('host_verification', 'Verifica primero la identidad del servidor en una terminal.')
                else:
                    continue
                proc.stdin.write((answer + '\n').encode()); proc.stdin.flush()
                pending = ''
            if proc.poll() is not None and not selector.get_map():
                break
        low = output.decode(errors='replace').lower()
        if proc.returncode and 'already mounted' not in low:
            if any(x in low for x in ('permission denied','authentication','password','not authorized')):
                raise ToolError('bad_password' if password is not None else 'auth_required',
                                'El servidor requiere credenciales válidas.')
            raise ToolError('network_error', 'No se pudo conectar al servidor.',
                            'Comprueba la dirección y el backend GVFS; no se aceptan automáticamente claves SSH.')
    finally:
        selector.close()
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=2)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait()
        proc.stdin.close(); proc.stdout.close()
        api._CLEANUP_PROCS.discard(proc)


def command(args, api):
    if args.action == 'discover':
        return discover()
    if args.action == 'mounts':
        return mounts()
    if args.action == 'saved':
        return dict(servers=saved())
    if args.action == 'shares':
        if not re.fullmatch(r'[A-Za-z0-9_.:\[\]-]+',args.host) or args.host.startswith('-'):
            raise ToolError('invalid_host','Nombre de servidor no válido.')
        result = run(['smbclient','-L',args.host,'-g','-N'])
        shares = []
        for line in result.stdout.splitlines():
            parts = line.split('|')
            if len(parts) >= 3 and parts[0] == 'Disk':
                shares.append(dict(name=parts[1],comment=parts[2]))
        return dict(shares=shares)
    server = public_server(args.uri, getattr(args,'name',''),getattr(args,'user',None))
    uri, user = server['uri'], server['user']
    if args.action in ('save','forget'):
        rows = [r for r in saved() if r['uri'] != uri]
        if args.action == 'save': rows.append(server)
        save_servers(rows)
        return dict(servers=rows)
    if args.action == 'unmount':
        run(['gio','mount','-u',uri])
        return dict(uri=uri)
    password = api.sys.stdin.readline().rstrip('\r\n') if args.password_stdin else None
    if args.save and not shutil.which('secret-tool'):
        raise ToolError('missing_tool', 'Falta secret-tool para guardar credenciales en el llavero.', 'Instala libsecret.')
    if password is None and shutil.which('secret-tool'):
        result = run(['secret-tool','lookup','service','dragon-files','uri',uri,'user',user], check=False)
        if result.returncode == 0:
            password = result.stdout.rstrip('\r\n') or None
    mount_dialog(uri, user, password, api)
    if args.save:
        if password is not None:
            run(['secret-tool','store','--label=Servidor de Archivos','service','dragon-files',
                 'uri',uri,'user',user], input=password)
        rows = [r for r in saved() if r['uri'] != uri]; rows.append(server); save_servers(rows)
    # A GVFS URI is usable by gio even when the optional FUSE daemon is absent.
    mountpoint = None
    for row in mounts()['mounts']:
        if row['uri'].rstrip('/') == uri.rstrip('/') and row.get('path'):
            mountpoint = row['path']
    if not mountpoint:
        info = run(['gio', 'info', '-a', 'standard::type', uri], check=False)
        match = re.search(r'^local path:\s*(.+)$', info.stdout, re.M)
        if match: mountpoint = match[1]
    if not mountpoint:
        raise ToolError('missing_fuse', 'Conectado, pero GVFS no expone una ruta local.',
                        'Instala gvfs y gvfs-fuse; vuelve a conectar desde la sesión de escritorio.')
    return dict(uri=uri,mountpoint=mountpoint)


def configure(sub):
    p = sub.add_parser('net')
    actions = p.add_subparsers(dest='action',required=True)
    for action in ('discover','mounts','saved','shares','connect','unmount','save','forget'):
        p = actions.add_parser(action)
        p.add_argument('--json',action='store_true')
        if action == 'shares': p.add_argument('host')
        if action in ('connect','unmount','save','forget'): p.add_argument('uri')
        if action == 'save': p.add_argument('--name',default='')
        if action == 'connect':
            p.add_argument('--user',default=None)
            p.add_argument('--password-stdin',action='store_true')
            p.add_argument('--save',action='store_true')
