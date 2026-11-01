import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import statistics
import subprocess
import tempfile
import time
import unittest

ROOT=Path(__file__).resolve().parents[2]

class Memory(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='dragon-mem-test-');self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name);self.repo=self.home/'repo ñ';self.repo.mkdir()
        self.env=dict(os.environ,HOME=str(self.home),PYTHONDONTWRITEBYTECODE='1',XDG_RUNTIME_DIR=str(self.home/'run'))
        for n in ('DATA','CONFIG','CACHE','STATE'):self.env[f'XDG_{n}_HOME']=str(self.home/n.lower())
        subprocess.run(['git','init','-q',str(self.repo)],check=True)
        self.db=self.home/'data/dragon-island/dragon.db'
        self.cli('project','add','--path',self.repo,'--slug','test','--prefix','AX')
    def cli(self,*args,code=0):
        r=subprocess.run([str(ROOT/'bin/dragon-mem'),*map(str,args),'--json'],env=self.env,capture_output=True,text=True,timeout=15)
        self.assertEqual(r.returncode,code,r.stderr+r.stdout)
        return json.loads(r.stdout)
    def add(self):return self.cli('card','add','--project','test','--title','Nueva función')['card']['key']
    def test_schema_permissions_idempotent(self):
        self.cli('init');self.cli('init')
        with sqlite3.connect(self.db) as db:
            self.assertEqual(db.execute('pragma user_version').fetchone()[0],1)
            self.assertEqual(db.execute('pragma journal_mode').fetchone()[0],'wal')
            self.assertEqual(db.execute('select count(*) from project').fetchone()[0],1)
        self.assertEqual(self.db.stat().st_mode&0o777,0o600)
        self.assertIn('.dragon/',(self.repo/'.git/info/exclude').read_text())
        self.assertFalse((self.repo/'.gitignore').exists())
    def test_key_wip_events(self):
        keys=[self.add() for _ in range(4)];self.assertEqual(keys,['AX-1','AX-2','AX-3','AX-4'])
        for k in keys[:3]:self.cli('card','move',k,'--to','doing')
        r=self.cli('card','move',keys[3],'--to','doing',code=1)
        self.assertEqual(r['error']['code'],'wip_limit_reached')
        self.cli('card','move',keys[3],'--to','doing','--force')
        self.cli('card','move',keys[0],'--to','review');self.cli('card','move',keys[0],'--to','doing','--force')
        self.assertIn('returned',[e['kind'] for e in self.cli('card','show',keys[0])['events']])
    def test_fts_transactions(self):
        key=self.add();self.cli('card','set',key,'--title','Facturación internacional')
        self.assertEqual(self.cli('search','facturacion','--project','test')['results'][0]['title'],'Facturación internacional')
        self.cli('card','set',key,'--title','Otra cosa')
        self.assertEqual(self.cli('search','facturacion')['results'],[])
        n=self.cli('note','add','--project','test','--title','Decisión','--body','Usar SQLite')['id']
        self.assertTrue(self.cli('search','sqlite')['results']);self.cli('note','rm',n)
        self.assertFalse(self.cli('search','sqlite')['results'])
        t=self.cli('template','save','--name','prueba','--blocks','["cobertura"]')['id']
        self.assertTrue(self.cli('search','cobertura')['results']);self.cli('template','rm',t)
        self.assertFalse(self.cli('search','cobertura')['results'])
    def test_seen_changed_and_comments(self):
        key=self.add();f=self.repo/'file.txt';f.write_text('uno')
        h=hashlib.sha1(b'blob 3\0uno').hexdigest()
        self.cli('seen','set',key,'--path','file.txt','--hash',h)
        r=self.cli('seen','list',key)['seen'][0];self.assertTrue(r['seen']);self.assertEqual(r['blob_hash'],h)
        f.write_text('dos');self.assertTrue(self.cli('seen','list',key)['seen'][0]['changed'])
        f.unlink();self.assertFalse(self.cli('seen','list',key)['seen'][0]['seen'])
        self.cli('comment','add',key,'--path','file.txt','--line','2','--text','Revisar')
        self.cli('comment','mark-sent',key)
        self.assertEqual(self.cli('comment','list',key)['comments'][0]['sent'],1)
        self.cli('comment','clear',key);self.assertEqual(self.cli('comment','list',key)['comments'],[])
    def test_export_utf8_limit_secrets(self):
        key=self.add();self.cli('card','move',key,'--to','doing')
        self.cli('card','criteria','add',key,'--text','Criterio real')
        for _ in range(12):self.cli('note','add','--project','test','--kind','decision','--title','ñ'*100,'--body','é'*600)
        self.cli('note','add','--project','test','--kind','convention','--title','Convención','--body','ñ'*4000)
        self.cli('system','log','add','--key','appearance','--old','a','--new','API_TOKEN=neverstore','--source','test')
        result=self.cli('export','--project','test');text=Path(result['path']).read_text()
        self.assertLess(len(text.encode()),4096);self.assertIn('Criterio real',text);self.assertIn('no editar',text)
        self.assertNotIn('neverstore',self.db.read_bytes().decode(errors='ignore'))
    def test_concurrent_keys(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:keys=list(pool.map(lambda _:self.add(),range(12)))
        self.assertEqual(len(set(keys)),12)
    def test_stats(self):
        key=self.add();now=int(time.time())
        with sqlite3.connect(self.db) as db:
            cid=db.execute('select id from card where key=?',(key,)).fetchone()[0]
            db.execute("update card set col='done',created_at=?,started_at=?,done_at=? where id=?",(now-7200,now-3600,now,cid))
            db.execute("insert into card_event(card_id,ts,kind) values(?,?,'returned')",(cid,now))
            db.execute('insert into agent_wait(agent_id,card_id,blocked_at,resumed_at) values(?,?,?,?)',('a',cid,now-1800,now))
        r=self.cli('stats','flow','--project','test');self.assertEqual(r['lead_time_median_h'],2)
        self.assertEqual(r['cycle_time_median_h'],1);self.assertEqual(r['rework_pct'],100)
        self.assertEqual(r['approval_wait_median_h'],.5);self.assertEqual(r['throughput_7d'],1)
    def test_wait_deduplicates(self):
        key=self.add()
        for _ in range(2):self.cli('wait','start','agent','--card',key)
        self.cli('wait','end','agent')
        with sqlite3.connect(self.db) as db:self.assertEqual(db.execute('select count(*) from agent_wait').fetchone()[0],1)
    def test_backups_and_migration(self):
        for _ in range(9):self.cli('backup')
        self.assertEqual(len(list((self.db.parent/'backups').glob('*.db'))),7)
        before=self.db.read_bytes()
        for _ in range(2):
            r=subprocess.run(['bash',str(ROOT/'migrations/044-mem-install.sh')],env=dict(self.env,LINK_MODE='copy',ASSUME_YES='true'),capture_output=True,text=True)
            self.assertEqual(r.returncode,0,r.stderr+r.stdout)
        self.assertEqual(before,self.db.read_bytes())
        copied=self.home/'.local/bin/dragon-mem'
        self.assertTrue(copied.is_file());self.assertEqual(subprocess.run([str(copied),'init'],env=self.env,capture_output=True).returncode,0)
    def test_installer_preserves_existing_database(self):
        with sqlite3.connect(self.db) as db:
            db.execute('PRAGMA wal_checkpoint(TRUNCATE)')
        other=self.home/'old/data/dragon-island/dragon.db';other.parent.mkdir(parents=True)
        with sqlite3.connect(other) as db:
            db.execute('create table custom_note(text)');db.execute("insert into custom_note values('keep me')")
        env=dict(self.env,XDG_DATA_HOME=str(self.home/'old/data'))
        for _ in range(2):
            r=subprocess.run(['python3','-S',str(ROOT/'dragon-core/mem_install.py')],env=env,capture_output=True,text=True)
            self.assertEqual(r.returncode,0,r.stderr)
        copies=list((other.parent/'backups').glob('*.db'));self.assertEqual(len(copies),1)
        with sqlite3.connect(copies[0]) as db:
            self.assertEqual(db.execute('select text from custom_note').fetchone()[0],'keep me')
        with sqlite3.connect(other) as db:self.assertEqual(db.execute('pragma user_version').fetchone()[0],1)
    def test_initial_schema_concurrency(self):
        env=dict(self.env,XDG_DATA_HOME=str(self.home/'new/data'))
        def invoke(_):
            return subprocess.run([str(ROOT/'bin/dragon-mem'),'init'],env=env,capture_output=True,text=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(invoke,range(2)))
        for r in results:self.assertEqual(r.returncode,0,r.stdout+r.stderr)
    def test_usage_error_json(self):
        self.assertEqual(self.cli('card','move',code=2)['error']['code'],'invalid_usage')
    def test_cold_read_budget(self):
        durations=[]
        for _ in range(7):
            start=time.perf_counter();self.cli('project','list');durations.append((time.perf_counter()-start)*1000)
        self.assertLess(statistics.median(durations),300)
