"""Docker Engine over AF_UNIX; no Docker SDK or background state files.

Log levels: ERROR/FATAL/panic/Traceback/Exception -> error, WARN -> warn,
otherwise info (case insensitive). Follow emits updated counts with the same ts
for consecutive repeats, so a live consumer replaces its last row.
"""
import concurrent.futures
import http.client
import json
import os
import re
import signal
import socket
import struct
import sys
import time
from urllib.parse import quote, urlencode
from taller_common import Parser, ToolError, emit, error, safe
from secret_filter import redact


class UnixHTTP(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__('localhost', timeout=5)
        self.path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.path)


class Docker:
    def __init__(self):
        self.path = os.environ.get('DRAGON_DOCKER_SOCKET', '/var/run/docker.sock')
        self.version = ''

    def request(self, path, method='GET', stream=False, versioned=True):
        if versioned and not self.version:
            self.version = '/v' + self.request('/version', versioned=False)['ApiVersion']
        conn = UnixHTTP(self.path)
        handed_off = False
        try:
            conn.request(method, (self.version if versioned else '') + path)
            response = conn.getresponse()
            if response.status >= 400:
                message = response.read().decode(errors='replace')
                raise ToolError('docker_api', 'Docker: ' + redact(message)[0])
            if stream:
                # Streams can be idle indefinitely; SIGTERM interrupts blocking reads.
                conn.sock.settimeout(None) if conn.sock else None
                handed_off = True
                return conn, response
            raw = response.read()
            return json.loads(raw) if raw else {}
        except PermissionError:
            raise ToolError('docker_permission', 'Docker no disponible: permiso denegado.',
                            'añade tu usuario al grupo docker y vuelve a iniciar sesión') from None
        except (OSError, http.client.HTTPException, ValueError, KeyError):
            raise ToolError('docker_unavailable', 'Docker no disponible.',
                            'Comprueba el daemon y el socket de Docker.') from None
        finally:
            if not handed_off:
                conn.close()

    def containers(self):
        rows = self.request('/containers/json?all=1')
        def normalize(row):
            data = self.request('/containers/' + quote(row['Id'], safe='') + '/json')
            state, labels = data.get('State', {}), data.get('Config', {}).get('Labels') or {}
            return dict(id=row['Id'], name=data.get('Name', '').lstrip('/'),
                        project=labels.get('com.docker.compose.project', 'Sin proyecto'),
                        service=labels.get('com.docker.compose.service', ''),
                        image=data.get('Config', {}).get('Image', ''), state=state.get('Status', 'created'),
                        health=state.get('Health', {}).get('Status', 'none'),
                        exit_code=state.get('ExitCode', 0), oom_killed=state.get('OOMKilled', False),
                        restart_count=data.get('RestartCount', 0), started_at=state.get('StartedAt', ''),
                        created_at=data.get('Created', ''),
                        working_dir=labels.get('com.docker.compose.project.working_dir', ''),
                        ports=[str(p.get('PublicPort', '')) + '->' + str(p.get('PrivatePort', ''))
                               for p in row.get('Ports', []) if p.get('PublicPort')])
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            return sorted(pool.map(normalize, rows), key=lambda r: (r['project'], r['name']))

    def issues(self):
        rows = self.containers()
        now = int(time.time())
        conn, response = self.request('/events?' + urlencode(dict(since=now-600, until=now,
            filters=json.dumps({'type': ['container'], 'event': ['restart', 'start', 'oom']}))), stream=True)
        events = {}
        try:
            for line in response:
                e = json.loads(line)
                cid = e.get('Actor', {}).get('ID', e.get('id', ''))
                action = e.get('Action', e.get('status', ''))
                events.setdefault(cid, {}).setdefault(action, []).append(e.get('time', now))
        finally:
            conn.close()
        issues = []
        for c in rows:
            base = dict(container=c['id'], since=c['started_at'])
            recent = events.get(c['id'], {})
            oom = recent.get('oom', [])
            if c['oom_killed'] or oom:
                issues.append(dict(base, kind='oom', since=min(oom) if oom else c['started_at'], detail='OOMKilled · memoria agotada'))
            # Docker emits start/die for policy restarts; explicit restart also has
            # a start event. Count starts, excluding the initial creation, without
            # counting an explicit restart twice. No lifetime-counter heuristic.
            starts, explicit = recent.get('start', []), recent.get('restart', [])
            created = c.get('created_at', '')
            try:
                from datetime import datetime
                initial_in_window = datetime.fromisoformat(created.replace('Z','+00:00')).timestamp() >= now-600
            except ValueError:
                initial_in_window = True
            restart_count = max(len(explicit), max(0, len(starts)-int(initial_in_window)), c.get('restart_count', 0) if initial_in_window and created else 0)
            if restart_count >= 3:
                issues.append(dict(base, kind='restart_loop', since=min(starts+explicit),
                                   detail=f"Reiniciado {restart_count} veces en 10 min"))
            if c['health'] == 'unhealthy':
                issues.append(dict(base, kind='unhealthy', detail='Comprobación de salud fallida'))
            if c['exit_code'] and c['state'] in ('exited', 'dead', 'restarting'):
                issues.append(dict(base, kind='exit_nonzero', detail=f"Salida {c['exit_code']}"))
        return issues


