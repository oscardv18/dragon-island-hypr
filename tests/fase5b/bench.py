"""Seven cold CLI runs, isolated HOME/XDG and a Unix fake. --limit-ms 300 in CI."""
import argparse
import os
from pathlib import Path
import statistics
import subprocess
import sys
import tempfile
import time
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/docker'))
from fake_docker import FakeDocker

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--limit-ms',type=float,default=150); args = parser.parse_args()
    failed = False
    with tempfile.TemporaryDirectory(prefix='5b-bench-') as tmp:
        home = Path(tmp); env = dict(os.environ,HOME=tmp,DRAGON_DOCKER_SOCKET=str(home/'d.sock'),PYTHONDONTWRITEBYTECODE='1')
        for key in ('CONFIG','DATA','STATE','CACHE','RUNTIME'): env['XDG_'+key+('_DIR' if key == 'RUNTIME' else '_HOME')] = str(home/key)
        repo = home/'repo'; subprocess.run(['git','init',str(repo)],env=env,capture_output=True,check=True)
        for i in range(1000): (repo/f'file-{i}').write_text('synthetic\n')
        server = FakeDocker(str(home/'d.sock')).start()
        try:
            for name, argv in [('docker-ps',['dragon-docker','ps','--json']),('git-status-1000',['dragon-git','status','--repo',str(repo),'--json'])]:
                durations = []
                for _ in range(7):
                    start = time.perf_counter(); subprocess.run([str(ROOT/'bin'/argv[0]),*argv[1:]],env=env,capture_output=True,check=True,timeout=5)
                    durations.append((time.perf_counter()-start)*1000)
                median = statistics.median(durations); failed |= median >= args.limit_ms
                print(f'{name}: mediana {median:.1f} ms, límite {args.limit_ms:g} ms')
        finally: server.stop()
    return int(failed)
if __name__ == '__main__': raise SystemExit(main())
