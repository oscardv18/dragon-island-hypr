import hashlib
import json
import os
from pathlib import Path
import subprocess
from support import EngineCase, ROOT


class InstallTests(EngineCase):
    def migrate(self, mode='copy', dry=False):
        environment = dict(os.environ, REPO_DIR=str(ROOT), LINK_MODE=mode, ASSUME_YES='true',
                           DRY_RUN='true' if dry else 'false', BACKUP_DIR=str(self.home / 'backups'))
        process = subprocess.run(['bash', str(ROOT / 'migrations/032-engines-install.sh')],
                                 env=environment, capture_output=True, text=True, timeout=10)
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)

    def snapshot(self):
        return {str(path.relative_to(self.home)): (path.is_symlink(), path.lstat().st_mtime_ns,
                hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None)
                for path in self.home.rglob('*')}

    def test_standalone_dry_run_creates_nothing(self):
        self.migrate(dry=True)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_copy_backups_idempotency_and_installed_libraries(self):
        old = self.home / '.local/bin/dragon-clip-store'
        old.parent.mkdir(parents=True)
        old.write_text('old watcher')
        self.migrate()
        self.assertEqual((self.home / 'backups/.local/bin/dragon-clip-store').read_text(), 'old watcher')
        before = self.snapshot()
        self.migrate()
        self.assertEqual(self.snapshot(), before)
        for mode, query in [('calc', '20% de 350'), ('cmd', 'python'), ('web', 'gh shell'), ('emoji', 'flecha')]:
            command = self.home / '.local/bin/dragon-search'
            process = subprocess.run([str(command), mode, query, '--json'], capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertTrue(json.loads(process.stdout)['results'])
        for name, args in [('dragon-usage', ['stats', '--json']), ('dragon-clip', ['pins', 'list', '--json'])]:
            process = subprocess.run([str(self.home / '.local/bin' / name), *args], capture_output=True, text=True)
            self.assertEqual(process.returncode, 0, process.stderr)
        self.assertTrue((self.home / 'data/dragon-island/engines/search-data/emoji.json').is_file())
        self.assertFalse((self.home / '.local/bin/dragon-search').is_symlink())
        # Installed watcher also resolves its copied library and obeys pause.
        flag = self.home / 'runtime/dragon-island/clipboard-paused'
        flag.parent.mkdir(parents=True)
        flag.touch()
        process = subprocess.run([str(self.home / '.local/bin/dragon-clip-store')], input=b'discard', capture_output=True)
        self.assertEqual(process.returncode, 0, process.stderr)

    def test_symlink_and_existing_library_backups(self):
        data = self.home / 'data/dragon-island/engines'
        data.mkdir(parents=True)
        (data / 'search_calc.py').write_text('old library')
        self.migrate('symlink')
        self.assertEqual((self.home / 'backups/data/dragon-island/engines/search_calc.py').read_text(), 'old library')
        before = self.snapshot()
        self.migrate('symlink')
        self.assertEqual(self.snapshot(), before)
        self.assertEqual((self.home / '.local/bin/dragon-search').resolve(), ROOT / 'bin/dragon-search')
        self.assertEqual((data / 'search_calc.py').resolve(), ROOT / 'dragon-core/search_calc.py')

    def test_fresh_core_install_calls_shared_deployment(self):
        # Exercise the actual helper sourced by core, without package or service side effects.
        core = (ROOT / 'modules/core.sh').read_text()
        self.assertIn('. "$REPO_DIR/lib/engines.sh"', core)
        self.assertIn('    engines_setup\n', core)
        environment = dict(os.environ, REPO_DIR=str(ROOT))
        source = '''set -Eeuo pipefail
DRY_RUN=false; LINK_MODE=copy
STATE_DIR="$XDG_STATE_HOME/dragon-island"; MANIFEST="$STATE_DIR/manifest"
BACKUP_DIR="$HOME/backups"
mkdir -p "$STATE_DIR"
. "$REPO_DIR/lib/common.sh"
. "$REPO_DIR/lib/engines.sh"
engines_setup
'''
        process = subprocess.run(['bash', '-c', source], env=environment, capture_output=True)
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertTrue((self.home / '.local/bin/dragon-search').is_file())
