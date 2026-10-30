import json
import math
import os
from pathlib import Path
import subprocess
from unittest.mock import patch
from support import EngineCase, ROOT
from engine_common import atomic_json, state_path, locked
from dragon_usage import WEEK, compact, record, stats, forget


class UsageTests(EngineCase):
    def test_empty_stats_are_read_only(self):
        self.assertEqual(stats(), {'apps': []})
        self.assertFalse((self.home / 'state').exists())

    def test_decay_normalization_week_and_determinism(self):
        now = 2000000
        record('older', now - WEEK)
        record('new', now)
        record('new', now)
        before = state_path('usage.json').read_bytes()
        rows = stats(now)['apps']
        self.assertEqual([row['id'] for row in rows], ['new', 'older'])
        self.assertEqual(rows[0], dict(id='new', total=2, week=2, lastUsed=now, frecency=1.0))
        self.assertEqual(rows[1]['frecency'], .25)
        self.assertEqual(rows[1]['week'], 0)
        self.assertEqual(stats(now), stats(now))
        self.assertEqual(stats(now + 10)['apps'][1]['frecency'], .25)
        self.assertEqual(state_path('usage.json').read_bytes(), before)

    def test_exact_counts_and_decay_after_compaction(self):
        now = 4000000
        times = [now - WEEK - 10] * 15 + [now - 20] * 2000 + [now] * 100
        app = dict(total=len(times), lastUsed=now, events=times[:], buckets={},
                   past=dict(count=0, weight=0.0, at=now - WEEK - 10))
        compact(app, now)
        self.assertEqual(len(app['events']), 2000)
        self.assertEqual(app['past']['count'], 15)
        self.assertEqual(sum(app['buckets'].values()), 100)
        path = state_path('usage.json')
        with locked(path):
            atomic_json(path, dict(version=1, apps={'busy': app}))
        record('reference', now)
        rows = {row['id']: row for row in stats(now)['apps']}
        expected = sum(2 ** (-(now - timestamp) / WEEK) for timestamp in times)
        self.assertEqual(rows['busy']['total'], 2115)
        self.assertEqual(rows['busy']['week'], 2100)
        self.assertEqual(rows['busy']['frecency'], 1)
        self.assertAlmostEqual(rows['reference']['frecency'], 1 / expected, places=11)
        self.assertEqual(stats(now + WEEK - 10)['apps'][0]['week'], 100)
        self.assertEqual(stats(now + WEEK)['apps'][0]['week'], 0)

    def test_2001_real_records_compact_without_loss(self):
        # Seed a state with exactly the retention limit, then exercise the actual writer.
        path = state_path('usage.json')
        app = dict(total=2000, lastUsed=1000000, events=[1000000] * 2000, buckets={},
                   past=dict(count=0, weight=0.0, at=1000000))
        with locked(path):
            atomic_json(path, dict(version=1, apps={'busy': app}))
        record('busy', 1000001)
        stored = json.loads(path.read_text())['apps']['busy']
        self.assertEqual(len(stored['events']), 2000)
        self.assertEqual(stored['buckets'], {'1000000': 1})
        self.assertEqual(stats(1000001)['apps'][0]['week'], 2001)

    def test_concurrent_processes_and_atomic_reads(self):
        script = 'from dragon_usage import record\nfor i in range(25): record("concurrent")\n'
        environment = dict(os.environ, PYTHONPATH=str(ROOT / 'dragon-core'))
        processes = [subprocess.Popen(['/usr/bin/python3', '-c', script], env=environment) for _ in range(2)]
        for process in processes:
            self.assertEqual(process.wait(timeout=10), 0)
        self.assertEqual(stats()['apps'][0]['total'], 50)
        self.assertEqual(stats()['apps'][0]['week'], 50)
        self.assertEqual(state_path('usage.json').stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(state_path('usage.json').parent.glob('.usage.json*')), [])

    def test_forget_reset_and_id_only(self):
        self.cli('dragon-usage', 'record', 'org.example.App.desktop')
        self.cli('dragon-usage', 'record', 'second')
        self.cli('dragon-usage', 'forget', 'org.example.App.desktop')
        self.assertEqual([row['id'] for row in self.cli('dragon-usage', 'stats', '--json')['apps']], ['second'])
        self.cli('dragon-usage', 'reset')
        self.assertEqual(stats(), {'apps': []})
        for invalid in ('../app', '/usr/bin/app', 'app --secret', 'app\nother'):
            with self.assertRaises(ValueError):
                record(invalid)

    def test_broken_state_is_not_silently_overwritten(self):
        path = state_path('usage.json')
        path.parent.mkdir(parents=True)
        path.write_text('{bad')
        self.cli('dragon-usage', 'record', 'app', code=1)
        self.assertEqual(path.read_text(), '{bad')
