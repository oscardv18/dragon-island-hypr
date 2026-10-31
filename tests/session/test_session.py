"""Stale terminal recovery and updater failures, with no real desktop commands."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.calls = self.home / 'calls'
        self.env = dict(os.environ, HOME=str(self.home), XDG_STATE_HOME=str(self.home / 'state'),
                        XDG_CONFIG_HOME=str(self.home / 'config'),
                        PATH=f'{self.bin}:/usr/bin:/bin', CALLS=str(self.calls),
                        HYPRLAND_INSTANCE_SIGNATURE='old', WAYLAND_DISPLAY='wayland-1',
                        INSTANCES=json.dumps([dict(instance='current', wl_socket='wayland-1')]))
        self.env.pop('STATE_DIR', None)
        self.env.pop('REPO_DIR', None)
        self.stub('hyprctl', '''#!/usr/bin/env python3
import os, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as f:
    f.write('hyprctl ' + ' '.join(args) + ' ' + os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '') + '\\n')
if args == ['-j', 'instances']:
    print(os.environ['INSTANCES'])
    sys.exit(0)
if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE') != 'current':
    sys.exit(4)
if args == ['reload'] and os.environ.get('RELOAD_FAIL'):
    sys.exit(1)
if args == ['configerrors'] and os.environ.get('ERRORS_FAIL'):
    sys.exit(4)
if args == ['plugin', 'list']:
    print('Plugin hyprfocus\\nPlugin hyprglass\\nVersion 0.9.1')
''')
        self.stub('hyprpm', '''#!/bin/sh
echo "hyprpm $* $HYPRLAND_INSTANCE_SIGNATURE" >> "$CALLS"
if [ "$1" = list ]; then echo 'hyprland-plugins HyprGlass'; fi
''')
        for name in ('sudo', 'qs', 'notify-send'):
            self.stub(name, f'#!/bin/sh\necho "{name} $*" >> "$CALLS"\n')
        self.stub('pacman', '#!/bin/sh\necho "hyprland 0.57.0-1"\n')
        self.stub('gum', '#!/bin/sh\nprintf "%s\\n" "$@"\n')

    def stub(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def run_bash(self, args, **env):
        return subprocess.run(['bash', *args], env=dict(self.env, **env), text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)

    def resolve(self, **env):
        return self.run_bash(['-c', 'source "$1"; hyprland_session; rc=$?; '
                             'echo "signature=$HYPRLAND_INSTANCE_SIGNATURE"; exit "$rc"',
                             'test', str(ROOT / 'lib/hyprland-session.sh')], **env)

    def test_recovers_stale_signature_for_same_display(self):
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('signature=current', result.stdout)

    def test_preserves_working_signature_without_discovery(self):
        result = self.resolve(HYPRLAND_INSTANCE_SIGNATURE='current')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn('instances', self.calls.read_text())

    def test_recovers_missing_signature_with_display(self):
        self.assertEqual(self.resolve(HYPRLAND_INSTANCE_SIGNATURE='').returncode, 0)

    def test_absolute_wayland_display(self):
        self.assertEqual(self.resolve(WAYLAND_DISPLAY='/run/user/1000/wayland-1').returncode, 0)

    def test_ignores_other_sessions(self):
        rows = [dict(instance='other', wl_socket='wayland-2'),
                dict(instance='current', wl_socket='wayland-1')]
        self.assertEqual(self.resolve(INSTANCES=json.dumps(rows)).returncode, 0)

    def test_rejects_ambiguous_missing_malformed_or_dead_instances(self):
        for rows in ('invalid', '{}', 'null', '[]', '[null]',
                     json.dumps([dict(instance='other', wl_socket='wayland-2')]),
                     json.dumps([dict(instance='dead', wl_socket='wayland-1')]),
                     json.dumps([dict(instance='current', wl_socket='wayland-1')] * 2)):
            with self.subTest(rows=rows):
                result = self.resolve(INSTANCES=rows)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('signature=old', result.stdout)

    def test_no_display_does_not_select_another_session(self):
        self.assertNotEqual(self.resolve(WAYLAND_DISPLAY='').returncode, 0)
        self.assertNotIn('instances', self.calls.read_text())

    def updater(self, **env):
        repo = self.home / 'repo'
        repo.mkdir()
        shutil.copy(ROOT / 'update.sh', repo)
        shutil.copytree(ROOT / 'lib', repo / 'lib')
        for directory in ('modules', 'migrations', 'scripts'):
            (repo / directory).mkdir()
        sync = repo / 'scripts/sync-shared.sh'
        sync.write_text('#!/bin/sh\nexit 0\n')
        sync.chmod(0o755)
        state = self.home / 'state/dragon-island'
        state.mkdir(parents=True)
        (state / 'modules').write_text('plugins\n')
        return self.run_bash([str(repo / 'update.sh'), '--yes'], **env)

    def test_updater_recovers_before_plugin_checks_and_reload(self):
        result = self.updater()
        self.assertEqual(result.returncode, 0, result.stdout)
        calls = self.calls.read_text()
        self.assertIn('hyprpm reload -n current', calls)
        self.assertIn('hyprctl reload current', calls)
        self.assertIn('Actualización terminada', result.stdout)
        self.assertNotIn('sudo ', calls)

    def test_updater_without_session_completes_and_defers_plugins(self):
        result = self.updater(INSTANCES='[]')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('Actualización terminada', result.stdout)
        self.assertTrue((self.home / 'state/dragon-island/plugins.pending').exists())
        calls = self.calls.read_text()
        self.assertNotIn('hyprpm ', calls)
        self.assertNotIn('qs ', calls)

    def test_reload_failure_keeps_running_shell_and_summary(self):
        result = self.updater(RELOAD_FAIL='1')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('Falló hyprctl reload', result.stdout)
        self.assertNotIn('qs kill', self.calls.read_text())

    def test_configerrors_failure_does_not_abort_summary(self):
        result = self.updater(ERRORS_FAIL='1')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('comprobación pendiente', result.stdout)
        self.assertIn('Actualización terminada', result.stdout)

    def test_plugin_runner_checks_connection_before_hyprpm(self):
        result = self.run_bash([str(ROOT / 'scripts/plugins-foreground.sh')], INSTANCES='[]')
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertTrue((self.home / 'state/dragon-island/plugins.pending').exists())
        self.assertNotIn('hyprpm ', self.calls.read_text())
        self.assertNotIn('sudo ', self.calls.read_text())

    def test_failed_plugin_build_stays_pending(self):
        self.stub('hyprpm', '#!/bin/sh\necho "hyprpm $*" >> "$CALLS"\nexit 1\n')
        result = self.run_bash([str(ROOT / 'scripts/plugins-foreground.sh')])
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertTrue((self.home / 'state/dragon-island/plugins.pending').exists())
        self.assertNotIn('hyprctl reload', self.calls.read_text())

    def test_migration_refreshes_copies_with_backup_and_is_idempotent(self):
        state = self.home / 'state/dragon-island'
        state.mkdir(parents=True)
        runner = state / 'plugins-foreground.sh'
        runner.write_text('# old runner\n')
        migration = [str(ROOT / 'migrations/041-hyprland-session.sh')]
        for dry in ('1', 'true'):
            result = self.run_bash(migration, DRY_RUN=dry, LINK_MODE='copy')
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(runner.read_text(), '# old runner\n')
            self.assertFalse((state / 'hyprland-session.sh').exists())
        result = self.run_bash(migration, LINK_MODE='copy')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(runner.read_bytes(), (ROOT / 'scripts/plugins-foreground.sh').read_bytes())
        backups = list((state / 'backups').glob('*/state/dragon-island/plugins-foreground.sh'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), '# old runner\n')
        self.assertEqual(self.run_bash(migration, LINK_MODE='copy').returncode, 10)
        result = self.run_bash([str(runner)])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('hyprpm update current', self.calls.read_text())
        self.assertFalse((state / 'plugins.pending').exists())

    def test_migration_without_installed_runner_skips(self):
        result = self.run_bash([str(ROOT / 'migrations/041-hyprland-session.sh')])
        self.assertEqual(result.returncode, 10, result.stdout)

    def test_migration_supports_symlinked_plugin_runner(self):
        state = self.home / 'state/dragon-island'
        state.mkdir(parents=True)
        runner = state / 'plugins-foreground.sh'
        runner.symlink_to(ROOT / 'scripts/plugins-foreground.sh')
        migration = [str(ROOT / 'migrations/041-hyprland-session.sh')]
        result = self.run_bash(migration, LINK_MODE='symlink')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(runner.is_symlink())
        self.assertEqual((state / 'hyprland-session.sh').resolve(), ROOT / 'lib/hyprland-session.sh')
        self.assertEqual(self.run_bash(migration, LINK_MODE='symlink').returncode, 10)
        result = self.run_bash([str(runner)])
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == '__main__':
    unittest.main()
