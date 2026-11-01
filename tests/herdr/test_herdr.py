import json
import os
from pathlib import Path
import selectors
import sqlite3
import statistics
import subprocess
import tempfile
import time
import unittest
from fake_herdr import FakeHerdr

ROOT=Path(__file__).resolve().parents[2]

class Bridge(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='dh-');self.addCleanup(self.tmp.cleanup);self.home=Path(self.tmp.name)
        self.env=dict(os.environ,HOME=str(self.home),XDG_RUNTIME_DIR=str(self.home/'run'),PYTHONDONTWRITEBYTECODE='1',HERDR_SOCKET_PATH=str(self.home/'herdr.sock'))
        for n in ('DATA','CONFIG','CACHE','STATE'):self.env[f'XDG_{n}_HOME']=str(self.home/n.lower())
        self.server=FakeHerdr(self.env['HERDR_SOCKET_PATH'],str(self.home)).start();self.addCleanup(lambda:self.server.stop())
        self.shim=self.home/'bin';self.shim.mkdir();self.env['PATH']=str(self.shim)+':'+os.environ['PATH']
        p=self.shim/'hyprctl';p.write_text('''#!/usr/bin/env python3
import json,os,sys
if sys.argv[1:]==['clients','-j']:
 print(json.dumps([{'class':'org.dragonisland.Herdr','address':'0x123','title':'demo'}]))
else:print('ok')
''');p.chmod(0o755)
    def cli(self,*args,code=0,input=None):
        r=subprocess.run([str(ROOT/'bin/dragon-herdr'),*args],env=self.env,capture_output=True,text=True,input=input,timeout=5)
        self.assertEqual(r.returncode,code,r.stdout+r.stderr);return json.loads(r.stdout)
    def watcher(self):
        p=subprocess.Popen([str(ROOT/'bin/dragon-herdr'),'watch','--record'],env=self.env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        def cleanup():
            if p.poll() is None:p.terminate();p.wait(timeout=3)
            p.stdout.close();p.stderr.close()
        self.addCleanup(cleanup)
        return p
    def line(self,p,until=None,timeout=4):
        # os.read avoids Python buffered-reader/select mismatch with multiple JSON lines.
        if not hasattr(self,'buffers'):self.buffers={}
        buffer=self.buffers.get(p.pid,b'');deadline=time.monotonic()+timeout
        with selectors.DefaultSelector() as sel:
            sel.register(p.stdout,selectors.EVENT_READ)
            while time.monotonic()<deadline:
                if b'\n' not in buffer:
                    if not sel.select(.1):continue
                    chunk=os.read(p.stdout.fileno(),65536)
                    if not chunk:self.fail('watch exited: '+p.stderr.read().decode())
                    buffer+=chunk
                while b'\n' in buffer:
                    line,buffer=buffer.split(b'\n',1);r=json.loads(line)
                    if until is None or until(r):self.buffers[p.pid]=buffer;return r
        self.fail('watch event timed out')
    def subscribed(self):
        deadline=time.monotonic()+3
        while time.monotonic()<deadline:
            if self.server.clients:return
            time.sleep(.02)
        self.fail('no subscription')
    def test_snapshot_probe_none_and_budget(self):
        r=self.cli('snapshot','--json');self.assertEqual(r['source'],'herdr');self.assertEqual(r['agents'][0]['helper_of'],None)
        self.assertFalse(self.cli('probe')['features']['helpers'])
        times=[]
        for _ in range(7):
            t=time.perf_counter();self.cli('snapshot');times.append((time.perf_counter()-t)*1000)
        self.assertLess(statistics.median(times),300)
        self.env['HERDR_SOCKET_PATH']=str(self.home/'missing.sock')
        self.assertEqual(self.cli('snapshot')['source'],'none');self.assertEqual(self.cli('snapshot')['agents'],[])
    def test_focus_read_prompt(self):
        self.assertTrue(self.cli('focus','w1:p1')['ok'])
        text=self.cli('read','w1:p1','--lines','8')['text']
        self.assertNotIn('neverexpose',text);self.assertNotIn('private_value',text);self.assertIn('[oculto:',text)
        self.cli('prompt','w1:p1','--stdin',input='API_KEY=secretvalue\nDo work')
        self.assertEqual(self.server.calls[-1][0],'agent.prompt');self.assertNotIn('secretvalue',self.server.calls[-1][1]['text'])
        self.cli('prompt','w1:p1','--stdin','--no-enter',input='draft')
        self.assertEqual(self.server.calls[-1][0],'pane.send_text')
        self.server.event('blocked')
        before=len([m for m,p in self.server.calls if m in ('agent.prompt','pane.send_text')])
        self.assertEqual(self.cli('prompt','w1:p1','--stdin',input='yes',code=1)['error']['code'],'agent_blocked')
        self.cli('prompt','w1:p1','--stdin','--no-enter',input='yes',code=1)
        self.assertEqual(before,len([m for m,p in self.server.calls if m in ('agent.prompt','pane.send_text')]))
    def test_watch_record_reconnect_and_sigterm(self):
        p=self.watcher();self.assertEqual(self.line(p)['t'],'snapshot');self.subscribed()
        start=time.monotonic();self.server.event('blocked')
        r=self.line(p,lambda r:r.get('t')=='agent');self.assertEqual(r['agent']['state'],'blocked')
        self.assertLess(time.monotonic()-start,2)
        db=self.home/'data/dragon-island/dragon.db'
        with sqlite3.connect(db) as c:self.assertEqual(c.execute('select count(*) from agent_wait where resumed_at is null').fetchone()[0],1)
        self.server.event('working');self.line(p,lambda r:r.get('t')=='agent' and r['agent']['state']=='working')
        with sqlite3.connect(db) as c:self.assertEqual(c.execute('select count(*) from agent_wait where resumed_at is null').fetchone()[0],0)
        self.server.stop();self.line(p,lambda r:r.get('source')=='none')
        self.server=FakeHerdr(self.env['HERDR_SOCKET_PATH'],str(self.home)).start()
        self.line(p,lambda r:r.get('source')=='herdr',timeout=5)
        p.terminate();self.assertEqual(p.wait(timeout=2),0)
    def test_remove_and_since(self):
        p=self.watcher();first=self.line(p)['agents'][0];self.subscribed()
        self.server.event('done');r=self.line(p,lambda r:r.get('t')=='agent')
        self.assertEqual(r['agent']['state'],'done')
        self.server.event(remove=True);self.assertEqual(self.line(p,lambda r:r.get('op')=='remove')['id'],first['id'])
    def test_card_worktree_join(self):
        command=[str(ROOT/'bin/dragon-mem')]
        for a in [('project','add','--path',str(self.home),'--slug','demo','--prefix','AX'),('card','add','--project','demo','--title','Task'),('card','set','AX-1','--worktree',str(self.home))]:
            subprocess.run(command+list(a),env=self.env,check=True,capture_output=True)
        a=self.cli('snapshot')['agents'][0];self.assertEqual(a['card'],'AX-1');self.assertEqual(a['project'],'demo')
    def test_start_order(self):
        r=self.cli('start','--cwd',str(self.home),'--kind','codex','--name','Task')
        self.assertEqual(r['id'],'w2:p1');self.assertEqual([m for m,p in self.server.calls],['workspace.create','agent.start'])
    def test_focus_ambiguous_error(self):
        p=self.shim/'hyprctl';p.write_text('#!/bin/sh\nprintf \'[]\\n\'\n');p.chmod(0o755)
        self.assertEqual(self.cli('focus','w1:p1',code=1)['error']['code'],'client_not_found')
