import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]

class FilesMigrations(unittest.TestCase):
    def test_tools_dry_run_backups_and_idempotence(self):
        with tempfile.TemporaryDirectory() as tmp:
            home=Path(tmp)
            env=dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=str(home/'config'),
                     XDG_DATA_HOME=str(home/'data'), XDG_STATE_HOME=str(home/'state'),
                     XDG_CACHE_HOME=str(home/'cache'), XDG_RUNTIME_DIR=str(home/'run'),
                     BACKUP_DIR=str(home/'backup'), ASSUME_YES='true',LINK_MODE='copy')
            # No real xdg-mime, qs, net, or sudo is allowed in migration tests.
            bindir=home/'bin';bindir.mkdir()
            for name in ('sudo','net','qs','xdg-mime'):
                p=bindir/name;p.write_text('#!/bin/sh\nexit 98\n');p.chmod(0o755)
            env['PATH']=str(bindir)+':/usr/bin:/bin'
            engine=home/'data/dragon-island/engines/dragon_files.py'
            engine.parent.mkdir(parents=True);engine.write_text('# stale')
            def snapshot():
                return {str(p.relative_to(home)):p.read_bytes() if p.is_file() else None for p in home.rglob('*')}
            def run(number,**extra):
                migration=next((ROOT/'migrations').glob(number+'-*.sh'))
                return subprocess.run(['bash',str(migration)],env=dict(env,**extra),capture_output=True,text=True)
            for number in ('071','072','073','074','075'):
                for dry in ('1','true'):
                    before=snapshot(); result=run(number,DRY_RUN=dry)
                    self.assertIn(result.returncode,(0,10),result.stderr)
                    self.assertEqual(before,snapshot(),number)
            for number in ('071','072','073'):
                result=run(number)
                self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual((home/'backup/data/dragon-island/engines/dragon_files.py').read_text(),'# stale')
            before=snapshot()
            self.assertEqual(run('073').returncode,0)
            self.assertEqual(before,snapshot())
            # No UI yet: default and shortcut are deferred, no stub command can run.
            self.assertEqual(run('074').returncode,10)
            self.assertEqual(run('075').returncode,10)
            ui=home/'config/quickshell/services';ui.mkdir(parents=True);(ui/'Files.qml').write_text('// installed')
            hypr=home/'config/hypr';hypr.mkdir();(hypr/'binds.lua').write_text('-- stale')
            before=snapshot();self.assertEqual(run('075',DRY_RUN='1').returncode,0);self.assertEqual(before,snapshot())
            self.assertEqual(run('075').returncode,0)
            self.assertEqual((home/'backup/config/hypr/binds.lua').read_text(),'-- stale')
            before=snapshot();self.assertEqual(run('075').returncode,10);self.assertEqual(before,snapshot())
            self.assertIn('qs ipc call files open',(hypr/'binds.lua').read_text())
