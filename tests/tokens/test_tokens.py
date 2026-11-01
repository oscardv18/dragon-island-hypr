from datetime import datetime, timedelta
import json
from pathlib import Path
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tool_support import ToolCase, ROOT, FIXTURES


class Tokens(ToolCase):
    def setUp(self):
        super().setUp()
        self.env['CODEX_HOME'] = str(self.home/'.codex')
        self.env['CLAUDE_CONFIG_DIR'] = str(self.home/'.claude')
        self.claude = self.home/'.claude/projects/synthetic/log.jsonl'
        self.codex = self.home/'.codex/sessions/synthetic/log.jsonl'
        self.now = datetime.now().astimezone().replace(hour=12, minute=0, second=0, microsecond=0).isoformat()
        self.yesterday = (datetime.now().astimezone()-timedelta(days=1)).isoformat()

    def fixture(self, name, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        text = (FIXTURES/name).read_text().replace('TODAY', self.now).replace('YESTERDAY', self.yesterday)
        path.write_text(text)

    def test_native_formats_streaming_dedup_and_read_only(self):
        self.fixture('claude-usage.jsonl', self.claude); self.fixture('codex-usage.jsonl', self.codex)
        before = {p: p.read_bytes() for p in (self.claude, self.codex)}
        r = self.cli('dragon-tokens', 'today')
        self.assertEqual(r['claude'], {'in': 140, 'out': 35, 'cache': 70})
        self.assertEqual(r['codex'], {'in': 90, 'out': 20})
        self.assertEqual(before, {p: p.read_bytes() for p in before})
        # Copied/resumed transcripts must not count again.
        self.claude.with_name('copy.jsonl').write_bytes(self.claude.read_bytes())
        self.codex.with_name('copy.jsonl').write_bytes(self.codex.read_bytes())
        self.assertEqual(self.cli('dragon-tokens', 'today'), r)

    def test_unknown_missing_and_malformed(self):
        r = self.cli('dragon-tokens', 'today'); self.assertIsNone(r['claude']); self.assertIsNone(r['codex'])
        self.fixture('claude-usage.jsonl', self.claude)
        with self.claude.open('a') as f: f.write('{incomplete')
        self.assertIsNotNone(self.cli('dragon-tokens', 'today')['claude'])
        self.fixture('codex-usage.jsonl', self.codex)
        with self.codex.open('a') as f:
            f.write(json.dumps(dict(type='event_msg', timestamp=self.now, payload=dict(type='token_count', info={'new_format': 5})))+'\n')
        r = self.cli('dragon-tokens', 'today'); self.assertIsNone(r['codex']); self.assertIsNotNone(r['claude'])

    def test_counter_reset_and_separate_sessions(self):
        self.fixture('codex-usage.jsonl', self.codex)
        with self.codex.open('a') as f:
            for n in (5, 8):
                f.write(json.dumps(dict(type='event_msg', timestamp=self.now[:-6]+'.'+str(n)+'00000'+self.now[-6:], payload=dict(type='token_count', info={'total_token_usage': {'input_tokens': n, 'output_tokens': 1}})))+'\n')
        # Reset adds 5, then 3, rather than subtracting from daily totals.
        self.assertEqual(self.cli('dragon-tokens', 'today')['codex'], {'in': 98, 'out': 21})

    def test_previous_day_only_and_bad_numeric_usage(self):
        self.fixture('claude-usage.jsonl', self.claude)
        self.claude.write_text(self.claude.read_text().replace(self.now, self.yesterday))
        self.assertEqual(self.cli('dragon-tokens', 'today')['claude'], {'in': 0, 'out': 0, 'cache': 0})
        self.fixture('claude-usage.jsonl', self.claude)
        self.claude.write_text(self.claude.read_text().replace('"output_tokens":5', '"output_tokens":true'))
        self.assertIsNone(self.cli('dragon-tokens', 'today')['claude'])

    def test_copy_migration(self):
        for migration in ('043-shared-secrets.sh', '064-tokens-tools.sh', '064-tokens-tools.sh'):
            r = subprocess.run(['bash', str(ROOT/'migrations'/migration)], env=dict(self.env, LINK_MODE='copy', ASSUME_YES='true'), capture_output=True)
            self.assertEqual(r.returncode, 0, r.stderr)
        r = subprocess.run([str(self.home/'.local/bin/dragon-tokens'), 'today', '--json'], env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr); self.assertIsNone(json.loads(r.stdout)['claude'])
