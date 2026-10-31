import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/engines'))
from support import EngineCase
import dragon_activity as activity


class ActivityTests(EngineCase):
    @property
    def path(self):
        return self.home / 'state/dragon-island/activity.jsonl'

    def run_activity(self, *args, code=0):
        result = subprocess.run([str(ROOT / 'bin/dragon-activity'), *map(str, args)],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result

    def add(self, name='cargo build', kind='command', start=None, end=None, status=None):
        args = ['add', '--kind', kind, '--name', name, '--start', str(time.time() if start is None else start)]
        if end is not None:
            args += ['--end', str(end)]
        if status is not None:
            args += ['--status', status]
        identifier = self.run_activity(*args).stdout.strip()
        self.assertRegex(identifier, r'^[0-9a-f]{12}$')
        return identifier

    def rows(self, start=0, stop=None):
        return json.loads(self.run_activity('range', '--from', start, '--to',
                                           time.time() + 1 if stop is None else stop, '--json').stdout)['items']

    def fixture(self, rows):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(''.join(activity.encode(row) for row in rows))

    def test_overlaps_sorting_and_exact_contract(self):
        now = int(time.time())
        early = self.add(start=now - 100, end=now - 30)
        later = self.add(kind='agent', start=now - 50, end=now - 10, status='fail')
        spanning = self.add(kind='focus', start=now - 200, end=now + 50)
        opened = self.add(start=now - 80, status='blocked')
        self.add(start=now - 500, end=now - 300)
        self.add(start=now + 100)
        rows = self.rows(now - 70, now)
        self.assertEqual([row['id'] for row in rows], [spanning, early, opened, later])
        self.assertEqual(set(rows[0]), {'id', 'kind', 'name', 'start', 'end', 'status'})
        self.assertIsNone(rows[2]['end'])
        self.assertEqual(rows[2]['status'], 'blocked')
        self.assertEqual([row['id'] for row in self.rows(now - 300, now - 300)],
                         [row['id'] for row in self.rows() if row['end'] == now - 300])

    def test_empty_range_and_unknown_end_leave_no_state(self):
        self.assertEqual(self.rows(), [])
        result = self.run_activity('end', 'missing-id', code=1)
        self.assertIn('unknown activity id', result.stderr)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_end_status_unknown_and_idempotency(self):
        identifier = self.add()
        before = time.time()
        self.run_activity('end', identifier, '--status', 'fail')
        row = self.rows()[0]
        self.assertEqual(row['status'], 'fail')
        self.assertGreaterEqual(row['end'], before)
        content = self.path.read_bytes()
        self.run_activity('end', identifier)
        self.run_activity('end', 'does-not-exist', code=1)
        self.assertEqual(self.path.read_bytes(), content)

    def test_concurrent_adds_and_end_keep_every_entry_and_valid_line(self):
        processes = [subprocess.Popen([str(ROOT / 'bin/dragon-activity'), 'add', '--kind', 'agent',
                                      '--name', f'worker {i}', '--start', str(time.time())],
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                     for i in range(16)]
        identifiers = []
        for process in processes:
            out, err = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, err)
            identifiers.append(out.strip())
        self.assertEqual(len(set(identifiers)), 16)
        # Race closures with additions, not only two operations of the same type.
        endings = [subprocess.Popen([str(ROOT / 'bin/dragon-activity'), 'end', identifier],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                   for identifier in identifiers]
        extra = self.add(name='extra')
        for process in endings:
            out, err = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, out + err)
        rows = self.rows()
        self.assertEqual({row['id'] for row in rows}, set(identifiers) | {extra})
        self.assertEqual(sum(row['end'] is None for row in rows), 1)
        lines = [json.loads(line) for line in self.path.read_text().splitlines()]
        self.assertEqual(len(lines), 33)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_retention_compacts_only_above_1mb_and_keeps_overlapping_work(self):
        now = int(time.time())
        old = dict(id='old', kind='focus', name='old', start=now - 40 * 86400,
                   end=now - 31 * 86400, status='ok')
        overlap = dict(old, id='overlap', end=now - 29 * 86400)
        self.fixture([old, overlap])
        self.add()
        self.assertIn('old', {row['id'] for row in self.rows()})
        self.path.write_text(activity.encode(old) * 12000 + activity.encode(overlap))
        self.assertGreater(self.path.stat().st_size, 1000000)
        identifier = self.add()
        persisted = [json.loads(line) for line in self.path.read_text().splitlines()]
        self.assertEqual({row['id'] for row in persisted}, {'overlap', identifier})
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        self.assertFalse(list(self.path.parent.glob('.activity-*')))

    def test_secret_filter_before_truncation_and_unsafe_first_token(self):
        for value in ['curl API_KEY=secret', 'curl FOO_TOKEN=secret', 'curl -H "Authorization: Bearer abc"',
                      'curl https://user:password@example.org', 'curl ' + 'x ' * 80 + 'API_KEY=secret']:
            identifier = self.add(name=value)
            self.assertEqual(next(row['name'] for row in self.rows() if row['id'] == identifier), 'curl')
        for value in ['API_KEY=secret tool', 'https://user:password@example.org', 'sk-abcdefghijk1234567']:
            self.assertEqual(activity.safe_name(value), '[redacted]')
        self.assertEqual(activity.safe_name('á' * 100), 'á' * 80)
        self.assertEqual(activity.safe_name('cargo\n build\t--release'), 'cargo build --release')
        contents = self.path.read_text()
        for sensitive in ('secret', 'password', 'Bearer', 'API_KEY'):
            self.assertNotIn(sensitive, contents)

    def test_old_open_entries_close_at_12h_and_persist_unknown(self):
        now = int(time.time())
        old = self.add(start=now - 13 * 3600, status='blocked')
        recent = self.add(start=now - 3600)
        rows = {row['id']: row for row in self.rows()}
        self.assertEqual(rows[old]['status'], 'unknown')
        self.assertEqual(rows[old]['end'], now - 3600)
        self.assertIsNone(rows[recent]['end'])
        contents = self.path.read_bytes()
        self.rows()
        self.assertEqual(self.path.read_bytes(), contents)
        # Expiry specifically triggered by range, with no intervening write.
        self.fixture([dict(rows[old], id='read-expiry', end=None, status='ok')])
        row = self.rows()[0]
        self.assertEqual(row['status'], 'unknown')
        self.assertEqual(json.loads(self.path.read_text().splitlines()[-1]), row)
        self.assertEqual(self.rows(now - 1800, now), [])

    def test_corrupt_file_and_invalid_arguments_do_not_overwrite(self):
        self.fixture([])
        self.path.write_text('{truncated')
        self.run_activity('range', '--from', '0', '--to', '1', '--json', code=1)
        self.run_activity('add', '--kind', 'focus', '--name', 'test', '--start', '1', code=1)
        self.assertEqual(self.path.read_text(), '{truncated')
        for args in [('range', '--from', '2', '--to', '1'),
                     ('range', '--from', 'nan', '--to', '1'),
                     ('range', '--from', '0', '--to', 'inf'),
                     ('add', '--kind', 'other', '--name', 'x', '--start', '1'),
                     ('add', '--kind', 'focus', '--name', 'x', '--start', '2', '--end', '1'),
                     ('end',), ('end', 'id', '--status', 'blocked'),
                     ('range', '--from', '0', '--from', '1', '--to', '2')]:
            self.run_activity(*args, code=2)

    def test_range_cli_under_50ms_with_30_days(self):
        now = int(time.time())
        rows = [dict(id=f'{i:012x}', kind='command', name='cargo build',
                     start=now - 30 * 86400 + i * 432, end=now - 30 * 86400 + i * 432 + 60,
                     status='ok') for i in range(6000)]
        self.fixture(rows)
        self.rows(now - 21600, now)  # Warm process/filesystem caches.
        durations = []
        for _ in range(7):
            start = time.perf_counter()
            result = self.rows(now - 21600, now)
            durations.append((time.perf_counter() - start) * 1000)
            self.assertEqual(len(result), 50)
        median = statistics.median(durations)
        print(f'\nACTIVITY range: median={median:.1f} ms (6000 entries, 30 days, full CLI)')
        self.assertLess(median, 50, durations)

    def migration(self, mode='copy', dry='false'):
        env = dict(os.environ, REPO_DIR=str(ROOT), LINK_MODE=mode, DRY_RUN=dry,
                   ASSUME_YES='true', BACKUP_DIR=str(self.home / 'backups'))
        process = subprocess.run(['bash', str(ROOT / 'migrations/040-activity-install.sh')],
                                 capture_output=True, text=True, env=env, timeout=10)
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)

    def snapshot(self):
        return {str(path.relative_to(self.home)): (path.lstat().st_mtime_ns,
                path.lstat().st_mode, os.readlink(path) if path.is_symlink() else
                hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None)
                for path in self.home.rglob('*')}

    def test_migration_dry_run_true_and_1_leave_home_empty(self):
        for dry in ('1', 'true'):
            self.migration(dry=dry)
            self.assertEqual(list(self.home.iterdir()), [])

    def test_copy_install_backups_idempotency_and_installed_cli(self):
        command = self.home / '.local/bin/dragon-activity'
        command.parent.mkdir(parents=True)
        command.write_text('old command')
        self.migration()
        self.assertEqual((self.home / 'backups/.local/bin/dragon-activity').read_text(), 'old command')
        self.assertFalse(command.is_symlink())
        before = self.snapshot()
        self.migration()
        self.assertEqual(self.snapshot(), before)
        result = subprocess.run([str(command), 'add', '--kind', 'focus', '--name', 'review',
                                 '--start', str(time.time())], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rows()[0]['id'], result.stdout.strip())

    def test_symlink_install_and_fresh_core_integration(self):
        self.migration('symlink')
        self.assertEqual((self.home / '.local/bin/dragon-activity').resolve(), ROOT / 'bin/dragon-activity')
        before = self.snapshot()
        self.migration('symlink')
        self.assertEqual(self.snapshot(), before)
        core = (ROOT / 'modules/core.sh').read_text()
        self.assertIn('. "$REPO_DIR/lib/activity.sh"', core)
        self.assertIn('    activity_setup\n', core)
        # Fresh install fixture: remove the prior symlink deployment.
        (self.home / '.local/bin/dragon-activity').unlink()
        source = '''set -Eeuo pipefail
DRY_RUN=false; LINK_MODE=copy
STATE_DIR="$XDG_STATE_HOME/dragon-island"; MANIFEST="$STATE_DIR/manifest"
BACKUP_DIR="$HOME/backups"
mkdir -p "$STATE_DIR"
. "$REPO_DIR/lib/common.sh"
. "$REPO_DIR/lib/activity.sh"
activity_setup
'''
        result = subprocess.run(['bash', '-c', source], capture_output=True, text=True,
                                env=dict(os.environ, REPO_DIR=str(ROOT)))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.home / '.local/bin/dragon-activity').is_symlink())