def stats(data, previous=None):
    cpu, pre = data.get('cpu_stats', {}), data.get('precpu_stats', {})
    total, system_total = cpu.get('cpu_usage', {}).get('total_usage', 0), cpu.get('system_cpu_usage', 0)
    # one-shot=1 can omit precpu_stats. Prefer our preceding two-second sample.
    prior_total, prior_system = (previous[3], previous[4]) if previous else (pre.get('cpu_usage', {}).get('total_usage', 0), pre.get('system_cpu_usage', 0))
    delta, system = total-prior_total, system_total-prior_system
    cores = cpu.get('online_cpus') or len(cpu.get('cpu_usage', {}).get('percpu_usage', [])) or 1
    memory = data.get('memory_stats', {})
    cache = memory.get('stats', {}).get('inactive_file', memory.get('stats', {}).get('cache', 0))
    net = data.get('networks', {})
    rx, tx = sum(v.get('rx_bytes', 0) for v in net.values()), sum(v.get('tx_bytes', 0) for v in net.values())
    now = time.monotonic()
    elapsed = max(now - previous[0], .001) if previous else 1
    return dict(cpu_pct=max(0, delta / system * cores * 100) if system > 0 else 0,
                mem_bytes=max(0, memory.get('usage', 0)-cache), mem_limit=memory.get('limit', 0),
                net_rx_bps=max(0, (rx-previous[1])/elapsed) if previous else 0,
                net_tx_bps=max(0, (tx-previous[2])/elapsed) if previous else 0), (now, rx, tx, total, system_total)


ANSI = re.compile(r'\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))')


def log_line(line):
    line = ANSI.sub('', line).rstrip('\r\n')
    parts = line.split(' ', 1)
    ts, msg = parts if len(parts) == 2 and re.match(r'^\d{4}-\d\d-\d\dT', parts[0]) else ('', line)
    msg = redact(msg)[0]
    level = 'error' if re.search(r'ERROR|FATAL|panic|Traceback|Exception', msg, re.I) else 'warn' if re.search('WARN', msg, re.I) else 'info'
    return dict(ok=True, ts=ts, level=level, msg=msg, count=1)


def read_exact(response, n):
    result = b''
    while len(result) < n:
        chunk = response.read(n-len(result))
        if not chunk:
            break
        result += chunk
    return result


def logs(client, args):
    last = None
    pem = False
    delay = 1
    since = args.since
    while True:
        cursor = since if re.match(r'^\d{4}-\d\d-\d\dT', since) else ""
        try:
            conn, response = client.request('/containers/' + quote(args.id, safe='') + '/logs?' + urlencode(dict(
                stdout=1, stderr=1, timestamps=1, tail=args.tail, since=parse_since(since), follow=int(args.follow))), stream=True)
        except ToolError as exc:
            if not args.follow: raise
            emit(error(exc.code, exc.message, exc.hint))
            time.sleep(delay); delay = min(10, delay * 2)
            continue
        # Inspect tells us whether the stream is raw TTY or Docker's 8-byte multiplex frames.
        try:
            tty = client.request('/containers/' + quote(args.id, safe='') + '/json').get('Config', {}).get('Tty', False)
            buffers = {1: b'', 2: b''}
            def lines():
                if tty:
                    yield from response
                    return
                while True:
                    header = read_exact(response, 8)
                    if not header:
                        break
                    if len(header) != 8 or header[0] not in (0, 1, 2):
                        raise ToolError('docker_logs', 'Trama de logs inválida.')
                    length = struct.unpack('>I', header[4:])[0]
                    if length > 16 * 1024 * 1024:
                        raise ToolError('docker_logs', 'Trama de logs demasiado grande.')
                    data = read_exact(response, length)
                    key = header[0]
                    buffers.setdefault(key, b'')
                    buffers[key] += data
                    while b'\n' in buffers[key]:
                        line, buffers[key] = buffers[key].split(b'\n', 1)
                        yield line
                for buf in buffers.values():
                    if buf:
                        yield buf
            for raw in lines():
                decoded = raw.decode(errors='replace')
                if re.search(r'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----', decoded): pem = True
                item = log_line(decoded)
                if cursor and item['ts'] and item['ts'] <= cursor: continue
                if pem: item['msg'] = '[oculto:pem]'
                if re.search(r'-----END (?:[A-Z0-9]+ )*PRIVATE KEY-----', decoded): pem = False
                if item['ts']:
                    since = item['ts']
                if last and (last['msg'], last['level']) == (item['msg'], item['level']):
                    last['count'] += 1
                else:
                    if last and not args.follow and (args.level == 'all' or last['level'] == args.level):
                        emit(last)
                    last = item
                if args.follow and (args.level == 'all' or last['level'] == args.level):
                    emit(last)
            if not args.follow:
                if last and (args.level == 'all' or last['level'] == args.level):
                    emit(last)
                return
            delay = 1
        except (OSError, http.client.HTTPException, ToolError) as exc:
            if not args.follow: raise
            emit(error('docker_logs', 'Esperando reconexión de logs con Docker.'))
        finally:
            conn.close()
        time.sleep(delay)
        delay = min(10, delay * 2)


