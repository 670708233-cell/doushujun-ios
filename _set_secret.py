# -*- coding: utf-8 -*-
"""把 token 写入 doushujun-ios 仓库 Actions secret（GH_PAT），供 uitest job checkout 私有后端仓。"""
import base64
import io
import json
import urllib.request

OWNER = "670708233-cell"
IOS_REPO = "doushujun-ios"
SECRET_NAME = "GH_PAT"


def read_token():
    cred = io.open(r"d:\hubulider\dsj\doushujunfull\_cred_out.txt", encoding="utf-8").read()
    for line in cred.splitlines():
        line = line.strip()
        if line.startswith("password="):
            return line[len("password="):].strip()
    raise SystemExit("TOKEN not found")


def req(method, url, body=None):
    headers = {"Authorization": "Bearer " + TOKEN, "Accept": "application/vnd.github+json",
               "User-Agent": "set-secret"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            content = resp.read()
            return resp.status, (json.loads(content) if content else {})
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:300].decode("utf-8", "ignore")


TOKEN = read_token()
BASE = f"https://api.github.com/repos/{OWNER}/{IOS_REPO}/actions/secrets"

# 1. 拿仓库公钥
code, pk = req("GET", BASE + "/public-key")
if code != 200:
    raise SystemExit(f"public-key FAILED {code}: {pk}")
print("public key ok:", pk["key_id"])

# 2. libsodium sealed box 加密
from nacl import encoding, public as nacl_public
pk_obj = nacl_public.PublicKey(pk["key"].encode(), encoding.Base64Encoder())
sealed = nacl_public.SealedBox(pk_obj).encrypt(TOKEN.encode())

# 3. 写 secret
code, r = req("PUT", BASE + f"/{SECRET_NAME}",
              {"encrypted_value": base64.b64encode(sealed).decode(), "key_id": pk["key_id"]})
print("PUT secret:", code)
if code not in (201, 204):
    raise SystemExit(f"secret FAILED: {r}")
print("DONE. secret GH_PAT set on", IOS_REPO)
