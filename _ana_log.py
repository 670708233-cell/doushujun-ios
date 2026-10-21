import sys
t = open('_uit_latest.log', encoding='utf-8', errors='replace').read().splitlines()
s = next(i for i, l in enumerate(t) if 'testLoginFullFlow' in l and 'Test Case' in l and 'started' in l)
for l in t[s:s+45]:
    print(l[:170])
