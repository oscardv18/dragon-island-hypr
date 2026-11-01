"""Copied installs, backups, dry runs, second application and installed CLIs."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
class Migrations(unittest.TestCase):
    def test_new_migrations_are_idempotent_and_back_up_copies(self):
        with tempfile.TemporaryDirectory(prefix='taller-migrations-') as tmp:
            home=Path(tmp)
            env=dict(os.environ,HOME=tmp,REPO_DIR=str(ROOT),LINK_MODE='copy',ASSUME_YES='true',PYTHONDONTWRITEBYTECODE='1')
            for n in ('CONFIG','DATA','STATE','CACHE'):env[f'XDG_{n}_HOME']=str(home/n.lower())
            cfg=home/'config';(cfg/'quickshell').mkdir(parents=True);(cfg/'quickshell/shell.qml').write_text('old shell')
            bindir=home/'.local/bin';bindir.mkdir(parents=True);(bindir/'dragon-herdr').write_text('old wrapper')
            migrations=sorted(p for p in (ROOT/'migrations').glob('*.sh') if int(p.name[:3])>=43)
            def tree():
                return {str(p.relative_to(home)):hashlib.sha256(p.read_bytes()).hexdigest() for p in home.rglob('*') if p.is_file() and 'backups' not in p.parts and p.name!='manifest'}
            for phase in ('dry','first','second'):
                before=tree()
                for p in migrations:
                    r=subprocess.run(['bash',str(p)],env=dict(env,DRY_RUN='1' if phase=='dry' else '0'),capture_output=True,text=True,timeout=20)
                    self.assertEqual(r.returncode,0,p.name+r.stdout+r.stderr)
                if phase in ('dry','second'):self.assertEqual(before,tree(),phase)
            backups=[p for p in (home/'state/dragon-island/backups').rglob('*') if p.is_file()]
            self.assertTrue(any(p.read_bytes()==b'old shell' for p in backups))
            self.assertTrue(any(p.read_bytes()==b'old wrapper' for p in backups))
            for command in ('dragon-mem','dragon-herdr'):
                r=subprocess.run([str(bindir/command),'path' if command=='dragon-mem' else 'probe','--json'],env=env,capture_output=True,text=True)
                self.assertEqual(r.returncode,0,r.stdout+r.stderr)
