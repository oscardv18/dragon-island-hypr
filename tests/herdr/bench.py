"""Seven cold CLI roundtrips to a real local fake Unix socket. No user data."""
import statistics
import time
from test_herdr import Bridge
m=Bridge();m.setUp()
try:
    values=[]
    for _ in range(7):
        start=time.perf_counter();m.cli('snapshot','--json');values.append((time.perf_counter()-start)*1000)
    median=statistics.median(values)
    print(f'dragon-herdr snapshot: {median:.1f} ms (target <150 ms)')
    raise SystemExit(int(median>=150))
finally:m.doCleanups()
