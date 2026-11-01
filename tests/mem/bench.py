"""Median of seven cold CLI project-list reads, isolated HOME/XDG."""
import statistics
import time
from test_mem import Memory
m=Memory();m.setUp()
try:
    samples=[]
    for _ in range(7):
        start=time.perf_counter();m.cli('project','list');samples.append((time.perf_counter()-start)*1000)
    median=statistics.median(samples)
    print(f'dragon-mem project list: {median:.1f} ms (target <150 ms)')
    raise SystemExit(int(median>=150))
finally:m.doCleanups()
