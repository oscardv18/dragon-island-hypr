"""Median of seven cold composer invocations, isolated HOME/XDG."""
import argparse
import statistics
import time
from test_prompt import Prompts

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--limit-ms', type=float, default=150)
a = parser.parse_args()
m = Prompts(); m.setUp()
try:
    medians = []
    for command, args in [('templates', ['--project', 'test']),
                          ('build', ['--project', 'test', '--template', 'implementar-tarjeta'])]:
        samples = []
        for _ in range(7):
            start = time.perf_counter(); m.cli('dragon-prompt', command, *args)
            samples.append((time.perf_counter()-start)*1000)
        medians.append(statistics.median(samples))
        print(f'dragon-prompt {command}: {medians[-1]:.1f} ms (limit {a.limit_ms:g} ms)')
    raise SystemExit(int(max(medians) >= a.limit_ms))
finally:
    m.doCleanups()
