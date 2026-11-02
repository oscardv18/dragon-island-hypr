import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]

class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.home=Path(self.tmp.name)
        bindir=self.home/'bin';bindir.mkdir()
        self.env=dict(os.environ,HOME=str(self.home),XDG_STATE_HOME=str(self.home/'state'),
                      XDG_CONFIG_HOME=str(self.home/'config'),XDG_DATA_HOME=str(self.home/'data'),
                      XDG_CACHE_HOME=str(self.home/'cache'),PATH=str(bindir)+':/usr/bin:/bin',
                      PYTHONDONTWRITEBYTECODE='1')
        for name,body in {'xdg-mime':'''from pathlib import Path
import os,sys
p=Path(os.environ['HOME'])/'association'
if sys.argv[1]=='query': print(p.read_text() if p.exists() else 'org.kde.dolphin.desktop')
else: p.write_text(sys.argv[2])
''', 'qs':'''import os,sys,json
from pathlib import Path
with (Path(os.environ['HOME'])/'ipc').open('a') as f:f.write(json.dumps(sys.argv[1:])+'\\n')
'''}.items():
            p=bindir/name;p.write_text('#!/usr/bin/python3\n'+body);p.chmod(0o755)

    def tearDown(self):self.tmp.cleanup()

    def cli(self,*args,ok=True):
        p=subprocess.run([str(ROOT/'bin/dragon-files'),*args,'--json'],env=self.env,capture_output=True,text=True)
        self.assertEqual(p.returncode,0 if ok else 1,p.stdout+p.stderr)
        return json.loads(p.stdout)

    def test_set_default_twice_restore_preserves_original(self):
        self.cli('--set-default');self.cli('--set-default')
        self.assertEqual((self.home/'association').read_text(),'dragon-files.desktop')
        r=self.cli('--restore-default');self.assertEqual(r['default'],'org.kde.dolphin.desktop')
        self.assertEqual((self.home/'association').read_text(),'org.kde.dolphin.desktop')
        state=self.home/'state/dragon-island/files/default.json'
        self.assertEqual(state.stat().st_mode & 0o777,0o600)

    def test_browse_local_uri_and_shell_metacharacters(self):
        folder=self.home/'space `touch hacked` $HOME';folder.mkdir()
        self.cli('--browse',folder.as_uri())
        args=json.loads((self.home/'ipc').read_text())
        self.assertEqual(args,['ipc','call','files','open',str(folder)])
        self.assertFalse((self.home/'hacked').exists())

    def test_reject_remote_uri_and_missing_previous(self):
        self.assertEqual(self.cli('--browse','smb://host/share',ok=False)['error']['code'],'unsupported_uri')
        self.assertEqual(self.cli('--restore-default',ok=False)['error']['code'],'no_previous_default')

    def test_desktop_entry_does_not_recurse(self):
        text=(ROOT/'config/applications/dragon-files.desktop').read_text()
        self.assertIn('Exec=dragon-files --browse %U',text)
        self.assertIn('MimeType=inode/directory;',text)
        self.assertNotIn('xdg-open',text)
