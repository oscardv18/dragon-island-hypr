"""Recorded Engine-shaped replies, served only over a temporary Unix socket."""
import http.server
import json
import socketserver
import struct
import threading
from urllib.parse import urlsplit

CID = 'a' * 64
INSPECT = {'Id': CID, 'Name': '/demo-api', 'Config': {'Image': 'demo:latest', 'Tty': False,
    'Env': ['PLAIN=value', 'API_TOKEN=ghp_abcdefghijk'], 'Labels': {
    'com.docker.compose.project': 'demo', 'com.docker.compose.service': 'api',
    'com.docker.compose.project.working_dir': '/tmp/demo'}},
    'State': {'Status': 'restarting', 'ExitCode': 137, 'OOMKilled': True,
              'StartedAt': '2026-11-01T00:00:00Z', 'Health': {'Status': 'unhealthy'}}, 'RestartCount': 6}

class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True

class FakeDocker:
    def __init__(self, path):
        self.requests = []
        self.log_records = None
        self.tty = False
        self.stopped = False
        outer = self
        class Handler(http.server.BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.0'
            def log_message(self, *_): pass
            def do_POST(self):
                outer.requests.append(self.path)
                if self.path.endswith('/stop'): outer.stopped = True
                self.send_response(204); self.end_headers()
            def do_GET(self):
                outer.requests.append(self.path)
                path = urlsplit(self.path).path.removeprefix('/v1.47')
                data = {}
                if path == '/version': data = {'ApiVersion': '1.47'}
                elif path == '/containers/json': data = [{'Id': CID, 'Ports': [{'PublicPort': 3000, 'PrivatePort': 3000}]}]
                elif path.endswith('/json'): data = dict(INSPECT, Config=dict(INSPECT['Config'],Tty=outer.tty), State=dict(INSPECT['State'], Status='exited' if outer.stopped else INSPECT['State']['Status']))
                elif path == '/events':
                    import time
                    data = b''.join(json.dumps({'Actor': {'ID': CID}, 'Action': 'restart', 'time': int(time.time())-n}).encode()+b'\n' for n in range(3))
                elif path.endswith('/stats'): data = {'cpu_stats': {'cpu_usage': {'total_usage': 300}, 'system_cpu_usage': 1000, 'online_cpus': 2}, 'precpu_stats': {'cpu_usage': {'total_usage': 100}, 'system_cpu_usage': 500}, 'memory_stats': {'usage': 1024, 'limit': 4096}, 'networks': {'eth0': {'rx_bytes': 100, 'tx_bytes': 200}}}
                elif path.endswith('/logs'):
                    logs = ['2026-11-01T00:00:00Z \x1b[31mERROR bad API_TOKEN=private\x1b[0m\n', '2026-11-01T00:00:01Z ERROR bad API_TOKEN=private\n', '2026-11-01T00:00:02Z WARN wait\n', '2026-11-01T00:00:03Z ready\n']
                    logs = outer.log_records if outer.log_records is not None else logs
                    data = b''.join(s.encode() if outer.tty else b'\x01\x00\x00\x00'+struct.pack('>I',len(s.encode()))+s.encode() for s in logs)
                raw = data if isinstance(data, bytes) else json.dumps(data).encode()
                self.send_response(200); self.send_header('Content-Length', str(len(raw))); self.end_headers()
                self.wfile.write(raw)
        self.server = Server(path, Handler)
    def start(self):
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True); self.thread.start(); return self
    def stop(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join()
