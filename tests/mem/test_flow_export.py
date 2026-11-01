import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import time
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tool_support import ToolCase, FIXTURES, ROOT


class FlowExport(ToolCase):
    def test_fixture_medians_windows_and_project_isolation(self):
        sample = json.loads((FIXTURES/'flow.json').read_text()); now = int(time.time())
        for c in sample['cards']:
            key = self.card()
            with sqlite3.connect(self.db) as db:
                cid = db.execute('select id from card where key=?', (key,)).fetchone()[0]
                db.execute("update card set col='done',created_at=?,started_at=?,done_at=? where id=?", (now-c['created_h']*3600, now-c['started_h']*3600, now-c['done_h']*3600, cid))
                if c['returned']: db.execute("insert into card_event(card_id,ts,kind) values(?,?,'returned')", (cid, now-25*3600))
        with sqlite3.connect(self.db) as db:
            for n, hours in enumerate(sample['waits']):
                db.execute('insert into agent_wait(agent_id,card_id,blocked_at,resumed_at) values(?,1,?,?)', (str(n), now-(hours+1)*3600, now-3600))
            db.execute('insert into agent_wait(agent_id,card_id,blocked_at) values(?,?,?)', ('open', 1, now-100))
        r = self.cli('dragon-mem', 'stats', 'flow', '--project', 'test', '--days', '30'); r.pop('ok')
        self.assertEqual(r, sample['expected'])
        self.cli('dragon-mem', 'project', 'add', '--path', self.repo, '--slug', 'other', '--prefix', 'OT')
        other = self.cli('dragon-mem', 'stats', 'flow', '--project', 'other')
        self.assertEqual(other['throughput_7d'], 0); self.assertIsNone(other['lead_time_median_h'])
        self.assertEqual(self.cli('dragon-mem', 'stats', 'flow', '--project', 'test', '--days', '0', code=1)['error']['code'], 'invalid_days')

    def test_future_invalid_durations_and_reopened_cards(self):
        key = self.card(); now = int(time.time())
        with sqlite3.connect(self.db) as db:
            db.execute("update card set col='done',created_at=?,started_at=?,done_at=? where key=?", (now+500, now+100, now-1, key))
        r = self.cli('dragon-mem', 'stats', 'flow', '--project', 'test')
        self.assertIsNone(r['lead_time_median_h']); self.assertIsNone(r['cycle_time_median_h'])
        with sqlite3.connect(self.db) as db: db.execute('update card set done_at=?', (now+500,))
        self.assertEqual(self.cli('dragon-mem', 'stats', 'flow', '--project', 'test')['throughput_7d'], 0)
        with sqlite3.connect(self.db) as db: db.execute("update card set col='doing',done_at=?", (now-1,))
        self.assertEqual(self.cli('dragon-mem', 'stats', 'flow', '--project', 'test')['throughput_7d'], 0)

    def test_export_redacts_before_clipping_and_preserves_sections(self):
        key = self.card(); self.cli('dragon-mem', 'card', 'move', key, '--to', 'doing')
        self.cli('dragon-mem', 'card', 'criteria', 'add', key, '--text', 'Criterio esencial')
        # Simulate legacy/raw records to prove redaction precedes clipping.
        with sqlite3.connect(self.db) as db:
            db.execute('update project set name=?', ('ñ'*5000,))
            db.execute('update card set body=?', ('Bearer '+('sensitive'*300),))
            for n in range(12):
                db.execute("insert into note(project_id,kind,title,body,created_at,updated_at) values(1,'decision',?,?,?,?)", ('Decisión '+str(n), 'TOKEN='+('secret'*100), n, n))
        out = self.repo/'custom.md'
        self.cli('dragon-mem', 'export', '--project', 'test', '--out', out)
        text = out.read_text(); self.assertLess(len(text.encode()), 4096)
        self.assertIn('Criterio esencial', text); self.assertIn('Últimas decisiones', text)
        self.assertNotIn('sensitive', text); self.assertNotIn('secret', text)
        self.assertNotIn('Decisión 0:', text); self.assertIn('Decisión 11:', text)
        self.assertEqual(out.stat().st_mode & 0o777, 0o600)
        before = out.read_bytes(); self.cli('dragon-mem', 'export', '--project', 'test', '--out', out)
        self.assertEqual(out.read_bytes(), before)

    def test_export_empty_and_migration_keeps_database(self):
        r = self.cli('dragon-mem', 'export', '--project', 'test')
        self.assertIn('Ninguna tarjeta', Path(r['path']).read_text())
        with sqlite3.connect(self.db) as db: db.execute('pragma wal_checkpoint(truncate)')
        before = self.db.read_bytes()
        for _ in range(2):
            r = subprocess.run(['bash', str(ROOT/'migrations/063-mem-flow-export.sh')], env=dict(self.env, LINK_MODE='copy', ASSUME_YES='true'), capture_output=True)
            self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.db.read_bytes(), before)
