"""Opt-in real Engine smoke test. Uses an existing image, isolated project, no ports/volumes/network.
Run: python3 tests/fase5b/real_compose.py --run
Only its own two containers are started/removed. The worker intentionally hits its
32 MiB container limit (max 5 restarts); the host has no unbounded allocation.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--run',action='store_true',required=True); parser.add_argument('--visual',metavar='OUT_DIR'); args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='5b-compose-') as tmp:
        home = Path(tmp); env = dict(os.environ,HOME=tmp)
        for key in ('CONFIG','DATA','STATE','CACHE','RUNTIME'): env['XDG_'+key+('_DIR' if key == 'RUNTIME' else '_HOME')] = str(home/key)
        config = home/'compose.json'
        common = dict(image='python:3.13-slim',network_mode='none',mem_limit='32m',cpus=.5)
        config.write_text(json.dumps(dict(services={
            'api':dict(common,command=['python','-u','-c','import time\nwhile True:\n print("WARN synthetic repeat",flush=True); sum(range(100000)); time.sleep(.3)']),
            'worker':dict(common,restart='on-failure:5',command=['python','-u','-c','print("ERROR synthetic OOM",flush=True); a=bytearray(256*1024*1024)'])})))
        compose = ['docker','compose','-p',f'dragon5b-test-{os.getpid()}','-f',str(config)]
        def cli(*args):
            p = subprocess.run([str(ROOT/'bin/dragon-docker'),*args],env=env,capture_output=True,text=True,check=True,timeout=10)
            return [json.loads(line) for line in p.stdout.splitlines()]
        try:
            subprocess.run([*compose,'up','-d','--pull','never'],env=env,check=True,timeout=20)
            deadline = time.monotonic()+35
            own = []
            while time.monotonic()<deadline:
                own = [r for r in cli('ps','--json')[0]['containers'] if r['project'] == f'dragon5b-test-{os.getpid()}']
                if len(own)==2 and next(c for c in own if c['service']=='worker')['restart_count']>=5 and next(c for c in own if c['service']=='worker')['state'] == 'exited': break
                time.sleep(.5)
            assert len(own)==2, own
            worker = next(c for c in own if c['service']=='worker'); api = next(c for c in own if c['service']=='api')
            assert worker['oom_killed'], worker
            issues = cli('issues','--json')[0]['issues']
            relevant = [i for i in issues if i['container']==worker['id']]
            print('REAL_COMPOSE_WORKER',json.dumps(dict(restart_count=worker['restart_count'],oom_killed=worker['oom_killed'],issues=relevant)))
            stream = subprocess.Popen([str(ROOT/'bin/dragon-docker'),'stats','--stream','--ids',api['id']],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            try:
                first = json.loads(stream.stdout.readline()); start = time.monotonic(); second = json.loads(stream.stdout.readline()); elapsed = time.monotonic()-start
                assert first['mem_bytes']>0 and second['cpu_pct']>=0 and 1.5<elapsed<3.5, (first,second,elapsed)
                print('REAL_COMPOSE_STATS',json.dumps(dict(cpu_pct=second['cpu_pct'],mem_bytes=second['mem_bytes'],interval_s=round(elapsed,2))))
            finally: stream.terminate(); stream.communicate(timeout=6)
            logs = cli('logs',api['id'],'--tail','20')
            assert any(r['count']>1 and r['level']=='warn' for r in logs), logs
            assert any(i['kind']=='restart_loop' for i in relevant), relevant
            print('REAL_COMPOSE_OK',flush=True)
            if args.visual:
                from real_preview import preview
                Path(args.visual).mkdir(parents=True,exist_ok=True)
                preview(f'dragon5b-test-{os.getpid()}',args.visual)
        finally:
            subprocess.run([*compose,'down','--remove-orphans'],env=env,timeout=20,check=True)
if __name__ == '__main__': main()
