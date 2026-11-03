"""Read-only installer inspection. JSON schema 1 is the I3 presentation contract.

No mkdir, log, cache, package refresh, sudo authentication, snapshot or service
activation. All external probes are bounded. A failed probe stays visible.
"""
import argparse
from functools import lru_cache
import json
import os
from pathlib import Path
import re
import shutil
import sys
from urllib.parse import urlencode

from installer_prereq import distro, kernel_info, run, system_path
from installer_profiles import load_profiles


def records(text):
    """Parse LC_ALL=C pacman paragraphs, including wrapped relationships."""
    result, item, key = [], {}, None
    for line in text.splitlines() + ['']:
        if not line.strip():
            if item:
                result.append(item)
                item, key = {}, None
        elif line[:1].isspace() and key:
            item[key] += ' ' + line.strip()
        elif ':' in line:
            key, value = line.split(':', 1)
            key = key.strip()
            item[key] = value.strip()
    return result


def words(value):
    return [] if not value or value == 'None' else value.split()


def package(record, source='pacman'):
    return {'name': record.get('Name', ''), 'version': record.get('Version', ''),
            'repository': record.get('Repository', 'installed'), 'source': source,
            'conflicts': words(record.get('Conflicts With')), 'replaces': words(record.get('Replaces')),
            'provides': words(record.get('Provides')), 'depends': words(record.get('Depends On')),
            'required_by': words(record.get('Required By'))}


def relation(value):
    match = re.fullmatch(r'([^<>=\s]+)(>=|<=|=|>|<)?(.*)', value)
    return match.groups() if match else ('', None, '')


@lru_cache(maxsize=None)
def compare(left, right):
    rc, out, _ = run('vercmp', left, right)
    if rc or out not in ('-1', '0', '1'):
        raise ValueError(f'No se pudo comparar versiones {left} / {right}; hace falta vercmp (pacman).')
    return int(out)


def satisfies(expression, candidate):
    name, operator, version = relation(expression)
    identities = [(candidate['name'], candidate['version'])]
    identities += [(n, v if op == '=' else '') for n, op, v in map(relation, candidate['provides'])]
    for identity, provided in identities:
        if identity != name:
            continue
        if not operator:
            return True
        if provided:
            value = compare(provided, version)
            if {'=': value == 0, '>': value > 0, '<': value < 0,
                '>=': value >= 0, '<=': value <= 0}[operator]:
                return True
    return False


