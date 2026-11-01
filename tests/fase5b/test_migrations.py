import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/docker'))
from fake_docker import FakeDocker

class Migrations(unittest.TestCase):
    def test_copied_and_linked_installs_dry_run_backups_and_idempotency(self):
        for mode in ('copy','symlink'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix='5b-migration-') as tmp:
                home = Path(tmp); runtime = home/'runtime'; runtime.mkdir(mode=0o700)
                env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime), REPO_DIR=str(ROOT), LINK_MODE=mode,
                           ASSUME_YES='true', DRAGON_DOCKER_SOCKET=str(home/'docker.sock'), PYTHONDONTWRITEBYTECODE='1')
                for key in ('CONFIG','DATA','STATE','CACHE'): env[f'XDG_{key}_HOME'] = str(home/key.lower())
                bindir = home/'.local/bin'; bindir.mkdir(parents=True)
                for name in ('dragon-docker','dragon-git'): (bindir/name).write_text('old '+name)
                config = home/'config/quickshell'; config.mkdir(parents=True); (config/'shell.qml').write_text('old shell')
                (home/'.gitconfig').write_text('# keep identity\n')
                def tree():
                    return {str(p.relative_to(home)):hashlib.sha256(p.read_bytes()).hexdigest() for p in home.rglob('*') if p.is_file() and 'backups' not in p.parts and p.name != 'manifest'}
                for phase in ('dry','first','second'):
                    before = tree()
                    for name in ('055-taller-tools.sh','056-taller-docker-git-ui.sh'):
                        r = subprocess.run(['bash',str(ROOT/'migrations'/name)],env=dict(env,DRY_RUN='1' if phase == 'dry' else '0'),capture_output=True,text=True,timeout=10)
                        self.assertEqual(r.returncode,0,r.stdout+r.stderr)
                    if phase in ('dry','second'): self.assertEqual(tree(),before)
                self.assertEqual((home/'.gitconfig').read_text(),'# keep identity\n')
                backups = [p.read_text() for p in (home/'state/dragon-island/backups').rglob('*') if p.is_file()]
                for content in ('old dragon-docker','old dragon-git','old shell'): self.assertIn(content,backups)
                server = FakeDocker(str(home/'docker.sock')).start()
                try:
                    r = subprocess.run([str(bindir/'dragon-docker'),'ps','--json'],env=env,capture_output=True,text=True,timeout=5)
                    self.assertEqual(r.returncode,0,r.stdout+r.stderr); self.assertTrue(json.loads(r.stdout)['containers'])
                finally: server.stop()
                repo = home/'repo'; subprocess.run(['git','init',str(repo)],env=env,capture_output=True,check=True)
                r = subprocess.run([str(bindir/'dragon-git'),'status','--repo',str(repo),'--json'],env=env,capture_output=True,text=True)
                self.assertTrue(json.loads(r.stdout)['ok'],r.stdout+r.stderr)
