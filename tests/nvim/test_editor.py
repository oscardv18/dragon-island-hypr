import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
REAL_NVIM = shutil.which('nvim')


class Editor(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dragon-nvim-test-')
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.cfg = self.home / 'cfg/nvim'
        self.state = self.home / 'state/dragon-island'
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.script('pacman', 'exit 0\n')
        self.script('nvim', 'printf "NVIM v0.12.6\\nLuaJIT fixture\\n"\n')
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / 'cfg'),
                        XDG_STATE_HOME=str(self.home / 'state'), XDG_DATA_HOME=str(self.home / 'data'),
                        XDG_CACHE_HOME=str(self.home / 'cache'), XDG_RUNTIME_DIR=str(self.home / 'runtime'),
                        PATH=str(self.bin) + ':' + os.environ['PATH'], REPO_DIR=str(ROOT),
                        BACKUP_DIR=str(self.home / 'backups'), ASSUME_YES='1', NO_SUDO='1',
                        PYTHONDONTWRITEBYTECODE='1', DRAGON_NVIM='0', DRAGON_NVIM_SYNC='0', DRAGON_NVIM_RESTORE='0')
        (self.home / 'runtime').mkdir(mode=0o700)

    def script(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + body)
        path.chmod(0o755)

    def bash(self, action, mode='symlink', dry='false'):
        setup = '. "$REPO_DIR/lib/migration-env.sh"\n. "$REPO_DIR/modules/editor.sh"\n'
        return subprocess.run(['bash', '-c', setup + action],
                              env=dict(self.env, LINK_MODE=mode, DRY_RUN=dry), capture_output=True, text=True)

    def old_config(self):
        self.cfg.mkdir(parents=True)
        (self.cfg / 'init.lua').write_text('-- my old config\n')

    def tree(self):
        result = {}
        for p in self.home.rglob('*'):
            meta = p.lstat()
            if p.is_symlink(): content = os.readlink(p)
            elif p.is_file(): content = p.read_bytes()
            else: content = None
            result[str(p.relative_to(self.home))] = (meta.st_mode, meta.st_mtime_ns, content)
        return result

    def test_deploy_link_and_copy_idempotent_backup_and_uninstall(self):
        for mode in ('symlink', 'copy'):
            with self.subTest(mode=mode):
                self.old_config()
                result = self.bash('editor_apply; editor_check', mode)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(self.cfg.is_symlink(), mode == 'symlink')
                self.assertEqual((self.home / 'backups/cfg/nvim/init.lua').read_text(), '-- my old config\n')
                before = self.tree()
                self.assertEqual(self.bash('editor_apply', mode).returncode, 0)
                self.assertEqual(self.tree(), before)
                (self.state / 'modules').write_text('editor\n')
                (self.state / 'link-mode').write_text(mode)
                uninstall = [str(ROOT / 'uninstall.sh'), '--modules', 'editor', '--yes', '--no-sudo']
                result = subprocess.run(uninstall, env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse(self.cfg.is_symlink())
                self.assertEqual((self.cfg / 'init.lua').read_text(), '-- my old config\n')
                result = subprocess.run(uninstall, env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.cfg / 'init.lua').read_text(), '-- my old config\n')
                shutil.rmtree(self.cfg)
                shutil.rmtree(self.state)
                if (self.home / 'backups').exists(): shutil.rmtree(self.home / 'backups')

    def test_identical_user_copy_is_backed_up_before_first_ownership(self):
        shutil.copytree(ROOT / 'config/nvim', self.cfg)
        original = (self.cfg / 'init.lua').read_bytes()
        result = self.bash('editor_apply', mode='copy')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.home / 'backups/cfg/nvim/init.lua').read_bytes(), original)
        self.assertIn('deploy\t' + str(self.cfg), (self.state / 'manifest').read_text())
        before = self.tree()
        self.assertEqual(self.bash('editor_apply', mode='copy').returncode, 0)
        self.assertEqual(self.tree(), before)
        self.assertEqual(self.bash('editor_revert', mode='copy').returncode, 0)
        self.assertEqual((self.cfg / 'init.lua').read_bytes(), original)

    def test_failed_backup_never_removes_previous_config(self):
        self.old_config()
        self.script('cp', 'exit 1\n')
        r = self.bash('editor_apply')
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(self.cfg.is_symlink())
        self.assertEqual((self.cfg / 'init.lua').read_text(), '-- my old config\n')

    def test_previous_symlink_is_backed_up_and_restored_as_symlink(self):
        self.cfg.parent.mkdir(parents=True)
        previous = self.home / 'previous-editor'
        previous.mkdir()
        (previous / 'init.lua').write_text('-- existing linked config\n')
        self.cfg.symlink_to(previous)
        r = self.bash('editor_apply')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        backup = self.home / 'backups/cfg/nvim'
        self.assertTrue(backup.is_symlink())
        self.assertEqual(backup.readlink(), previous)
        r = self.bash('editor_revert')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.cfg.readlink(), previous)
        self.assertEqual((previous / 'init.lua').read_text(), '-- existing linked config\n')

    def test_dry_run_no_writes_for_both_modes_and_flags(self):
        self.old_config()
        before = self.tree()
        for mode in ('symlink', 'copy'):
            for dry in ('1', 'true'):
                r = self.bash('editor_apply; editor_revert', mode, dry)
                self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
                self.assertEqual(self.tree(), before)

    def test_uninstall_without_ownership_preserves_user_config(self):
        self.old_config()
        r = self.bash('editor_revert')
        self.assertEqual(r.returncode, 0)
        self.assertEqual((self.cfg / 'init.lua').read_text(), '-- my old config\n')

    def test_migration_requires_opt_in_even_with_yes_and_lists_differences(self):
        self.old_config()
        command = ['bash', str(ROOT / 'migrations/150-nvim-opt-in.sh')]
        r = subprocess.run(command, env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 10)
        self.assertFalse(self.cfg.is_symlink())
        for dry in ('1', 'true'):
            before = self.tree()
            r = subprocess.run(command, env=dict(self.env, DRAGON_NVIM='1', DRY_RUN=dry), capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn('init.lua', r.stdout)
            self.assertEqual(self.tree(), before)
        r = subprocess.run(command, env=dict(self.env, DRAGON_NVIM='1'), capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('init.lua', r.stdout)
        self.assertNotIn('-- my old config', r.stdout)
        self.assertTrue(self.cfg.is_symlink())
        before = self.tree()
        self.assertEqual(subprocess.run(command, env=self.env, capture_output=True).returncode, 10)
        self.assertEqual(self.tree(), before)

    def test_migration_identical_still_backs_up_before_linking(self):
        shutil.copytree(ROOT / 'config/nvim', self.cfg)
        result = subprocess.run(['bash', str(ROOT / 'migrations/150-nvim-opt-in.sh')],
                                env=dict(self.env, DRAGON_NVIM='1'), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('idénticas', result.stdout + result.stderr)
        self.assertTrue(self.cfg.is_symlink())
        self.assertTrue((self.home / 'backups/cfg/nvim/lazy-lock.json').exists())

    def test_shared_filter_rejects_secret_private_url_and_personal_path_without_leaking(self):
        source = self.home / 'public'
        shutil.copytree(ROOT / 'config/nvim', source)
        command = ['python3', str(ROOT / 'scripts/check-nvim-public.py'), str(source)]
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
        bad = source / 'lua/plugins/unsafe.lua'
        for content in ('return { api_key = "sk-syntheticCredentialForThisTest123" }',
                        'return "https://private.example.invalid/repo"', 'return "/home/someone/private"'):
            bad.write_text(content)
            r = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(r.returncode, 1)
            self.assertIn('unsafe.lua', r.stderr)
            self.assertNotIn(content, r.stdout + r.stderr)
            self.assertNotIn('sk-syntheticCredentialForThisTest123', r.stdout + r.stderr)

    @unittest.skipUnless(REAL_NVIM, 'Neovim required for offline/syntax checks')
    def test_lua_syntax_and_unconfirmed_headless_start_never_downloads(self):
        self.cfg.parent.mkdir(parents=True)
        self.cfg.symlink_to(ROOT / 'config/nvim')
        self.script('git', 'echo unexpected-network >> "$HOME/network-calls"; exit 91\n')
        files = [str(p) for p in (ROOT / 'config/nvim').rglob('*.lua')]
        check = 'for _,p in ipairs(vim.json.decode(' + json.dumps(json.dumps(files)) + ')) do assert(loadfile(p)) end'
        r = subprocess.run([REAL_NVIM, '--headless', '--clean', '-i', 'NONE', '-n', '+lua ' + check, '+qa'],
                           env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn('Error', r.stderr)
        r = subprocess.run([REAL_NVIM, '--headless', '-i', 'NONE', '-n', '+qa'],
                           env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('Plugins pendientes', r.stderr)
        self.assertFalse((self.home / 'network-calls').exists())
        self.assertFalse((self.home / 'data/nvim/lazy').exists())

    @unittest.skipUnless(REAL_NVIM, 'Neovim required')
    def test_offline_and_timeout_are_warnings_not_failures(self):
        self.cfg.parent.mkdir(parents=True)
        self.cfg.symlink_to(ROOT / 'config/nvim')
        # Fake timeout, not a real restore: verifies the bound and child-only flag.
        self.script('timeout', '''printf '%s|%s\n' "$*" "${DRAGON_NVIM_RESTORE:-0}" >> "$HOME/sync-calls"
case "$*" in
  *ls-remote*) [ -f "$HOME/online" ] && exit 0; exit 1 ;;
  *180s*) exit 124 ;;
esac
exit 92
''')
        for online in (False, True):
            if online: (self.home / 'online').touch()
            r = subprocess.run([REAL_NVIM, '--headless', '-i', 'NONE', '-n', '+qa'],
                               env=dict(self.env, DRAGON_NVIM_SYNC='1'), capture_output=True, text=True, timeout=10)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn('Restauración pendiente' if online else 'Sin acceso a GitHub', r.stderr)
            self.assertFalse((self.home / 'data/nvim/lazy').exists())
        calls = (self.home / 'sync-calls').read_text()
        self.assertIn('--kill-after=5s 180s', calls)
        self.assertIn('+Lazy! restore +qa|1', calls)

    @unittest.skipUnless(REAL_NVIM, 'Neovim required')
    def test_mock_restore_marker_avoids_repeat_network(self):
        self.cfg.parent.mkdir(parents=True)
        self.cfg.symlink_to(ROOT / 'config/nvim')
        versions = json.loads((ROOT / 'config/nvim/lazy-lock.json').read_text())
        for name in versions:
            (self.home / 'data/nvim/lazy' / name).mkdir(parents=True)
        lazy = self.home / 'data/nvim/lazy/lazy.nvim/lua/lazy'
        lazy.mkdir(parents=True)
        (lazy / 'init.lua').write_text('return { setup = function(_) end }')
        self.script('timeout', 'echo fake-restore >> "$HOME/sync-calls"; exit 0\n')
        for approved in ('1', '0'):
            r = subprocess.run([REAL_NVIM, '--headless', '-i', 'NONE', '-n', '+qa'],
                               env=dict(self.env, DRAGON_NVIM_SYNC=approved), capture_output=True, text=True, timeout=10)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertNotIn('Error', r.stderr)
        self.assertTrue((self.home / 'state/nvim/dragon-plugins-restored').exists())
        self.assertEqual((self.home / 'sync-calls').read_text().splitlines(), ['fake-restore', 'fake-restore'])

    @unittest.skipUnless(REAL_NVIM, 'Neovim required')
    def test_version_check_is_read_only_even_with_real_neovim(self):
        self.script('nvim', 'exec ' + shlex.quote(REAL_NVIM) + ' "$@"\n')
        before = self.tree()
        r = self.bash('nvim_version_ok', dry='1')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.tree(), before)

    def test_editor_is_default_and_optional(self):
        source = (ROOT / 'install.sh').read_text()
        defaults = source.split('DEFAULT_MODULES=(', 1)[1].split(')', 1)[0].split()
        self.assertIn('editor', defaults)
        self.assertIn('editor', (ROOT / 'uninstall.sh').read_text().split('ALL_MODULES=(', 1)[1].split(')', 1)[0].split())
        r = subprocess.run([str(ROOT / 'install.sh'), '--dry-run', '--yes', '--no-sudo', '--modules', 'editor'],
                           env=self.env, capture_output=True, text=True, timeout=90)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('editor', r.stdout)
        self.assertFalse(self.cfg.exists())
