import json
import os
from pathlib import Path
import shlex
import signal
import sqlite3
import subprocess
import sys
import time
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tool_support import ToolCase, ROOT, FIXTURES


class Gates(ToolCase):
    def command(self, command):
        self.cli('dragon-mem', 'project', 'set', 'test', '--test-cmd', command)

    def gate(self, *args, code=0):
        r = subprocess.run([str(ROOT/'bin/dragon-gate'), 'run', '--project', 'test', '--cwd', str(self.repo), *args, '--json'],
                           env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(r.returncode, code, r.stderr+r.stdout)
        return [json.loads(line) for line in r.stdout.splitlines()]

    def test_no_command_and_usage(self):
        self.assertEqual(self.gate(code=1)[0]['error']['code'], 'no_test_cmd')
        self.assertEqual(self.cli('dragon-gate', 'run', code=2)['error']['code'], 'invalid_usage')
        self.command('true')
        self.assertEqual(self.gate('--timeout', '0', code=1)[0]['error']['code'], 'invalid_timeout')

    def test_progress_redaction_and_gate_event(self):
        key = self.card(); self.cli('dragon-mem', 'card', 'move', key, '--to', 'doing')
        # user-defined command, no shell interpolation by the tool
        (self.repo/'output.txt').write_text((FIXTURES/'gate-output.txt').read_text())
        self.command('cat output.txt')
        records = self.gate(); r = records[-1]
        self.assertTrue(r['ok']); self.assertEqual(r['exit'], 0); self.assertEqual(r['card'], key)
        self.assertEqual(records[0]['t'], 'progress')
        text = json.dumps(records); self.assertNotIn('fixture-secret', text); self.assertNotIn('fixture-private-key-content', text)
        with sqlite3.connect(self.db) as db:
            event = db.execute("select data from card_event where kind='gate'").fetchone()[0]
        self.assertTrue(json.loads(event)['ok']); self.assertNotIn('tail', event)

    def test_nonzero_tail_and_no_output(self):
        self.command("for n in {1..50}; do echo $n; done; exit 7")
        r = self.gate(code=1)[-1]; self.assertEqual(r['exit'], 7)
        self.assertEqual(r['tail'], list(map(str, range(21, 51))))
        self.assertEqual(r['error']['code'], 'test_failed')
        self.command('true'); self.assertEqual(self.gate()[-1]['tail'], [])

    def test_output_and_line_limits(self):
        self.command("python3 -c 'print(\"x\"*20000)' ")
        r = self.gate()[-1]; self.assertIn('16 KiB', r['tail'][0]); self.assertLess(len(str(r)), 1000)
        self.command("python3 -c 'import os; [os.write(1,b\"x\"*65536) for _ in range(40)]'")
        r = self.gate(code=1)[-1]; self.assertEqual(r['error']['code'], 'output_limit'); self.assertTrue(r['truncated'])

    def test_timeout_and_closed_stdout(self):
        for cmd in ('sleep 30', 'exec 1>&- 2>&-; sleep 30'):
            self.command(cmd); start = time.monotonic()
            self.assertEqual(self.gate('--timeout', '.2', code=1)[-1]['error']['code'], 'timeout')
            self.assertLess(time.monotonic()-start, 2)

    def test_sigterm_kills_children(self):
        script = self.repo/'child.py'
        script.write_text('import os,time\nfrom pathlib import Path\nPath("child.pid").write_text(str(os.getpid()))\ntime.sleep(1.2)\nPath("survived").touch()\ntime.sleep(30)\n')
        self.command('python3 child.py & wait')
        proc = subprocess.Popen([str(ROOT/'bin/dragon-gate'), 'run', '--project', 'test', '--cwd', str(self.repo)],
                                env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: proc.poll() is None and proc.kill())
        deadline = time.monotonic()+4
        while not (self.repo/'child.pid').exists() and time.monotonic()<deadline: time.sleep(.02)
        self.assertTrue((self.repo/'child.pid').exists())
        proc.send_signal(signal.SIGTERM); stdout, stderr = proc.communicate(timeout=4)
        self.assertEqual(proc.returncode, 1, stderr); self.assertEqual(json.loads(stdout.splitlines()[-1])['error']['code'], 'cancelled')
        time.sleep(1.3); self.assertFalse((self.repo/'survived').exists())

    def test_ambiguous_card_and_explicit_scope(self):
        self.command('true'); keys = [self.card(), self.card()]
        for k in keys: self.cli('dragon-mem', 'card', 'move', k, '--to', 'doing')
        self.assertEqual(self.gate(code=1)[0]['error']['code'], 'ambiguous_card')
        self.assertEqual(self.gate('--card', keys[1])[-1]['card'], keys[1])

    def test_copy_migration(self):
        for migration in ('044-mem-install.sh', '062-gate-tools.sh', '062-gate-tools.sh'):
            r = subprocess.run(['bash', str(ROOT/'migrations'/migration)], env=dict(self.env, LINK_MODE='copy', ASSUME_YES='true'), capture_output=True)
            self.assertEqual(r.returncode, 0, r.stderr)
        self.command('true')
        r = subprocess.run([str(self.home/'.local/bin/dragon-gate'), 'run', '--project', 'test', '--cwd', str(self.repo)], env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr+r.stdout)
