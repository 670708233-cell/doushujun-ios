import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
t = open('_uit_latest.log', encoding='utf-8', errors='replace').read().splitlines()
s = next(i for i, l in enumerate(t) if 'testLoginFullFlow' in l and 'Test Case' in l and 'started' in l)
for l in t[s:s+200]:
    if any(k in l for k in ('Launch', 'Terminate', 'Checking existence', 'Waiting', 'Checking `Expect predicate', 'DIAG', 'idle', 'Find the', 'failed', 'passed', 'Test Case')):
        print(l[:160])
