import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from fake_docker import FakeDocker, CID
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'dragon-core'))
import dragon_docker as docker
from taller_common import ToolError

class DockerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='dd-'); self.home = Path(self.tmp.name)
        self.env = dict(os.environ, HOME=str(self.home), DRAGON_DOCKER_SOCKET=str(self.home/'docker.sock'))
        for key in ('CONFIG', 'DATA', 'CACHE', 'STATE', 'RUNTIME'): self.env['XDG_'+key+('_DIR' if key == 'RUNTIME' else '_HOME')] = str(self.home/key)
        self.server = FakeDocker(self.env['DRAGON_DOCKER_SOCKET']).start()
    def tearDown(self): self.server.stop(); self.tmp.cleanup()
    def cli(self, *args):
        result = subprocess.run([str(ROOT/'bin/dragon-docker'), *args], env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        return [json.loads(s) for s in result.stdout.splitlines()]
    def test_ps_inspect_action(self):
        c = self.cli('ps', '--json')[0]['containers'][0]
        self.assertEqual((c['project'], c['service'], c['ports']), ('demo', 'api', ['3000->3000']))
        data = self.cli('inspect', CID, '--json')[0]
        self.assertNotIn('private', json.dumps(data)); self.assertNotIn('value', json.dumps(data)); self.assertNotIn('ghp_abcdefghijk', json.dumps(data))
        self.assertTrue(self.cli('action', CID, 'restart')[0]['ok'])
        self.assertTrue(any(r.endswith('/restart') for r in self.server.requests))
    def test_issues_window_and_all_causes(self):
        issues = self.cli('issues', '--json')[0]['issues']
        self.assertEqual({i['kind'] for i in issues}, {'oom', 'restart_loop', 'unhealthy', 'exit_nonzero'})
        self.assertTrue(any('until=' in r and 'since=' in r for r in self.server.requests))
        with patch.object(docker.Docker, 'containers', return_value=[dict(id=CID, started_at='', oom_killed=False, health='none', exit_code=0, state='running', restart_count=100)]), patch.object(docker.Docker, 'request') as req:
            import io
            req.return_value = (unittest.mock.Mock(), io.BytesIO(b''))
            self.assertEqual(docker.Docker().issues(), [])
    def test_logs_redact_collapse_filter(self):
        logs = self.cli('logs', CID)
        self.assertEqual(len(logs), 3); self.assertEqual(logs[0]['count'], 2)
        self.assertNotIn('private', str(logs)); self.assertNotIn('\x1b', str(logs))
        self.assertEqual(len(self.cli('logs', CID, '--level', 'error')), 1)
    def test_stats_math_and_stream_termination(self):
        item = self.cli('stats', '--ids', CID)[0]
        self.assertEqual(item['cpu_pct'], 80); self.assertEqual(item['mem_bytes'], 1024)
        p = subprocess.Popen([str(ROOT/'bin/dragon-docker'), 'stats', '--stream', '--ids', CID], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertEqual(json.loads(p.stdout.readline())['id'], CID)
            p.terminate(); p.communicate(timeout=3); self.assertEqual(p.returncode, 0)
        finally:
            if p.poll() is None: p.kill(); p.communicate()
    def test_missing_socket_and_permissions(self):
        with patch.object(docker.UnixHTTP, 'connect', side_effect=PermissionError()):
            with self.assertRaises(ToolError) as caught: docker.Docker().request('/version', versioned=False)
            self.assertEqual(caught.exception.code, 'docker_permission')
        self.env['DRAGON_DOCKER_SOCKET'] = str(self.home/'missing')
        p = subprocess.run([str(ROOT/'bin/dragon-docker'), 'ps', '--json'], env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 1); self.assertEqual(json.loads(p.stdout)['error']['code'], 'docker_unavailable')

    def test_policy_restarts_recent_oom_and_no_double_count(self):
        import io
        c = dict(id=CID, started_at='now', created_at='2026-01-01T00:00:00Z',
                 oom_killed=False, health='none', exit_code=0, state='running', restart_count=999)
        events = [{'Actor': {'ID': CID}, 'Action': action, 'time': 100+n}
                  for n, action in enumerate(['start','restart','start','restart','start','restart','oom'])]
        with patch.object(docker.Docker, 'containers', return_value=[c]), patch.object(docker.Docker, 'request') as req:
            req.return_value = (unittest.mock.Mock(), io.BytesIO(b''.join(json.dumps(e).encode()+b'\n' for e in events)))
            issues = docker.Docker().issues()
            self.assertEqual({i['kind'] for i in issues}, {'oom','restart_loop'})
            loop = next(i for i in issues if i['kind'] == 'restart_loop')
            self.assertIn('3 veces', loop['detail'])

    def test_one_shot_cpu_uses_two_sample_delta(self):
        first = {'cpu_stats': {'cpu_usage': {'total_usage': 300}, 'system_cpu_usage': 1000, 'online_cpus': 2}}
        _, previous = docker.stats(first)
        second = {'cpu_stats': {'cpu_usage': {'total_usage': 500}, 'system_cpu_usage': 1500, 'online_cpus': 2}}
        result, _ = docker.stats(second, previous)
        self.assertEqual(result['cpu_pct'],80)

    def test_tty_pem_and_only_consecutive_repeats(self):
        self.server.tty = True
        self.server.log_records = ['ERROR same\n','info between\n','ERROR same\n',
            '-----BEGIN PRIVATE KEY-----\n','private body\n','-----END PRIVATE KEY-----\n']
        errors = self.cli('logs',CID,'--level','error')
        self.assertEqual([r['count'] for r in errors],[1,1])
        self.assertNotIn('private body',str(self.cli('logs',CID)))

    def test_follow_reconnect_and_sigterm(self):
        p = subprocess.Popen([str(ROOT/'bin/dragon-docker'),'logs',CID,'--follow'],env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            self.assertEqual(json.loads(p.stdout.readline())['count'],1)
            self.assertEqual(json.loads(p.stdout.readline())['count'],2)
            import time
            time.sleep(1.3)
            self.assertGreaterEqual(sum('/logs?' in r for r in self.server.requests),2)
            p.terminate(); p.communicate(timeout=3); self.assertEqual(p.returncode,0)
        finally:
            if p.poll() is None: p.kill(); p.communicate()
