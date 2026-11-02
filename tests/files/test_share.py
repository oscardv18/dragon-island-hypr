import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class ShareTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        bindir = self.home/'bin'; bindir.mkdir()
        self.env = dict(os.environ,HOME=str(self.home), XDG_CONFIG_HOME=str(self.home/'config'),
                        XDG_DATA_HOME=str(self.home/'data'), XDG_STATE_HOME=str(self.home/'state'),
                        PATH=str(bindir)+':/usr/bin:/bin', PYTHONDONTWRITEBYTECODE='1')
        fake = bindir/'net'
        fake.write_text('''#!/usr/bin/python3
import sys,os,json
from pathlib import Path
p=Path(os.environ['HOME'])/'usershares-fake'
rows=json.loads(p.read_text()) if p.exists() else {}
args=sys.argv[1:]
with (Path(os.environ['HOME'])/'argv').open('a') as f: f.write(json.dumps(args)+'\\n')
if args[:2]==['usershare','info']:
 for name,r in rows.items():
  print('['+name+']'); print('path='+r['path']); print('usershare_acl='+r['acl']); print(r['guest'])
elif args[:2]==['usershare','add']:
 rows[args[2]]={'path':args[3],'acl':args[5],'guest':args[6]}; p.write_text(json.dumps(rows))
elif args[:2]==['usershare','delete']:
 rows.pop(args[2],None); p.write_text(json.dumps(rows))
''');fake.chmod(0o755)
        self.folder=self.home/'public';self.folder.mkdir()

    def tearDown(self):self.tmp.cleanup()

    def cli(self,*args,ok=True):
        p=subprocess.run([str(ROOT/'bin/dragon-files'),'share',*map(str,args),'--json'],
                         env=self.env,capture_output=True,text=True,timeout=10)
        self.assertEqual(p.returncode,0 if ok else 1,p.stdout+p.stderr)
        return json.loads(p.stdout)

    def test_enable_status_disable_and_guest_default(self):
        r=self.cli('enable','--path',self.folder,'--name','Docs','--rw')
        self.assertFalse(r['guest']);self.assertTrue(r['rw'])
        self.assertTrue(r['addresses']['smb'].endswith('/Docs'))
        argv=(self.home/'argv').read_text()
        self.assertIn('guest_ok=n',argv);self.assertNotIn('Everyone',argv)
        self.assertTrue(self.cli('status','--path',self.folder)['shared'])
        self.assertEqual(len(self.cli('status')['shares']),1)
        self.cli('disable','--path',self.folder)
        self.assertFalse(self.cli('status','--path',self.folder)['shared'])

    def test_forbidden_paths_and_symlink_bypass(self):
        for name in ('.ssh','.gnupg','.config','.local/share/keyrings'):
            (self.home/name).mkdir(parents=True,exist_ok=True)
        link=self.home/'alias';link.symlink_to(self.home/'.ssh',target_is_directory=True)
        for path in (self.home,Path('/'),Path('/etc'),self.home/'.ssh',self.home/'.gnupg',self.home/'.config',link):
            with self.subTest(path=path):
                r=self.cli('enable','--path',path,'--name','Bad',ok=False)
                self.assertEqual(r['error']['code'],'forbidden_path')
        self.assertFalse((self.home/'argv').exists())

    def test_names_and_collision(self):
        self.cli('enable','--path',self.folder,'--name','Docs')
        other=self.home/'other';other.mkdir()
        self.assertEqual(self.cli('enable','--path',other,'--name','Docs',ok=False)['error']['code'],'share_exists')
        for name in ('../bad','-bad','x\ny','x$','x;foo'):
            self.assertEqual(self.cli('enable','--path',self.folder,'--name='+name,ok=False)['error']['code'],'invalid_name')

    def test_disable_cannot_delete_another_path(self):
        other=self.home/'other';other.mkdir()
        self.cli('enable','--path',self.folder,'--name','Docs')
        self.cli('disable','--path',other,'--name','Docs')
        self.assertTrue(self.cli('status','--path',self.folder)['shared'])
