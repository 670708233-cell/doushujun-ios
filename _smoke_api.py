# -*- coding: utf-8 -*-
"""iOS 端对接冒烟测试：复刻 Swift 端签名/请求流程，验证接口参数与响应结构"""
import hashlib
import json
import ssl
import urllib.request

BASE = "https://doushujun.me/api"
SECRET = "your_secret_key_here526fb87088aa9ac0bea25c0117f7e018"
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE


def flatten(value, prefix=None, pairs=None):
    if pairs is None:
        pairs = []
    if isinstance(value, dict):
        for k, v in value.items():
            child = k if prefix is None else f"{prefix}.{k}"
            flatten(v, child, pairs)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            flatten(v, f"{prefix}.{i}", pairs)
    else:
        if isinstance(value, bool):
            s = "true" if value else "false"
        elif value is None:
            s = ""
        else:
            s = str(value)
        pairs.append((prefix or "", s))
    return pairs


def sign(data, ts):
    pairs = sorted(flatten(data), key=lambda x: x[0])
    joined = "&".join(f"{k}={v}" for k, v in pairs)
    raw = f"{joined}&timestamp={ts}&key={SECRET}"
    return hashlib.sha256(raw.encode()).hexdigest()


def req(path, method="GET", body=None, signed=False):
    ts = int(__import__("time").time())
    headers = {"Content-Type": "application/json", "User-Agent": "DoushujuniOS/2.0"}
    if signed:
        headers["X-Timestamp"] = str(ts)
        headers["X-Signature"] = sign(body or {}, ts)
    data = json.dumps(body).encode() if (method != "GET" and body is not None) else None
    r = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r, timeout=20, context=ctx) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8", "ignore"))
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode("utf-8", "ignore"))
        except Exception:
            return e.code, {}


print("== 1. captcha/generate ==")
code, d = req("/captcha/generate")
print(code, json.dumps(d, ensure_ascii=False)[:200])

print("\n== 2. captcha/slider/generate ==")
code, d = req("/captcha/slider/generate")
print(code, json.dumps(d, ensure_ascii=False)[:260])
slider = d.get("data") or {}

print("\n== 3. vip/packages (signed) ==")
code, d = req("/vip/packages", signed=True)
print(code, json.dumps(d, ensure_ascii=False)[:300])

print("\n== 4. reset_password/checkEmailForReset ==")
code, d = req("/reset_password/checkEmailForReset", method="POST", body={"email": "not_exist_test@x.com"})
print(code, json.dumps(d, ensure_ascii=False)[:200])

print("\n== 5. user/login (wrong captcha, expect explicit error) ==")
code, d = req("/user/login", method="POST", body={
    "username": "test_probe", "password": "test123",
    "captcha_key": (slider.get("captcha_key") or ""), "captcha_code": "xxxx",
    "slider_token": "fake"})
print(code, json.dumps(d, ensure_ascii=False)[:200])

print("\n== 6. vip/status (no auth, expect 401-ish) ==")
code, d = req("/vip/status", signed=True)
print(code, json.dumps(d, ensure_ascii=False)[:200])
