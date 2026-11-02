import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class NetworkTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'; self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / 'config'),
                        XDG_STATE_HOME=str(self.home / 'state'), XDG_DATA_HOME=str(self.home / 'data'),
                        XDG_CACHE_HOME=str(self.home / 'cache'), XDG_RUNTIME_DIR=str(self.home / 'run'),
                        PATH=str(self.bin) + ':/usr/bin:/bin', PYTHONDONTWRITEBYTECODE='1')
        self.fake('avahi-browse', '''print('=;eth0;IPv4;NAS;_smb._tcp;local;nas.local;192.0.2.1;445;')
print('=;eth0;IPv4;SSH;_ssh._tcp;local;ssh.local;192.0.2.2;22;')
print('+;eth0;IPv4;not resolved;_smb._tcp;local')
''')
        self.fake('smbclient', "print('Disk|Docs|Documents'); print('IPC|IPC$|IPC')")
        self.fake('secret-tool', '''import os,sys
from pathlib import Path
p=Path(os.environ['HOME'])/'keyring-fake'
if sys.argv[1]=='store': p.write_text(sys.stdin.read())
elif sys.argv[1]=='lookup':
 if p.exists(): print(p.read_text())
 else: sys.exit(1)
''')
        self.fake('gio', '''import sys,os,json
from pathlib import Path
with (Path(os.environ['HOME'])/'argv').open('a') as f: f.write(json.dumps(sys.argv)+'\\n')
if sys.argv[1:]==['mount','-li']:
 print('Mount(0): Docs -> smb://alice@192.0.2.1/Docs')
 print('  default_location=file://'+os.environ['HOME']+'/mounted')
elif sys.argv[1]=='info': print('local path: '+os.environ['HOME']+'/mounted')
elif sys.argv[1:3]==['mount','-u']: pass
else:
 print('User [alice]: ',end='',flush=True); sys.stdin.readline()
 print('Domain [WORKGROUP]: ',end='',flush=True); sys.stdin.readline()
 print('Password: ',end='',flush=True)
 if sys.stdin.readline().strip()!='stdin-secret':
  print('Authentication failed'); sys.exit(1)
''')
        (self.home / 'mounted').mkdir()

    def fake(self, tool, body):
        path = self.bin / tool
        path.write_text('#!/usr/bin/python3\n' + body + '\n'); path.chmod(0o755)

    def tearDown(self): self.tmp.cleanup()

    def cli(self,*args,stdin='',ok=True):
        p = subprocess.run([str(ROOT/'bin/dragon-files'),'net',*args,'--json'],env=self.env,
                           input=stdin,capture_output=True,text=True,timeout=10)
        self.assertEqual(p.returncode,0 if ok else 1,p.stdout+p.stderr)
        self.assertNotIn('stdin-secret',p.stdout+p.stderr)
        return json.loads(p.stdout)

    def test_discovery_and_shares(self):
        hosts = self.cli('discover')['hosts']
        self.assertEqual(len(hosts),2)
        self.assertEqual(hosts[0]['protocol'],'smb')
        self.assertEqual(self.cli('shares','192.0.2.1')['shares'],[dict(name='Docs',comment='Documents')])

    def test_mount_password_and_system_keyring(self):
        result = self.cli('connect','smb://192.0.2.1/Docs','--user','alice','--password-stdin','--save',stdin='stdin-secret\n')
        self.assertEqual(result['mountpoint'],str(self.home/'mounted'))
        self.assertNotIn('stdin-secret',(self.home/'argv').read_text())
        bookmark = (self.home/'config/dragon-island/files/servers.json').read_text()
        self.assertNotIn('stdin-secret',bookmark)
        self.assertEqual((self.home/'keyring-fake').read_text(),'stdin-secret')
        self.cli('connect','smb://alice@192.0.2.1/Docs')
        self.cli('unmount','smb://alice@192.0.2.1/Docs')

    def test_auth_required_and_bad_password(self):
        self.assertEqual(self.cli('connect','smb://192.0.2.1/Docs',ok=False)['error']['code'],'auth_required')
        self.assertEqual(self.cli('connect','smb://192.0.2.1/Docs','--password-stdin',stdin='wrong\n',ok=False)['error']['code'],'bad_password')

    def test_saved_and_forget_all_protocols(self):
        for protocol in ('smb','sftp','nfs','ftp','dav','davs'):
            self.cli('save',protocol+'://192.0.2.1/data','--name','Servidor')
        self.assertEqual(len(self.cli('saved')['servers']),6)
        self.cli('forget','smb://192.0.2.1/data')
        self.assertEqual(len(self.cli('saved')['servers']),5)

    def test_reject_secrets_and_controls_in_uri(self):
        for uri in ('smb://alice:secret@host/share','smb://host/share?password=x',
                    'smb://host/a%0ab','smb://host:bad/a','file:///etc','smb://host/#x'):
            with self.subTest(uri=uri):
                self.assertEqual(self.cli('save',uri,ok=False)['error']['code'],'invalid_uri')
        self.assertFalse((self.home/'argv').exists())

    def test_missing_tool_and_mounts(self):
        (self.bin/'avahi-browse').unlink()
        # Restrict only helper lookup; Python and Bash are still available as fakes.
        for name,target in (('bash','/usr/bin/bash'),('python3','/usr/bin/python3'),('readlink','/usr/bin/readlink')):
            (self.bin/name).symlink_to(target)
        self.env['PATH']=str(self.bin)
        self.assertEqual(self.cli('discover',ok=False)['error']['code'],'missing_tool')
        self.assertEqual(self.cli('mounts')['mounts'][0]['path'],str(self.home/'mounted'))
