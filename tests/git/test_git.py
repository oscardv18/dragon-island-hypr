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