def parse_since(value):
    match = re.fullmatch(r'(\d+)([smhd])', value)
    return int(time.time()) - int(match[1]) * dict(s=1, m=60, h=3600, d=86400)[match[2]] if match else value


def inspect_safe(data):
    # Inspect may expose arbitrary environment names; mask ALL values, not just named secrets.
    data = safe(data)
    for cfg in ('Config', 'ContainerConfig'):
        if isinstance(data.get(cfg), dict):
            data[cfg]['Env'] = [entry.split('=', 1)[0] + '=[oculto:entorno]' for entry in data[cfg].get('Env') or []]
    return data


def main():
    parser = Parser(description='Contenedores Docker locales (JSON).')
    sub = parser.add_subparsers(dest='cmd', required=True)
    for name in ('ps', 'issues'):
        sub.add_parser(name).add_argument('--json', action='store_true')
    p = sub.add_parser('stats'); p.add_argument('--stream', action='store_true'); p.add_argument('--ids', nargs='+')
    p = sub.add_parser('logs'); p.add_argument('id'); p.add_argument('--tail', type=int, default=200); p.add_argument('--since', default='10m'); p.add_argument('--follow', action='store_true'); p.add_argument('--level', choices=['all', 'warn', 'error'], default='all')
    p = sub.add_parser('events'); p.add_argument('--follow', action='store_true')
    p = sub.add_parser('inspect'); p.add_argument('id'); p.add_argument('--json', action='store_true')
    p = sub.add_parser('action'); p.add_argument('id'); p.add_argument('action', choices=['start', 'stop', 'restart'])
    args = parser.parse_args()
    client = Docker()
    if args.cmd == 'ps': emit(dict(ok=True, containers=client.containers()))
    elif args.cmd == 'issues': emit(dict(ok=True, issues=client.issues()))
    elif args.cmd == 'inspect': emit(dict(ok=True, inspect=inspect_safe(client.request('/containers/' + quote(args.id, safe='') + '/json'))))
    elif args.cmd == 'action':
        client.request('/containers/' + quote(args.id, safe='') + '/' + args.action, method='POST'); emit(dict(ok=True))
    elif args.cmd == 'logs': logs(client, args)
    elif args.cmd == 'stats':
        previous, delay = {}, 1
        while True:
            start = time.monotonic()
            try:
                ids = args.ids or [c['id'] for c in client.containers() if c['state'] == 'running']
                def sample(cid):
                    return cid, client.request('/containers/' + quote(cid, safe='') + '/stats?stream=0&one-shot=1')
                with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
                    for cid, data in pool.map(sample, ids):
                        item, previous[cid] = stats(data, previous.get(cid))
                        emit(dict(ok=True, id=cid, **item))
                delay = 1
            except ToolError as exc:
                if not args.stream: raise
                emit(error(exc.code, exc.message, exc.hint)); time.sleep(delay); delay = min(10, delay*2)
            if not args.stream: return
            time.sleep(max(0, 2 - (time.monotonic()-start)))
    else:
        delay = 1
        since = int(time.time())
        while True:
            try:
                conn, response = client.request('/events?' + urlencode(dict(since=since, filters=json.dumps(
                    {'type': ['container'], 'event': ['die', 'oom', 'restart', 'health_status']}))), stream=True)
                try:
                    for line in response:
                        item = json.loads(line); since = item.get('time', since); emit(dict(ok=True, **item))
                        delay = 1
                        if not args.follow: return
                finally: conn.close()
            except (ToolError, OSError, http.client.HTTPException, ValueError) as exc:
                emit(error('docker_events', 'Esperando reconexión con Docker.'))
            if not args.follow: return
            time.sleep(delay); delay = min(10, delay*2)


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        main()
    except ToolError as exc:
        emit(error(exc.code, exc.message, exc.hint)); sys.exit(1)
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
