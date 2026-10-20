# -*- coding: utf-8 -*-
"""自研滑块验证全自动测试：模拟完整协议打生产接口，定位 iOS 端失败原因
测试组：
  A. iOS 当前行为复现：轨迹=[[x,y,t]] 数组格式 + ratio=1.0 × N 次
  B. web 端协议对齐：轨迹=[{x,y,t}] 对象格式 + ratio=1.0 × N 次
  C. ratio 扫描：反推 target 分布（generate 不下发 target，只能统计）
  D. 反脚本检测边界：匀速直线 / 恒 Y 轨迹
"""
import json, time, base64, urllib.request, random, math, subprocess, sys, os

BASE = "https://doushujun.me/api"

# ---------- AES-128-CBC PKCS7（多后端 fallback） ----------
def aes_enc(plain: bytes, key: bytes, iv: bytes) -> str:
    pad = 16 - len(plain) % 16
    data = plain + bytes([pad]) * pad
    try:                                    # 1) cryptography
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        enc = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
        return base64.b64encode(enc.update(data) + enc.finalize()).decode()
    except ImportError:
        pass
    try:                                    # 2) pycryptodome
        from Crypto.Cipher import AES
        c = AES.new(key, AES.MODE_CBC, iv)
        return base64.b64encode(c.encrypt(data)).decode()
    except ImportError:
        pass
    # 3) openssl 命令行兜底
    p = subprocess.run(
        ["openssl", "enc", "-aes-128-cbc", "-K", key.hex(), "-iv", iv.hex(),
         "-nosalt"], input=data, capture_output=True, check=True)
    return base64.b64encode(p.stdout).decode()

# ---------- HTTP ----------
def http(method: str, path: str, body: dict | None = None):
    url = BASE + path
    data = None
    headers = {"User-Agent": "DoushujunTest/1.0"}
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read().decode())
        except Exception:
            return {"code": e.code, "msg": f"HTTP {e.code}"}

def generate():
    d = http("GET", "/captcha/slider/generate")
    if d.get("code") != 200:
        raise RuntimeError(f"generate 失败: {d}")
    dd = d["data"]
    return dd["captcha_key"], dd["aes_key"].encode(), dd["aes_iv"].encode()

# ---------- 拟人轨迹生成（模拟 iOS 拖动 60Hz 回调） ----------
def human_traj(max_px=300.0, dur_ms=None):
    dur_ms = dur_ms or random.randint(700, 1600)
    n = random.randint(28, 55)
    y0 = 500 + random.randint(-50, 50)
    pts = []
    for i in range(n):
        p = (i + 1) / n
        # ease-out：先快后慢
        eased = 1 - (1 - p) ** 2.2
        x = max_px * eased + random.uniform(-1.0, 1.0)
        y = y0 + random.uniform(-3.0, 3.0)
        t = int(dur_ms * p + random.uniform(-12, 12))
        pts.append([x, y, max(t, 0)])
    pts.sort(key=lambda q: q[2])
    return pts

def to_objects(arr):
    return [{"x": round(x, 2), "y": round(y, 2), "t": t} for x, y, t in arr]

def verify(captcha_key, aes_key, aes_iv, ratio, traj, total_ms=None, fmt="array"):
    if fmt == "object":
        traj = to_objects(traj)
    total_ms = total_ms or max(int(traj[-1][2] if fmt == "array" else traj[-1]["t"]), 600)
    payload = {
        "ratio": round(ratio, 4),
        "total_time": total_ms,
        "trajectory": traj,
        "pause_count": 0,
        "point_count": len(traj),
        "mouse_down_count": 1,
    }
    cipher = aes_enc(json.dumps(payload, ensure_ascii=False).encode(), aes_key, aes_iv)
    return http("POST", "/captcha/slider/verify",
                {"captcha_key": captcha_key, "payload": cipher})

# ---------- 测试组 ----------
def run(name, n, ratio, fmt, traj_fn=human_traj, **kw):
    ok = fail = 0
    msgs = {}
    for i in range(n):
        try:
            k, ak, av = generate()
            r = verify(k, ak, av, ratio, traj_fn(**kw) if traj_fn else None, fmt=fmt)
        except Exception as e:
            print(f"  [{name}] #{i+1} EXC {e}"); fail += 1; continue
        m = r.get("msg", "?")
        msgs[m] = msgs.get(m, 0) + 1
        if r.get("code") == 200:
            ok += 1
        else:
            fail += 1
        time.sleep(0.15)
    print(f"[{name}] ratio={ratio} fmt={fmt} n={n} → 通过 {ok}/{n}  明细: {msgs}")
    return ok, msgs

if __name__ == "__main__":
    print("=" * 64)
    print("自研滑块全自动测试  生产:", BASE)
    print("=" * 64)
    # 冒烟：generate 可用性
    k, ak, av = generate()
    print(f"冒烟 generate OK  key={k[:12]}...  aes_key={ak.decode()}  aes_iv={av.decode()}")
    print()

    group = sys.argv[1] if len(sys.argv) > 1 else "all"

    if group in ("all", "A"):
        print("---- 组A：复现 iOS 现状（数组轨迹 + ratio=1.0）----")
        run("A", 10, 1.00, "array")
        print()

    if group in ("all", "B"):
        print("---- 组B：web 协议对齐（对象轨迹 + ratio=1.0）----")
        run("B", 10, 1.00, "object")
        print()

    if group in ("all", "C"):
        print("---- 组C：ratio 扫描反推 target 区间（对象轨迹）----")
        for rr in (0.85, 0.88, 0.90, 0.92, 0.94, 0.96, 0.98):
            run("C", 4, rr, "object")
        print()

    if group in ("all", "D"):
        print("---- 组D：反脚本检测边界（对象轨迹 + ratio=1.0）----")
        # D1 匀速直线（x 匀速 / t 等距 / y 恒定）→ 预期「行为异常」
        def linear(**kw):
            y0 = 500.0
            return [[300.0 * i / 29, y0, int(1000 * i / 29)] for i in range(30)]
        run("D1匀速恒Y", 4, 1.00, "object", traj_fn=linear)
        # D2 拟人（对照）
        run("D2拟人对照", 4, 1.00, "object")
        print()
    print("DONE")
