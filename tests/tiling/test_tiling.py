"""Run dragon-tiling against Hyprland 0.57 selector semantics, without touching a desktop."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TilingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.runtime = self.home / 'workspaces.json'
        self.rows = [dict(id=1, name='1', tiledLayout='dwindle'),
                     dict(id=2, name='2', tiledLayout='dwindle'),
                     dict(id=-1337, name='code', tiledLayout='dwindle'),
                     dict(id=-99, name='special:dropdown', tiledLayout='dwindle')]
        self.runtime.write_text(json.dumps(self.rows))
        self.state = self.home / 'state/dragon-island/tiling.json'
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:/usr/bin:/bin',
                        XDG_STATE_HOME=str(self.home / 'state'), RUNTIME=str(self.runtime),
                        ASSUME_YES='true')
        self.env.pop('STATE_DIR', None)
        self.env.pop('REPO_DIR', None)
        self.stub('hyprctl', r'''#!/usr/bin/env python3
import json, os, re, sys
from pathlib import Path
file = Path(os.environ['RUNTIME'])
rows = json.loads(file.read_text())
args = sys.argv[1:]
if args == ['-j', 'activeworkspace']:
    print(json.dumps(rows[0]))
elif args == ['-j', 'workspaces']:
    print(json.dumps(rows))
elif args[0] == 'eval':
    match = re.fullmatch(r'hl.workspace_rule\(\{ workspace = "([^"]+)", layout = "([^"]+)" \}\)', args[1])
    if not match:
        sys.exit(1)
    selector, mode = match.groups()
    for row in rows:
        if selector.isdigit():
            matches = row['id'] == int(selector)
        elif selector.startswith('name:'):
            matches = row['id'] < 0 and row['name'] == selector[5:]
        else:
            matches = row['name'] == selector
        if matches:
            row['tiledLayout'] = mode
    file.write_text(json.dumps(rows))
    print('ok')
else:
    sys.exit(1)
''')
        self.stub('qs', '#!/bin/sh\nexit 0\n')

    def stub(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def run_bash(self, script, *args, **env):
        return subprocess.run(['bash', str(script), *args], env=dict(self.env, **env),
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)

    def tiling(self, *args):
        result = self.run_bash(ROOT / 'scripts/tiling.sh', *args)
        self.assertEqual(result.returncode, 0, result.stdout)
        return result.stdout.strip()

    def layouts(self):
        return {row['name']: row['tiledLayout'] for row in json.loads(self.runtime.read_text())}

    def test_toggle_numbered_workspace_both_directions_and_preserve_others(self):
        self.assertEqual(self.tiling('toggle'), 'scrolling')
        self.assertEqual(self.layouts(), {'1': 'scrolling', '2': 'dwindle',
                                         'code': 'dwindle', 'special:dropdown': 'dwindle'})
        self.assertEqual(json.loads(self.state.read_text()), {'workspaces': {'1': 'scrolling'}})
        self.assertEqual(json.loads(self.tiling('get', '--json')),
                         {'workspace': '1', 'mode': 'scrolling'})
        self.assertEqual(self.tiling('toggle'), 'dwindle')
        self.assertEqual(self.layouts()['1'], 'dwindle')
        self.assertEqual(json.loads(self.state.read_text()), {'workspaces': {}})

    def test_set_another_numbered_workspace(self):
        self.tiling('set', 'scrolling', '--workspace', '2')
        self.assertEqual(self.layouts()['2'], 'scrolling')
        self.assertEqual(self.layouts()['1'], 'dwindle')

    def test_named_and_special_workspaces(self):
        for name in ('code', 'special:dropdown'):
            self.tiling('set', 'scrolling', '--workspace', name)
            self.assertEqual(self.layouts()[name], 'scrolling')
            self.tiling('toggle', '--workspace', name)
            self.assertEqual(self.layouts()[name], 'dwindle')

    def test_restore_existing_saved_modes(self):
        self.state.parent.mkdir(parents=True)
        saved = '{"workspaces":{"1":"scrolling","2":"scrolling","code":"scrolling"}}\n'
        self.state.write_text(saved)
        self.tiling('restore')
        self.assertEqual(self.layouts(), {'1': 'scrolling', '2': 'scrolling',
                                         'code': 'scrolling', 'special:dropdown': 'dwindle'})
        self.assertEqual(self.state.read_text(), saved)

    def test_restore_missing_or_corrupt_state_does_nothing(self):
        before = self.runtime.read_bytes()
        self.tiling('restore')
        self.state.parent.mkdir(parents=True)
        self.state.write_text('broken')
        self.tiling('restore')
        self.assertEqual(self.runtime.read_bytes(), before)

    def test_migration_backs_up_copied_runner_and_keeps_saved_modes(self):
        runner = self.home / '.local/bin/dragon-tiling'
        runner.parent.mkdir(parents=True)
        runner.write_text('# old\n')
        self.state.parent.mkdir(parents=True)
        saved = '{"workspaces":{"1":"scrolling"}}\n'
        self.state.write_text(saved)
        migration = ROOT / 'migrations/042-tiling-workspace-selectors.sh'
        for dry in ('1', 'true'):
            result = self.run_bash(migration, DRY_RUN=dry, LINK_MODE='copy')
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(runner.read_text(), '# old\n')
        result = self.run_bash(migration, LINK_MODE='copy')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(runner.read_bytes(), (ROOT / 'scripts/tiling.sh').read_bytes())
        backup = list((self.state.parent / 'backups').glob('*/.local/bin/dragon-tiling'))
        self.assertEqual(len(backup), 1)
        self.assertEqual(backup[0].read_text(), '# old\n')
        self.assertEqual(self.run_bash(migration, LINK_MODE='copy').returncode, 10)
        self.assertEqual(self.state.read_text(), saved)

    def test_migration_leaves_current_copies_and_symlinks_alone(self):
        runner = self.home / '.local/bin/dragon-tiling'
        runner.parent.mkdir(parents=True)
        migration = ROOT / 'migrations/042-tiling-workspace-selectors.sh'
        self.assertEqual(self.run_bash(migration).returncode, 10)
        shutil.copy(ROOT / 'scripts/tiling.sh', runner)
        self.assertEqual(self.run_bash(migration).returncode, 10)
        runner.unlink()
        runner.symlink_to(ROOT / 'scripts/tiling.sh')
        self.assertEqual(self.run_bash(migration).returncode, 10)
        self.assertTrue(runner.is_symlink())


if __name__ == '__main__':
    unittest.main()
