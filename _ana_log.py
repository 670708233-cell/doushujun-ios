import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
t = open('_uit_latest.log', encoding='utf-8', errors='replace').read().splitlines()
s = next(i for i, l in enumerate(t) if 'testLoginFullFlow' in l and 'Test Case' in l and 'started' in l)
e = next(i for i, l in enumerate(t) if 'testLoginFullFlow' in l and 'Test Case' in l and 'failed' in l)
seg = t[s:e]
# 找第二次 Launch com.doushujun（重试轮起点）
idx = [i for i, l in enumerate(seg) if 'Launch com.doushujun' in l]
start = idx[1] - 1 if len(idx) > 1 else 0
for l in seg[start:start+50]:
    print(l[:170])
