"""Seven cold CLI runs for dragon-files ls of 1000 entries in an isolated HOME/XDG. --limit-ms 300 in CI."""
import argparse
import os
from pathlib import Path
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--limit-ms', type=float, default=150)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='files-bench-') as tmp:
        home = Path(tmp)
        env = dict(os.environ, HOME=tmp, PYTHONDONTWRITEBYTECODE='1')
        for key in ('CONFIG', 'DATA', 'STATE', 'CACHE', 'RUNTIME'):
            env['XDG_' + key + ('_DIR' if key == 'RUNTIME' else '_HOME')] = str(home / key.lower())
        folder = home / 'thousand'
        folder.mkdir()
        for i in range(1000):
            (folder / f'archivo-{i:04d}.txt').write_text('contenido\n', encoding='utf-8')
        durations = []
        for _ in range(7):
            start = time.perf_counter()
            subprocess.run(
                [str(ROOT / 'bin/dragon-files'), 'ls', str(folder), '--sort', 'name', '--dirs-first', '--hidden', '--json'],
                env=env,
                capture_output=True,
                check=True,
                timeout=5,
            )
            durations.append((time.perf_counter() - start) * 1000)
        median = statistics.median(durations)
        print(f'files-ls-1000: mediana {median:.1f} ms, límite {args.limit_ms:g} ms')
        return int(median >= args.limit_ms)


if __name__ == '__main__':
    raise SystemExit(main())
