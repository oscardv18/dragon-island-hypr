"""Standalone CLI benchmark: warmed median/p95, 150 ms median target, isolated state."""
import argparse
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runs', type=int, default=25)
    args = parser.parse_args()
    if args.runs < 7:
        parser.error('--runs must be at least 7')
    failed = False
    with tempfile.TemporaryDirectory(prefix='dragon-engines-bench-') as temporary:
        home = Path(temporary)
        environment = dict(os.environ, HOME=temporary, HISTFILE=str(home / 'history'),
                           PYTHONDONTWRITEBYTECODE='1')
        for key, child in [('CONFIG', 'config'), ('STATE', 'state'), ('DATA', 'data'), ('CACHE', 'cache')]:
            environment[f'XDG_{key}_HOME'] = str(home / child)
        environment['XDG_RUNTIME_DIR'] = str(home / 'runtime')
        (home / 'history').write_text(''.join(f': 1761830000:0;git status --fixture-{i}\n' for i in range(4000)))
        for mode, query in [('calc', '20% de 350'), ('cmd', 'git'), ('cmd', ''),
                            ('web', 'gh quickshell'), ('emoji', 'corazón')]:
            command = [str(ROOT / 'bin/dragon-search'), mode, query, '--json']
            durations = []
            for run in range(args.runs + 1):
                start = time.perf_counter()
                process = subprocess.run(command, env=environment, capture_output=True, text=True,
                                         timeout=5, check=True)
                elapsed = (time.perf_counter() - start) * 1000
                if not json.loads(process.stdout)['results']:
                    raise RuntimeError(f'{mode}: no results')
                if run:
                    durations.append(elapsed)
            median = statistics.median(durations)
            p95 = sorted(durations)[math.ceil(.95 * len(durations)) - 1]
            failed |= median >= 150
            print(f'{mode:5} query={query!r}: median={median:.1f} ms  p95={p95:.1f} ms '
                  f'(target <150 ms: {"PASS" if median < 150 else "FAIL"})')
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