class Inspector:
    def __init__(self, profiles, packages):
        self.profiles = profiles
        self.requested = packages
        self.checks = []
        self.planned = []
        self.installed = []
        self.deptested = set()

    def add(self, code, level, message, evidence='', remedy=''):
        self.checks.append({'id': code, 'level': level, 'message': message,
                            'evidence': evidence, 'remedy': remedy})

    def probe(self, code, args, message, failure='aviso', remedy=''):
        rc, out, err = run(*args)
        self.add(code, 'informacion' if rc == 0 else failure, message, out or err, remedy if rc else '')
        return rc, out

    def machine(self):
        os_info = distro()
        supported = os_info.get('ID') in ('arch', 'endeavouros', 'cachyos') or 'arch' in os_info.get('ID_LIKE', '').split()
        self.add('distro', 'informacion' if supported else 'bloqueante',
                 'Distribución y versión.', json.dumps(os_info, ensure_ascii=False), 'Usa Arch o una derivada compatible.' if not supported else '')
        k = kernel_info()
        self.add('kernel', 'aviso' if not k['headers'] or k['reboot'] else 'informacion',
                 'Kernel en uso y cabeceras derivadas de pkgbase.', json.dumps(k),
                 'Reinicia y repite doctor.sh --pre antes de instalar cabeceras.' if k['reboot'] else '')
        dkms = [p['name'] for p in self.installed if p['name'] == 'dkms' or p['name'].endswith('-dkms')]
        headers = next((p for p in self.installed if p['name'] == k['headers']), None)
        kernel_package = next((p for p in self.installed if p['name'] == k['pkgbase']), None)
        mismatch = bool(headers and kernel_package and headers['version'] != kernel_package['version'])
        level = 'bloqueante' if dkms and (not headers or mismatch or k['reboot']) else 'aviso' if not headers or mismatch else 'informacion'
        self.add('headers', level, 'Cabeceras del kernel; obligatorias con DKMS.',
                 json.dumps({'headers': k['headers'], 'installed': bool(headers), 'version_mismatch': mismatch, 'dkms': dkms}),
                 'Ejecuta doctor.sh --pre; instala sus prerrequisitos manuales tras reiniciar si lo pide.' if level != 'informacion' else '')
        self.add('root', 'bloqueante' if os.geteuid() == 0 else 'informacion', 'El instalador debe ejecutarse como usuario.', str(os.geteuid()))
        for path in sorted(set(('/', str(Path.home())))):
            try:
                free = shutil.disk_usage(path).free
                self.add('disk:' + path, 'bloqueante' if free < 5 * 1024**3 else 'informacion',
                         'Espacio libre; mínimo conservador de 5 GiB, no es una estimación de descarga.', f'{path}: {free} bytes')
            except OSError as exc:
                self.add('disk:' + path, 'bloqueante', 'No se pudo consultar el espacio.', str(exc))
        self.probe('network', ('curl', '-fsS', '--max-time', '6', '-o', '/dev/null', 'https://archlinux.org'),
                   'Red HTTPS hacia archlinux.org.', 'bloqueante', 'Comprueba conexión, DNS y certificados.')
        rc, out, err = run('timedatectl', 'show', '-p', 'NTPSynchronized', '--value')
        self.add('clock', 'informacion' if rc == 0 and out == 'yes' else 'aviso',
                 'Reloj sincronizado (necesario para TLS y firmas).', out or err, 'Comprueba NTP antes de instalar.' if out != 'yes' else '')
        rc, groups, err = run('id', '-nG')
        allowed = shutil.which('sudo') and rc == 0 and set(groups.split()).intersection(('wheel', 'sudo'))
        self.add('sudo', 'informacion' if allowed else 'aviso',
                 'Disponibilidad de sudo y grupo administrativo; no autentica ni modifica credenciales.',
                 groups or err, 'Los permisos sudo efectivos y la autenticación se validarán al aplicar (I3).')
        rc, out, err = run('lspci', '-k')
        self.add('gpu', 'informacion' if rc == 0 and 'Kernel driver in use:' in out else 'aviso',
                 'GPU y módulos del kernel (no instala drivers).', out or err,
                 'Comprueba el driver en uso y DKMS antes de instalar.')
        rc, out, err = run('systemctl', 'show', 'display-manager.service', '-p', 'Id', '-p', 'ActiveState', '-p', 'FragmentPath')
        self.add('display-manager', 'informacion' if rc == 0 and 'ActiveState=active' in out else 'aviso',
                 'Gestor de acceso activo; no se cambia.', out or err,
                 'Comprueba el gestor de acceso antes de iniciar la sesión Hyprland.' if 'ActiveState=active' not in out else '')
        managers = []
        for name in ('sddm', 'gdm', 'lightdm', 'greetd', 'plasmalogin'):
            if run('systemctl', 'is-enabled', name + '.service')[1] in ('enabled', 'enabled-runtime', 'linked', 'linked-runtime', 'alias'):
                managers.append(name)
        self.add('display-managers', 'bloqueante' if len(managers) > 1 else 'informacion',
                 'Dos gestores de acceso habilitados competirían al arrancar.', ', '.join(managers) or 'ninguno detectado',
                 'Elige manualmente uno; este chequeo no deshabilita servicios.' if len(managers) > 1 else '')
        sockets = []
        socket_paths = {}
        for scope in ((), ('--user',)):
            for unit in ('docker.socket', 'podman.socket'):
                enabled = run('systemctl', *scope, 'is-enabled', unit)[1]
                active = run('systemctl', *scope, 'is-active', unit)[1]
                if enabled in ('enabled', 'enabled-runtime') or active == 'active':
                    socket_id = ('user:' if scope else 'system:') + unit
                    sockets.append(socket_id)
                    _, listen, _ = run('systemctl', *scope, 'show', unit, '-p', 'Listen', '--value')
                    for path in re.findall(r'(/\S+) \(Stream\)', listen):
                        normalized = path.replace('/var/run/', '/run/', 1)
                        socket_paths.setdefault(normalized, []).append(socket_id)
        podman_compat = any(p['name'] == 'podman-docker' for p in self.installed)
        docker_planned = any(p['name'] == 'docker' for p in self.requested)
        shared = {path: units for path, units in socket_paths.items() if len(units) > 1}
        collision = (podman_compat and docker_planned) or bool(shared)
        dual = any('docker.socket' in s for s in sockets) and any('podman.socket' in s for s in sockets)
        self.add('container-sockets', 'bloqueante' if collision else 'aviso' if dual else 'informacion',
                 'Docker/Podman: podman-docker usa la interfaz Docker; dos sockets requieren revisar sus rutas.',
                 json.dumps({'sockets': sockets, 'shared_paths': shared, 'podman-docker': podman_compat, 'DOCKER_HOST': os.environ.get('DOCKER_HOST', '')}),
                 'Revisa ListenStream y DOCKER_HOST; conserva un solo dueño del socket compartido.' if collision or dual else '')
        tools = [t for t in ('snapper', 'timeshift') if shutil.which(t)]
        if tools:
            for tool in tools:
                self.probe('snapshot:' + tool, (tool, '--list') if tool == 'timeshift' else (tool, 'list-configs'),
                           'Configuración de instantáneas; hay que crear una previa al aplicar (I4).')
                if tool == 'snapper':
                    self.probe('snapshot-existing', ('snapper', 'list'), 'Instantáneas existentes; ninguna se crea durante --check.')
        self.add('snapshot-plan', 'aviso' if tools else 'informacion',
                 'Solo lectura: no se crea instantánea ni archivo de paquetes.', ', '.join(tools) or 'snapper/timeshift no detectados',
                 'I4 debe crear la instantánea previa y guardar pacman -Qqe antes de aplicar.')
        self.probe('explicit-packages', ('pacman', '-Qqe'), 'Lista de paquetes explícitos para el respaldo previo; todavía sin guardar.', 'bloqueante')

    def desktops(self):
        names = [p['name'] for p in self.installed]
        for name in names:
            if name in ('cachyos-hypr-noctalia', 'cachyos-hyprland-settings') or name.startswith('noctalia'):
                self.add('desktop:' + name, 'bloqueante', f'{name} escribe configuración Hyprland/Quickshell que compite con Dragon.',
                         name, 'Respalda y resuelve su configuración/UWSM antes de continuar; se recomienda CachyOS sin escritorio.')
            elif name.startswith('plasma-') or name == 'gnome-shell':
                self.add('desktop:' + name, 'aviso', f'{name}: escritorio existente; se mantiene como sesión separada.',
                         name, 'Revisa autoinicio y portales por sesión; no se desinstala ni enmascara Plasma.')
        rc, out, err = run('busctl', '--user', '--no-pager', '--full', 'list')
        owner = '\n'.join(line for line in out.splitlines() if line.split() and line.split()[0] == 'org.freedesktop.secrets')
        # An activatable service has no PID/owner yet. Listing never activates it.
        active_owner = bool(owner and len(owner.split()) > 1 and owner.split()[1].isdigit())
        kwallet = [name for name in names if name.startswith('kwallet')]
        self.add('kwallet', 'aviso' if kwallet else 'informacion', 'Presencia de KWallet; Plasma lo puede conservar.', ' '.join(kwallet) or 'no detectado',
                 'Solo un Secret Service debe arrancar en Hyprland; no se elimina KWallet de Plasma.' if kwallet else '')
        gnome_selected = any(p['name'] == 'gnome-keyring' for p in self.requested)
        conflict = gnome_selected and active_owner and 'gnome-keyring' not in owner
        self.add('secrets-owner', 'bloqueante' if conflict else 'aviso' if rc or not active_owner else 'informacion',
                 'Dueño actual de org.freedesktop.secrets en el bus de usuario.', owner or err or 'sin dueño activo',
                 'Ejecuta dentro de tu sesión para verificar el dueño; resuelve el autoinicio antes de habilitar GNOME Keyring.' if rc or not active_owner or conflict else '')
        rc, passwd, _ = run('getent', 'passwd', str(os.getuid()))
        shell = passwd.split(':')[-1] if rc == 0 else os.environ.get('SHELL', 'desconocido')
        self.add('login-shell', 'aviso' if shell.endswith('/fish') else 'informacion',
                 'Shell de login; Dragon usa zsh, chsh requiere confirmación explícita.', shell)
        for name in names:
            if name in ('cachyos-hello', 'cachyos-kernel-manager', 'cachyos-packageinstaller', 'cachyos-wallpapers', 'firefox', 'vlc-plugins-all') or name.startswith('firefox-i18n-'):
                self.add('leftover:' + name, 'aviso', 'Paquete opcional de CachyOS; no se elimina automáticamente.', name,
                         'Puedes desmarcarlo en una instalación limpia; revisa dependencias antes de retirarlo.')
        requested = {p['name'] for p in self.requested}
        manifest = json.loads((Path(__file__).resolve().parents[1]/'packages/profiles.json').read_text())
        _, all_packages = load_profiles(list(manifest['profiles']))
        excluded = {p['name'] for p in all_packages} - requested
        for p in self.installed:
            if p['required_by'] and p['name'] in excluded:
                self.add('retained:' + p['name'], 'informacion', 'Fuera de los perfiles elegidos, pero otro paquete lo necesita: se conserva.',
                         p['name'] + ': requerido por ' + ', '.join(p['required_by']))

    def metadata(self):
        aur = []
        for request in self.requested:
            rc, out, err = run('pacman', '-Si', request['name'])
            parsed = records(out)
            if rc == 0 and parsed:
                p = package(parsed[0])
                p['profiles'] = request['profiles']
                self.planned.append(p)
                self.add('package:' + request['name'], 'informacion', 'Paquete disponible en los repositorios configurados (prioridad efectiva de pacman).', out)
            elif request['source'] == 'aur':
                aur.append(request)
            else:
                self.add('package:' + request['name'], 'bloqueante', 'Paquete oficial no disponible; no se adivina otro nombre ni se refrescan bases.', out or err,
                         'Revisa el nombre y tus repositorios; actualiza el sistema manualmente y repite --check.')
        if aur:
            query = urlencode([('v', '5'), ('type', 'info')] + [('arg[]', p['name']) for p in aur])
            rc, out, err = run('curl', '-fsS', '--max-time', '12', 'https://aur.archlinux.org/rpc/?' + query)
            try:
                response = json.loads(out) if rc == 0 else {}
                found = {p['Name']: p for p in response.get('results', [])}
            except (ValueError, KeyError, TypeError):
                found = {}
            for request in aur:
                record = found.get(request['name'])
                if not record:
                    self.add('package:' + request['name'], 'bloqueante', 'Paquete AUR ausente o RPC inaccesible.', err or out,
                             'Comprueba AUR y repite; no se descargan ni ejecutan PKGBUILD.')
                    continue
                p = {'name': record['Name'], 'version': record['Version'], 'repository': 'AUR', 'source': 'aur',
                     'conflicts': record.get('Conflicts', []), 'replaces': record.get('Replaces', []),
                     'provides': record.get('Provides', []), 'depends': record.get('Depends', []),
                     'build_depends': record.get('MakeDepends', []) + record.get('CheckDepends', []),
                     'profiles': request['profiles']}
                self.planned.append(p)
                self.add('package:' + p['name'], 'informacion', 'Metadatos AUR RPC; no se compila ni ejecuta código.', json.dumps(p))
        self.installed_providers()
        self.plan_providers()
        official = [p['name'] for p in self.planned
                    if p['source'] == 'pacman' and p.get('state') != 'satisfied']
        if official:
            rc, out, err = run('pacman', '-Sp', '--needed', '--noconfirm', '--print-format', '%n %v %r %s', *official)
            self.add('transaction', 'bloqueante' if rc else 'informacion',
                     'Resolución pacman -Sp --needed (sin instalar); conflictos comprobados además por metadatos.', out + ('\n' + err if err else ''),
                     'Resuelve el error del plan antes de aplicar.' if rc else '')
            planned_names = {p['name'] for p in self.planned}
            for line in out.splitlines() if rc == 0 else []:
                fields = line.split()
                if len(fields) == 4 and fields[0] not in planned_names:
                    dep_rc, dep_out, dep_err = run('pacman', '-Si', fields[0])
                    parsed = records(dep_out)
                    if dep_rc == 0 and parsed:
                        dependency = package(parsed[0]); dependency['profiles'] = ['dependency']
                        self.planned.append(dependency); planned_names.add(dependency['name'])
                        self.add('dependency:' + dependency['name'], 'aviso', 'La resolución amplía el plan con una dependencia.', dep_out)
                    else:
                        self.add('dependency:' + fields[0], 'bloqueante', 'No se pudieron comprobar los metadatos de una dependencia.', dep_err)
        self.installed_providers()
        pool = self.installed + [p for p in self.planned if p.get('state') != 'satisfied']
        for p in self.planned:
            if p['source'] == 'aur':
                missing = [dep for dep in p['depends'] + p.get('build_depends', []) if not any(satisfies(dep, other) for other in pool)]
                self.add('aur-build:' + p['name'], 'aviso', 'AUR requiere compilación; dependencias aún fuera del plan pueden aumentar tamaño y tiempo.',
                         json.dumps({'package': p['name'], 'unresolved_dependencies': missing}),
                         'Revisa PKGBUILD, dependencias y duración antes de confirmar (I3); RPC no sustituye una revisión del código.')
        for name, minimum in (('hyprland', '0.56'), ('quickshell', '0.3'), ('neovim', '0.12')):
            candidate = next((p for p in self.planned if p['name'] == name), None)
            if candidate:
                self.add('version:' + name, 'bloqueante' if compare(candidate['version'], minimum) < 0 else 'informacion',
                         f'{name} necesita versión ≥ {minimum}.', candidate['version'])
        hypr = next((p for p in self.planned if p['name'] == 'hyprland'), None)
        if hypr and any(p['name'] == 'hyprpm' for p in self.planned):
            self.add('hyprland-plugins', 'aviso', 'Los plugins necesitan el ABI exacto de Hyprland, no basta la versión de hyprpm.',
                     hypr['version'], 'Verifica la revisión compatible y compila en la sesión Hyprland; --check no ejecuta hyprpm.')

    def installed_providers(self):
        """pacman -T is authoritative; metadata only identifies the provider."""
        pending = [p for p in self.planned if p['name'] not in self.deptested]
        if not pending:
            return
        names = {p['name'] for p in pending}
        rc, out, err = run('pacman', '-T', '--', *sorted(names))
        missing = set(out.splitlines())
        self.deptested.update(names)
        if rc not in (0, 127) or not missing.issubset(names) or (rc == 127 and not missing) or (rc == 0 and missing):
            self.add('deptest', 'bloqueante',
                     'No se pudo comprobar si los paquetes están satisfechos.', out or err)
            return
        for p in pending:
            if p['name'] in missing or any(i['name'] == p['name'] for i in self.installed):
                continue
            providers = sorted((i for i in self.installed if satisfies(p['name'], i)),
                               key=lambda i: i['name'])
            if not providers:
                self.add('deptest:' + p['name'], 'bloqueante',
                         'pacman -T indica satisfacción sin proveedor identificable; repite el chequeo.', out or err)
                continue
            provider = providers[0]
            p.update(state='satisfied', provider=provider['name'],
                     provider_origin='installed', installed_version=provider['version'])
            self.add('satisfied:' + p['name'], 'informacion',
                     f"{p['name']}: ya satisfecho (lo provee {provider['name']}).",
                     'pacman -T -- ' + p['name'] + ': salida 0; se conserva el proveedor instalado.')

    def plan_providers(self):
        """Choose explicit provider roots from the complete plan, never insertion order.

        Mutual providers and ambiguous alternatives remain active: their real
        conflicts still block instead of silently choosing an arbitrary package.
        """
        active = [p for p in self.planned if p.get('state') != 'satisfied']
        roots = [p for p in active if not any(
            other['name'] != p['name'] and satisfies(p['name'], other) for other in active)]
        for p in active:
            candidates = [other for other in roots
                          if other['name'] != p['name'] and satisfies(p['name'], other)]
            if len(candidates) != 1:
                continue
            provider = candidates[0]
            p.update(state='satisfied', provider=provider['name'],
                     provider_origin='plan', installed_version=None)
            provider['required_profiles'] = sorted(set(provider.get('required_profiles', [])) | set(p['profiles']))
            self.add('satisfied:' + p['name'], 'informacion',
                     f"{p['name']}: satisfecho por el proveedor explícito {provider['name']} del plan.",
                     'Se instalará el proveedor; se omite el paquete redundante.')

    def conflicts(self):
        reported = set()
        active = [p for p in self.planned if p.get('state') != 'satisfied']
        planned_names = {p['name'] for p in active}
        for p in active:
            for other, context in [(other, 'plan') for other in active] + [(other, 'installed') for other in self.installed if other['name'] not in planned_names]:
                if other['name'] == p['name']:
                    continue
                for field in ('conflicts', 'replaces'):
                    matches = [r for r in p[field] if satisfies(r, other)]
                    if field == 'conflicts':
                        matches += [r for r in other[field] if satisfies(r, p)]
                    if not matches:
                        continue
                    key = (field, context, *sorted((p['name'], other['name'])))
                    if key in reported:
                        continue
                    reported.add(key)
                    self.add(':'.join(key), 'bloqueante' if field == 'conflicts' else 'aviso',
                             'Conflicts With: selección incompatible.' if field == 'conflicts' else 'Replaces: la transacción podría sustituir un paquete.',
                             f"{p['name']} / {other['name']} ({context}): {', '.join(matches)}",
                             'Resuelve la selección antes de aplicar; no se retira ni sustituye nada automáticamente.')
                overlaps = {relation(r)[0] for r in p['provides']} & {relation(r)[0] for r in other['provides']}
                if overlaps and context == 'plan' and p['name'] < other['name']:
                    self.add(f"provides:{p['name']}:{other['name']}", 'aviso', 'Dos paquetes del plan proporcionan la misma capacidad.', ', '.join(sorted(overlaps)))
            installed = next((i for i in self.installed if i['name'] == p['name']), None)
            p['installed_version'] = installed['version'] if installed else None
            p['state'] = 'installed' if installed and installed['version'] == p['version'] else 'change' if installed else 'install'

    def inspect(self):
        rc, out, err = run('pacman', '-Qi')
        self.installed = [package(r) for r in records(out)]
        self.add('installed-metadata', 'bloqueante' if rc else 'informacion',
                 'Consulta de paquetes instalados y dependencias inversas.', err if rc else f'{len(self.installed)} paquetes')
        self.machine()
        self.desktops()
        try:
            self.metadata()
            self.conflicts()
        except ValueError as exc:
            self.add('metadata-comparison', 'bloqueante', 'No se pudo completar la comparación de relaciones/versiones.', str(exc))
        blocked = any(c['level'] == 'bloqueante' for c in self.checks)
        return {'schema': 1, 'read_only': True, 'profiles': self.profiles,
                'packages': self.planned, 'checks': self.checks, 'blocked': blocked}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profiles', help='Perfiles separados por comas; por defecto los del manifiesto.')
    parser.add_argument('--modules', help='Selección de módulos, incluye core; traduce a perfiles sin aplicar.')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    try:
        if args.profiles and args.modules:
            raise ValueError('Usa --profiles o --modules, no ambos.')
        if args.modules:
            allowed = {'core', 'shell', 'editor', 'theme', 'plugins', 'login', 'keyring', 'keyboard', 'boot', 'extras', 'taller', 'archivos'}
            unknown = set(args.modules.split(',')) - allowed
            if unknown:
                raise ValueError('Módulos desconocidos: ' + ', '.join(sorted(unknown)))
        profiles, packages = load_profiles(args.profiles.split(',') if args.profiles else None,
                                            args.modules.split(',') if args.modules else None)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    result = Inspector(profiles, packages).inspect()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print('Preflight SOLO LECTURA · perfiles: ' + ', '.join(profiles))
        for check in result['checks']:
            print(f"[{check['level']}] {check['id']}: {check['message']}")
            if check['evidence']:
                print(check['evidence'])
            if check['remedy']:
                print('Salida: ' + check['remedy'])
        print('BLOQUEADO: resuelve los bloqueos y repite --check.' if result['blocked'] else 'Sin bloqueos detectados; revisa los avisos antes de aplicar.')
    return int(result['blocked'])


if __name__ == '__main__':
    sys.exit(main())
