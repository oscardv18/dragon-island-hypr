import json
import os
from pathlib import Path
import select
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]

class GitTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='dg-'); self.home = Path(self.tmp.name); self.repo = self.home/'repo ñ'
        self.repo.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), GIT_CONFIG_NOSYSTEM='1', GIT_AUTHOR_NAME='Prueba', GIT_AUTHOR_EMAIL='test@example.org', GIT_COMMITTER_NAME='Prueba', GIT_COMMITTER_EMAIL='test@example.org')
        for key in ('CONFIG', 'DATA', 'STATE', 'CACHE', 'RUNTIME'): self.env['XDG_'+key+('_DIR' if key == 'RUNTIME' else '_HOME')] = str(self.home/key)
        self.git('init', '-b', 'main')
    def tearDown(self): self.tmp.cleanup()
    def git(self, *args): return subprocess.run(['git', '-C', str(self.repo), *args], env=self.env, capture_output=True, check=True).stdout
    def cli(self, *args, ok=True):
        p = subprocess.run([str(ROOT/'bin/dragon-git'), *args, '--repo', str(self.repo), '--json'], env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(p.returncode, 0 if ok else 1, p.stdout+p.stderr)
        return json.loads(p.stdout)
    def write(self, name, text): (self.repo/name).write_text(text)
    def initial(self):
        self.write('base.txt', 'one\ntwo\n'); self.git('add', '.'); self.git('commit', '-m', 'init')
    def test_unborn_stage_commit_and_warning(self):
        name = 'espacio ñ\tline\n.txt'
        self.write(name, 'hello\n'); self.assertEqual(self.cli('status')['untracked'][0]['path'], name)
        self.cli('stage', '--paths', name); self.assertEqual(self.cli('status')['staged'][0]['add'], 1)
        self.cli('unstage', '--paths', name); self.assertEqual(self.cli('status')['staged'], [])
        self.cli('stage', '--paths', name); self.assertTrue(self.cli('commit', '-m', 'initial')['warnings'])
        self.assertEqual(self.cli('log')['log'][0]['subject'], 'initial')
        self.assertEqual(self.cli('branches')['branches'][0]['name'], 'main')
    def test_diff_rename_binary_and_hash(self):
        self.initial(); self.write('base.txt', 'one\nthree\n')
        d = self.cli('diff', '--path', 'base.txt'); self.assertEqual((d['add'], d['del']), (1,1))
        lines = d['hunks'][0]['lines']; self.assertEqual([r['t'] for r in lines], ['ctx','del','add'])
        self.assertEqual(self.cli('blob-hash', '--path', 'base.txt')['hash'], self.git('hash-object', 'base.txt').decode().strip())
        self.git('mv', 'base.txt', 'renamed ñ.txt'); self.assertEqual(self.cli('status')['staged'][0]['status'], 'R')
        (self.repo/'binary').write_bytes(b'a\0b'); self.assertTrue(self.cli('diff', '--path', 'binary')['binary'])
        self.cli('stage', '--paths', 'binary'); self.assertTrue(self.cli('diff', '--path', 'binary', '--staged')['binary'])
    def test_secret_check_uses_index_and_no_values(self):
        self.initial(); self.write('.env', 'FOO=harmless\n'); self.cli('stage', '--paths', '.env')
        out = self.cli('commit', '-m', 'feat(test): no', ok=False)
        self.assertEqual(out['error']['code'], 'secrets_found'); self.assertNotIn('harmless', str(out))
        self.cli('unstage', '--paths', '.env')
        self.write('key.txt', 'first\nAPI_TOKEN=ghp_abcdefghijk\n'); self.cli('stage', '--paths', 'key.txt'); self.write('key.txt', 'safe\n')
        out = self.cli('commit', '-m', 'feat(test): no', ok=False)
        self.assertEqual(out['error']['files'][0]['line'], 2); self.assertNotIn('ghp_', str(out))
        self.cli('stage', '--paths', 'key.txt'); self.cli('commit', '-m', 'feat(test): safe')
    def test_truncation_and_untracked(self):
        self.initial(); self.write('large', 'line\n'*2100)
        d = self.cli('diff', '--path', 'large'); self.assertTrue(d['truncated']); self.assertEqual(sum(len(h['lines']) for h in d['hunks']), 2000)
        self.assertEqual(d['add'], 2100)
    def test_worktrees_dirty_refused_and_remove(self):
        self.initial(); target = self.home/'tree ñ'
        self.cli('worktree', 'add', '--branch', 'feature', '--path', str(target), '--from', 'main')
        self.assertEqual(len(self.cli('worktree', 'list')['worktrees']), 2)
        (target/'untracked').write_text('keep')
        self.assertEqual(self.cli('worktree', 'remove', '--path', str(target), ok=False)['error']['code'], 'dirty_worktree')
        (target/'untracked').unlink(); self.cli('worktree', 'remove', '--path', str(target)); self.assertFalse(target.exists())
    def test_conflict_reported_and_ff_only(self):
        self.initial(); self.git('checkout', '-b', 'other'); self.write('base.txt', 'other\n'); self.git('commit', '-am', 'other')
        self.git('checkout', 'main'); self.write('base.txt', 'main\n'); self.git('commit', '-am', 'main')
        subprocess.run(['git', '-C', str(self.repo), 'merge', 'other'], env=self.env, capture_output=True)
        self.assertEqual(self.cli('status')['conflicts'], ['base.txt'])
        self.cli('commit', '-m', 'feat(test): unresolved', ok=False)
    def test_watch_detects_content_and_stops(self):
        self.initial()
        p = subprocess.Popen([str(ROOT/'bin/dragon-git'), 'watch', '--repo', str(self.repo)], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertTrue(select.select([p.stdout], [], [], 4)[0]); json.loads(p.stdout.readline())
            self.write('base.txt', 'changed\n')
            self.assertTrue(select.select([p.stdout], [], [], 4)[0]); out = json.loads(p.stdout.readline()); self.assertEqual(out['files'][0]['path'], 'base.txt')
            h = out['files'][0]['hash']; self.write('base.txt', 'changed again\n')
            self.assertTrue(select.select([p.stdout], [], [], 4)[0]); self.assertNotEqual(json.loads(p.stdout.readline())['files'][0]['hash'], h)
            p.terminate(); p.communicate(timeout=3); self.assertEqual(p.returncode, 0)
        finally:
            if p.poll() is None: p.kill(); p.communicate()
    def test_multiline_private_key_and_timeout(self):
        self.initial(); self.write('key', '-----BEGIN PRIVATE KEY-----\nprivate-body\n-----END PRIVATE KEY-----\n')
        self.assertNotIn('private-body', str(self.cli('diff', '--path', 'key')))
        self.cli('stage', '--paths', 'key')
        self.assertEqual(self.cli('check-secrets')['secrets'][0]['type'], 'pem')
        import sys
        from unittest.mock import patch
        sys.path.insert(0, str(ROOT/'dragon-core'))
        import dragon_git
        from taller_common import ToolError
        with patch.object( dragon_git.subprocess, 'Popen', wraps=subprocess.Popen):
            with self.assertRaises(ToolError) as caught:
                dragon_git.run(self.repo, '-c', 'alias.wait=!sleep 3', 'wait', timeout=.05)
            self.assertEqual(caught.exception.code, 'git_timeout')

    def test_pathspecs_and_checkout_options(self):
        self.initial(); self.write(':(glob)*', 'literal\n')
        self.cli('stage', '--paths', ':(glob)*'); self.assertEqual(self.cli('status')['staged'][0]['path'], ':(glob)*')
        self.assertEqual(self.cli('stage', '--paths', '../escape', ok=False)['error']['code'], 'invalid_path')
        p = subprocess.run([str(ROOT/'bin/dragon-git'), 'checkout', '--repo', str(self.repo), '--', '--force'], env=self.env, capture_output=True, text=True)
        self.assertEqual(json.loads(p.stdout)['error']['code'], 'invalid_branch')

    def test_untracked_symlink_never_reads_external_target(self):
        self.initial(); outside = self.home/'outside'; outside.write_text('private external content')
        (self.repo/'link').symlink_to(outside)
        d = self.cli('diff','--path','link')
        self.assertNotIn('private external content',str(d))
        self.assertIn(str(outside),str(d))
        (self.repo/'dirlink').symlink_to(self.home,target_is_directory=True)
        self.assertEqual(self.cli('blob-hash','--path','dirlink/outside',ok=False)['error']['code'],'invalid_path')

    def test_unborn_unstage_preserves_newer_working_copy(self):
        self.write('new','staged\n'); self.cli('stage','--paths','new'); self.write('new','newer working copy\n')
        self.cli('unstage','--paths','new')
        self.assertEqual((self.repo/'new').read_text(),'newer working copy\n')
        self.assertEqual(self.cli('status')['staged'],[])

    def test_inotify_debounce_and_child_cleanup(self):
        self.initial(); helpers = self.home/'bin'; helpers.mkdir(); marker = self.home/'watcher-pid'
        watcher = helpers/'inotifywait'
        watcher.write_text('#!/usr/bin/python3\nimport os,time\nfrom pathlib import Path\nPath('+repr(str(marker))+').write_text(str(os.getpid()))\ntime.sleep(.2)\nprint("changed",flush=True)\ntime.sleep(20)\n')
        watcher.chmod(0o755)
        env = dict(self.env,PATH=str(helpers)+os.pathsep+self.env['PATH'])
        p = subprocess.Popen([str(ROOT/'bin/dragon-git'),'watch','--repo',str(self.repo)],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            self.assertTrue(select.select([p.stdout],[],[],3)[0]); json.loads(p.stdout.readline())
            self.write('base.txt','changed after watch starts\n')
            self.assertTrue(select.select([p.stdout],[],[],1.5)[0]); self.assertEqual(json.loads(p.stdout.readline())['files'][0]['path'],'base.txt')
            pid = int(marker.read_text()); p.terminate(); p.communicate(timeout=3)
            self.assertFalse(Path('/proc',str(pid)).exists())
        finally:
            if p.poll() is None: p.kill(); p.communicate()

    def snapshot(self):
        return {str(p.relative_to(self.repo)): (p.read_bytes(), p.stat().st_mode, None if '.git/objects/' in p.as_posix() else p.stat().st_mtime_ns)
                for p in self.repo.rglob('*') if p.is_file() and not p.is_symlink()}

    def test_base_diff_includes_commits_index_and_working_copy(self):
        self.initial(); self.git('checkout', '-b', 'feature')
        self.write('base.txt', 'committed\ntwo\n'); self.git('commit', '-am', 'feature')
        self.write('base.txt', 'committed\nstaged\n'); self.git('add', 'base.txt')
        self.write('base.txt', 'committed\nworking\n')
        before = self.snapshot()
        d = self.cli('diff', '--path', 'base.txt', '--base', 'main')
        self.assertEqual((d['add'], d['del']), (2, 2))
        self.assertIn('working', str(d)); self.assertNotIn("'text': 'staged'", str(d))
        staged = self.cli('diff', '--path', 'base.txt', '--base', 'main', '--staged')
        self.assertIn("'text': 'staged'", str(staged))
        rows = self.cli('status', '--base', 'main')['staged']
        self.assertEqual((rows[0]['add'], rows[0]['del']), (2, 2))
        self.assertEqual(before, self.snapshot())

    def test_base_is_merge_base_and_supports_renames_deletions(self):
        self.initial(); self.git('checkout', '-b', 'feature')
        self.git('mv', 'base.txt', 'renamed ñ\tline\n.txt'); self.git('commit', '-am', 'rename')
        self.git('checkout', 'main'); self.write('only-main', 'main\n'); self.git('add', '.'); self.git('commit', '-m', 'main advances')
        self.git('checkout', 'feature')
        s = self.cli('status', '--base', 'main')
        self.assertEqual([f['path'] for f in s['changes']], ['renamed ñ\tline\n.txt'])
        self.assertEqual(s['changes'][0]['old_path'], 'base.txt')
        self.assertFalse(self.cli('diff', '--path', 'only-main', '--base', 'main')['hunks'])
        self.git('rm', 'renamed ñ\tline\n.txt'); self.git('commit', '-m', 'delete')
        s = self.cli('status', '--base', 'main'); self.assertEqual(s['changes'][0]['status'], 'D')
        self.assertEqual(self.cli('diff', '--path', 'base.txt', '--base', 'main')['del'], 2)

    def test_base_diff_redaction_binary_truncation_and_untracked(self):
        self.initial(); self.git('checkout', '-b', 'feature')
        self.write('secret', 'API_TOKEN=private-value\n'); self.write('large', 'line\n'*2100)
        (self.repo/'binary').write_bytes(b'a\0b'); self.git('add', '.'); self.git('commit', '-m', 'fixtures')
        self.assertNotIn('private-value', str(self.cli('diff', '--path', 'secret', '--base', 'main')))
        self.assertTrue(self.cli('diff', '--path', 'binary', '--base', 'main')['binary'])
        self.assertTrue(self.cli('diff', '--path', 'large', '--base', 'main')['truncated'])
        self.write('untracked', 'new\n'); self.assertEqual(self.cli('diff', '--path', 'untracked', '--base', 'main')['add'], 1)

    def test_merge_check_conflicts_and_clean_leave_entire_repo_unchanged(self):
        self.initial(); name = 'conflict ñ\tline\n.txt'; self.write(name, 'base\n'); self.git('add', '.'); self.git('commit', '-m', 'base')
        self.git('checkout', '-b', 'feature'); self.write(name, 'feature\n'); self.git('commit', '-am', 'feature')
        self.git('checkout', 'main'); self.write(name, 'main\n'); self.git('commit', '-am', 'main')
        self.git('checkout', 'feature'); self.write('dirty', 'keep\n'); self.git('add', 'dirty'); self.write(name, 'working copy\n')
        before = self.snapshot()
        for args in (('main',), ('--base', 'main')):
            r = self.cli('merge-check', *args); self.assertTrue(r['ok']); self.assertEqual(r['conflicts'], [name])
        self.assertEqual(before, self.snapshot())
        self.assertEqual(self.cli('merge-check', 'HEAD')['conflicts'], [])
        self.assertEqual(before, self.snapshot())

    def test_merge_check_clean_divergence_and_linked_worktree(self):
        self.initial(); self.git('checkout', '-b', 'feature'); self.write('feature', 'new\n'); self.git('add', '.'); self.git('commit', '-m', 'feature')
        self.git('checkout', 'main'); self.write('main', 'new\n'); self.git('add', '.'); self.git('commit', '-m', 'main')
        target = self.home/'worktree'; self.git('worktree', 'add', str(target), 'feature')
        before = self.snapshot()
        r = subprocess.run([str(ROOT/'bin/dragon-git'), 'merge-check', '--repo', str(target), '--base', 'main', '--json'], env=self.env, capture_output=True, text=True)
        self.assertEqual(json.loads(r.stdout), {'ok': True, 'conflicts': []}, r.stderr)
        self.assertEqual(before, self.snapshot()); self.assertEqual((target/'base.txt').read_text(), 'one\ntwo\n')

    def test_base_and_merge_invalid_refs_and_unborn(self):
        self.assertFalse(self.cli('merge-check', 'missing', ok=False)['ok'])
        self.initial()
        for command, args in [('merge-check', ('--base', 'missing')), ('diff', ('--path', 'base.txt', '--base', 'missing')), ('status', ('--base', 'missing'))]:
            self.assertFalse(self.cli(command, *args, ok=False)['ok'])
        self.assertEqual(self.cli('merge-check', '--base=-invalid', ok=False)['error']['code'], 'invalid_branch')
        for args in ((), ('main', '--base', 'main')):
            r = subprocess.run([str(ROOT/'bin/dragon-git'), 'merge-check', '--repo', str(self.repo), *args, '--json'], env=self.env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 2); self.assertEqual(json.loads(r.stdout)['error']['code'], 'invalid_usage')

    def test_migration_066_refreshes_copied_engine_with_backup_and_dry_run(self):
        env = dict(self.env, LINK_MODE='copy', ASSUME_YES='true', BACKUP_DIR=str(self.home/'backups'))
        r = subprocess.run(['bash', str(ROOT/'migrations/055-taller-tools.sh')], env=env, capture_output=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        engine = self.home/'DATA/dragon-island/engines/dragon_git.py'; engine.write_text('old engine')
        for flag in ('1', 'true'):
            r = subprocess.run(['bash', str(ROOT/'migrations/066-git-base-check.sh')], env=dict(env, DRY_RUN=flag), capture_output=True)
            self.assertEqual(r.returncode, 0, r.stderr); self.assertEqual(engine.read_text(), 'old engine')
        for _ in range(2):
            r = subprocess.run(['bash', str(ROOT/'migrations/066-git-base-check.sh')], env=env, capture_output=True)
            self.assertEqual(r.returncode, 0, r.stderr)
        copies = list((self.home/'backups').rglob('dragon_git.py'))
        self.assertEqual(len(copies), 1); self.assertEqual(copies[0].read_text(), 'old engine')
        self.initial()
        r = subprocess.run([str(self.home/'.local/bin/dragon-git'), 'merge-check', 'main', '--repo', str(self.repo), '--json'], env=self.env, capture_output=True, text=True)
        self.assertEqual(json.loads(r.stdout), {'ok': True, 'conflicts': []}, r.stderr)
